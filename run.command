#!/bin/bash
# Self-contained Python Runner for macOS and Linux. Internet is needed on first run.
set -euo pipefail

handle_exit() {
    local status="$1"
    if [ "$status" -ne 0 ] && [ "$status" -ne 130 ]; then
        printf '\nSetup or server stopped with an error (exit %s). See the message above.\n' "$status" >&2
        if [ -t 0 ]; then
            read -r -p 'Press Enter to close...' || true
        fi
    fi
}
trap 'handle_exit $?' EXIT

download() {
    if command -v curl >/dev/null 2>&1; then
        curl --fail --location --retry 2 --connect-timeout 20 --output "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget --tries=3 --timeout=20 -O "$2" "$1"
    else
        printf 'Please install curl or wget, then run this file again.\n' >&2
        return 1
    fi
}

system="$(uname -s)"
machine="$(uname -m)"
case "$system-$machine" in
    Darwin-arm64|Darwin-aarch64)
        target='aarch64-apple-darwin'
        expected_hash='e5af2fde6a937a0e0c795a0c595c4efb70578d57463a2657c819992b9b9acbac'
        ;;
    Darwin-x86_64)
        target='x86_64-apple-darwin'
        expected_hash='708be9e7df297f68bdae589ea9e62a621db5abe7708f79e851c41410347452d1'
        ;;
    Linux-aarch64|Linux-arm64)
        target='aarch64-unknown-linux-gnu'
        expected_hash='b48451865bde9a39e2f3e71d7fdcbf1f32615f50f24d78dc50d04ede6501cf81'
        ;;
    Linux-x86_64)
        target='x86_64-unknown-linux-gnu'
        expected_hash='126343c54daff4068efc1ac269518d0cc202d57857794948103dd1454e8881be'
        ;;
    *)
        printf 'Unsupported platform: %s %s. Use macOS or Linux on x64/ARM64.\n' "$system" "$machine" >&2
        exit 1
        ;;
esac

if [ "$system" = 'Darwin' ]; then
    data_dir="${XDG_DATA_HOME:-$HOME/Library/Application Support}/PythonRunner"
else
    if ! getconf GNU_LIBC_VERSION >/dev/null 2>&1; then
        printf 'This script requires Linux with glibc, such as Ubuntu, Debian or Fedora.\n' >&2
        exit 1
    fi
    data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/PythonRunner"
fi

# Keep the private runtime independent of another Python installation.
unset PYTHONHOME PYTHONPATH
export PYTHONNOUSERSITE=1

runtime_dir="$data_dir/python-3.13.18-$target"
python="$runtime_dir/python/bin/python3"
ready_file="$runtime_dir/ready-fastapi-0.162.0-uvicorn-0.54.0"

if [ ! -x "$python" ] || [ ! -f "$ready_file" ]; then
    printf 'First run: preparing Python and server libraries. Internet is required.\n'
    mkdir -p "$runtime_dir"
    if [ ! -x "$python" ]; then
        archive="$runtime_dir/python.tar.gz"
        url="https://github.com/astral-sh/python-build-standalone/releases/download/20261026/cpython-3.13.18%2B20261026-$target-install_only.tar.gz"
        download "$url" "$archive"
        if command -v shasum >/dev/null 2>&1; then
            actual_hash="$(LC_ALL=C shasum -a 256 "$archive")"
        elif command -v sha256sum >/dev/null 2>&1; then
            actual_hash="$(sha256sum "$archive")"
        else
            printf 'Please install shasum or sha256sum to check the Python download.\n' >&2
            exit 1
        fi
        if [ "${actual_hash%% *}" != "$expected_hash" ]; then
            printf 'The Python download is incomplete or invalid. Run this file again.\n' >&2
            exit 1
        fi
        tar -xzf "$archive" -C "$runtime_dir"
    fi
    "$python" -m pip --isolated install --upgrade --disable-pip-version-check --only-binary=:all: 'fastapi==0.162.0' 'uvicorn==0.54.0'
    "$python" -c 'import fastapi, uvicorn'
    printf 'ready\n' > "$ready_file"
fi

server_path="$runtime_dir/python_server.py"
cat > "$server_path" <<'PYTHON_RUNNER_CODE'
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
PYTHON_RUNNER_CODE

printf '\nPython Runner: http://127.0.0.1:8001\n'
printf 'Health check:  http://127.0.0.1:8001/health\n'
printf 'Keep this window open. Press Ctrl+C to stop.\n\n'
"$python" -X utf8 "$server_path"
