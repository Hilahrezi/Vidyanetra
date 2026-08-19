@echo off
title AutoGrading Backend API (Port 8000)
cd /d "%~dp0backend"
if not exist ".venv" (
    echo Virtual environment tidak ditemukan. Membuat .venv...
    python -m venv .venv
    call .venv\Scripts\activate
    pip install -r requirements.txt
) else (
    call .venv\Scripts\activate
)

echo ========================================================
echo   AutoGrading Backend API Server
echo   Host: http://0.0.0.0:8000
echo   Tailscale: http://100.78.211.26:8000
echo ========================================================
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
pause
