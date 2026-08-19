@echo off
title AutoGrading Server Launcher
echo Menjalankan Backend API dan Web Dashboard di jendela terpisah...
start "AutoGrading Backend" "%~dp0run_backend.bat"
start "AutoGrading Web" "%~dp0run_web.bat"
echo Layanan telah dinyalakan!
timeout /t 5
