@echo off
setlocal
title Install Python 3.9
rem Windows 10/11 x64. Internet is needed only if Python 3.9 is not installed.
set "PYTHON39_SETUP_BAT=%~f0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$text = [IO.File]::ReadAllText($env:PYTHON39_SETUP_BAT); $parts = $text -split '(?m)^# POWERSHELL\r?\n', 2; if ($parts.Length -ne 2) { throw 'The BAT file is incomplete.' }; & ([ScriptBlock]::Create($parts[1]))"
set "PYTHON39_SETUP_EXIT=%ERRORLEVEL%"
echo.
pause
exit /b %PYTHON39_SETUP_EXIT%

# POWERSHELL
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    if (($env:PROCESSOR_ARCHITECTURE -ne 'AMD64') -and ($env:PROCESSOR_ARCHITEW6432 -ne 'AMD64')) {
        throw 'This installer requires Windows 10/11 x64.'
    }

    $installDir = Join-Path $env:LOCALAPPDATA 'Programs\Python\Python39'
    $candidates = @((Join-Path $installDir 'python.exe'))
    foreach ($key in @('HKCU:\Software\Python\PythonCore\3.9\InstallPath', 'HKLM:\Software\Python\PythonCore\3.9\InstallPath')) {
        if (Test-Path -LiteralPath $key) {
            $registeredDir = (Get-Item -LiteralPath $key).GetValue('')
            if ($registeredDir) {
                $candidates += Join-Path $registeredDir 'python.exe'
            }
        }
    }

    $python = $null
    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $candidate) {
            & $candidate -c "import struct, sys; sys.exit(0 if sys.version_info[:2] == (3, 9) and struct.calcsize('P') == 8 else 1)"
            if ($LASTEXITCODE -eq 0) {
                $python = $candidate
                break
            }
        }
    }

    if ($python) {
        Write-Host 'Using the existing Python 3.9 installation.'
    }
    else {
        Write-Host 'Downloading and installing Python 3.9.13 x64. Please wait...'
        $setupDir = Join-Path ([IO.Path]::GetTempPath()) ('python39-setup-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $setupDir | Out-Null
        $installer = Join-Path $setupDir 'python-3.9.13-amd64.exe'
        $installLog = Join-Path $setupDir 'install.log'
        Invoke-WebRequest -UseBasicParsing -Uri 'https://www.python.org/ftp/python/3.9.13/python-3.9.13-amd64.exe' -OutFile $installer
        $expectedHash = 'fb3d0466f3754752ca7fd839a09ffe53375ff2c981279fd4bc23a005458f7f5d'
        if ((Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash -ine $expectedHash) {
            throw 'The installer download is incomplete or invalid. Run this BAT again.'
        }

        $installerArgs = @(
            '/quiet', '/norestart', 'InstallAllUsers=0', 'PrependPath=1',
            'Include_pip=1', 'Include_launcher=1', 'InstallLauncherAllUsers=0',
            'Include_test=0', 'AssociateFiles=0',
            ('TargetDir="' + $installDir + '"'), '/log', ('"' + $installLog + '"')
        )
        $process = Start-Process -FilePath $installer -ArgumentList $installerArgs -Wait -PassThru
        if (($process.ExitCode -ne 0) -and ($process.ExitCode -ne 3010)) {
            throw "Python installation failed (exit $($process.ExitCode)). Log: $installLog"
        }
        if ($process.ExitCode -eq 3010) {
            Write-Host 'Windows reported that a restart is needed. This script will not restart the computer.'
        }
        $python = Join-Path $installDir 'python.exe'
        if (-not (Test-Path -LiteralPath $python)) {
            throw "Python was not found after installation. Log: $installLog"
        }
        Remove-Item -LiteralPath $setupDir -Recurse -Force
    }

    & $python -c "import struct, sys; sys.exit(0 if sys.version_info[:2] == (3, 9) and struct.calcsize('P') == 8 else 1)"
    if ($LASTEXITCODE -ne 0) {
        throw 'The selected interpreter is not Python 3.9 x64.'
    }
    & $python -m pip --version
    if ($LASTEXITCODE -ne 0) {
        & $python -m ensurepip --upgrade
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not prepare pip for Python 3.9.'
        }
    }

    # Preserve other entries and add the two Python directories only once.
    $installDir = Split-Path -Parent $python
    $scriptsDir = Join-Path $installDir 'Scripts'
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $pathEntries = @($installDir, $scriptsDir)
    foreach ($entry in ($userPath -split ';')) {
        $expanded = [Environment]::ExpandEnvironmentVariables($entry.Trim().Trim('"')).TrimEnd('\')
        if ($entry -and ($expanded -ine $installDir) -and ($expanded -ine $scriptsDir)) {
            $pathEntries += $entry
        }
    }
    [Environment]::SetEnvironmentVariable('Path', ($pathEntries -join ';'), 'User')

    Write-Host ''
    & $python --version
    Write-Host "Python location: $python"
    Write-Host 'Python and Scripts have been added to your user PATH.'
    Write-Host 'Close and reopen Terminal, CMD or PowerShell before using python and pip.'
    if (Get-Command py.exe -CommandType Application -ErrorAction SilentlyContinue) {
        Write-Host 'To select Python 3.9 when other versions are installed: py -3.9'
    }
    else {
        Write-Host 'If another Python version is selected, use the full Python location shown above.'
    }
    exit 0
}
catch {
    Write-Host ''
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
