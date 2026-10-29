@echo off
setlocal
title Python Runner - localhost:8001
rem Copy only this BAT to Windows 10/11 x64. Internet is needed on first run.
rem Python and dependencies are kept in LOCALAPPDATA\PythonRunner.
set "PY_RUNNER_BAT=%~f0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$text = [IO.File]::ReadAllText($env:PY_RUNNER_BAT); $parts = $text -split '(?m)^# (?:POWERSHELL|PYTHON)\r?\n', 3; if ($parts.Length -ne 3) { throw 'The BAT file is incomplete.' }; & ([ScriptBlock]::Create($parts[1]))"
set "PY_RUNNER_EXIT=%ERRORLEVEL%"
echo.
if not "%PY_RUNNER_EXIT%"=="0" echo Python Runner could not start or stopped with an error. See the message above.
pause
exit /b %PY_RUNNER_EXIT%

# POWERSHELL
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    if (-not [Environment]::Is64BitOperatingSystem) {
        throw 'This file requires 64-bit Windows 10 or 11.'
    }

    $pythonVersion = '3.13.17'
    $runtimeDir = Join-Path $env:LOCALAPPDATA "PythonRunner\python-$pythonVersion-x64"
    $python = Join-Path $runtimeDir 'python.exe'
    $readyFile = Join-Path $runtimeDir 'ready-fastapi-0.162.0-uvicorn-0.54.0.txt'

    if (-not ((Test-Path $python) -and (Test-Path $readyFile))) {
        Write-Host 'First run: downloading Python and server libraries. Internet is required.'
        New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
        $archive = Join-Path $runtimeDir 'python.zip'
        $pythonUrl = "https://www.python.org/ftp/python/$pythonVersion/python-$pythonVersion-embed-amd64.zip"
        Invoke-WebRequest -UseBasicParsing -Uri $pythonUrl -OutFile $archive
        Expand-Archive -LiteralPath $archive -DestinationPath $runtimeDir -Force

        # Allow the private runtime to load its private third-party packages.
        $sitePackages = Join-Path $runtimeDir 'Lib\site-packages'
        New-Item -ItemType Directory -Path $sitePackages -Force | Out-Null
        $pythonPaths = @('python313.zip', '.', 'Lib\site-packages', 'import site')
        Set-Content -LiteralPath (Join-Path $runtimeDir 'python313._pth') -Value $pythonPaths -Encoding ASCII

        $getPip = Join-Path $runtimeDir 'get-pip.py'
        Invoke-WebRequest -UseBasicParsing -Uri 'https://bootstrap.pypa.io/get-pip.py' -OutFile $getPip
        & $python $getPip --isolated --disable-pip-version-check --no-warn-script-location --target $sitePackages
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not prepare pip. Check the internet connection and run this BAT again.'
        }

        & $python -m pip --isolated install --upgrade --disable-pip-version-check --no-warn-script-location --only-binary=:all: --target $sitePackages 'fastapi==0.162.0' 'uvicorn==0.54.0'
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not download server libraries. Check the internet connection and run this BAT again.'
        }

        & $python -c 'import fastapi, uvicorn'
        if ($LASTEXITCODE -ne 0) {
            throw 'The downloaded Python environment could not load the server libraries.'
        }
        Set-Content -LiteralPath $readyFile -Value 'ready' -Encoding ASCII
    }

    # The server is included below, so no separate PY file is needed.
    $serverPath = Join-Path $runtimeDir 'python_server.py'
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($serverPath, $parts[2], $utf8)

    Write-Host ''
    Write-Host 'Python Runner: http://127.0.0.1:8001'
    Write-Host 'Health check:  http://127.0.0.1:8001/health'
    Write-Host 'Keep this window open. Press Ctrl+C to stop.'
    Write-Host ''
    & $python -X utf8 $serverPath
    exit $LASTEXITCODE
}
catch {
    Write-Host ''
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# PYTHON
#!/usr/bin/env python
"""
Python Server for Local Code Execution
Copy this file to your machine and run: python python_server.py
"""

import tempfile
import os
import shutil
import subprocess
import asyncio
import sys
import uvicorn
from typing import Optional
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

app = FastAPI(title="Python Runner API")

# Enable CORS for frontend access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class RunRequest(BaseModel):
    code: str = Field(..., min_length=1)
    input: Optional[str] = Field("", description="Input data for the program")
    timeout: Optional[int] = Field(5, description="Seconds before killing the run (default 5)")

class RunResult(BaseModel):
    stdout: str
    stderr: str
    exit_code: Optional[int]
    timed_out: bool = False
    error: Optional[str] = None

async def run_python(code: str, input_data: str = "", timeout: int = 5) -> RunResult:
    tmpdir = tempfile.mkdtemp(prefix="py-run-")
    script_name = "main.py"
    script_path = os.path.join(tmpdir, script_name)

    try:
        # Ghi code vào file
        with open(script_path, "w", encoding="utf-8") as f:
            f.write(code)

        # Chạy bằng subprocess với input
        proc = await asyncio.create_subprocess_exec(
            sys.executable, "-X", "utf8", script_path,
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )

        try:
            # Gửi input data nếu có
            input_bytes = input_data.encode('utf-8') if input_data else b''
            stdout, stderr = await asyncio.wait_for(
                proc.communicate(input=input_bytes), 
                timeout=timeout
            )
            return RunResult(
                stdout=stdout.decode(errors="ignore"),
                stderr=stderr.decode(errors="ignore"),
                exit_code=proc.returncode,
                timed_out=False
            )
        except asyncio.TimeoutError:
            proc.kill()
            await proc.wait()
            return RunResult(
                stdout="",
                stderr="Process killed due to timeout",
                exit_code=None,
                timed_out=True
            )

    except Exception as e:
        return RunResult(stdout="", stderr="", exit_code=None, timed_out=False, error=str(e))
    finally:
        # Dọn dẹp thư mục tạm
        try:
            shutil.rmtree(tmpdir)
        except Exception:
            pass

@app.post("/run", response_model=RunResult)
async def run_code(req: RunRequest):
    if len(req.code) > 20000:
        raise HTTPException(status_code=400, detail="Code too large (max 20000 characters).")

    print(f"Received code: {req.code[:100]}...")
    print(f"Received input: {repr(req.input)}")
    print(f"Input length: {len(req.input or '')}")
    
    result = await run_python(req.code, req.input or "", req.timeout or 5)
    return result

@app.get("/health")
def health():
    return {"status": "ok"}

if __name__ == "__main__":
    print("Starting Python Code Execution Server...")
    print("Server will run at: http://127.0.0.1:8001")
    print("Press Ctrl+C to stop the server.")
    print("Ready to execute Python code locally!")
    uvicorn.run("__main__:app", host="127.0.0.1", port=8001, reload=False)
