@echo off
title AutoGrading Web Dashboard (Port 3000)
cd /d "%~dp0web"
echo ========================================================
echo   AutoGrading Web Dashboard
echo   Host: http://0.0.0.0:3000
echo   Tailscale: http://100.78.211.26:3000
echo ========================================================
npm run dev -- -H 0.0.0.0 -p 3000
pause
