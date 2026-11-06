@echo off
title MU Online WebSocket Gateway Proxy
cd /d "%~dp0"

echo ========================================================
echo   MU Online WebSocket Gateway Proxy
echo   WebSocket: ws://127.0.0.1:8080
echo   OpenMU GameServer: 127.0.0.1:45901
echo ========================================================

python "gateway\ws_proxy.py"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [LOI] Chuong trinh bi dung dot ngot! Ma loi: %ERRORLEVEL%
    pause
)
pause
