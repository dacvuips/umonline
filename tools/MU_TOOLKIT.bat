@echo off
chcp 65001 >NUL
title MU Toolkit - MuGodot
cd /d "%~dp0"
set PY=python
where py >NUL 2>NUL
if %errorlevel%==0 set PY=py -3

:menu
cls
echo ==========================================================
echo                 MU TOOLKIT  -  MuGodot
echo ==========================================================
echo   1. Chuyen TAT CA (model + ban do + kiem tra)
echo   7. Chuyen BAN DO (tat ca World / hoac so map)
echo   2. Chuyen 1 thu muc (vd: Player / Monster / NPC / Item / Skill / Effect)
echo   3. Chuyen LAI tu dau (ghi de tat ca)
echo   4. Kiem tra du lieu (bao cao model con thieu)
echo   5. Mo bao cao kiem tra
echo   6. Dat duong dan Client\Data
echo   0. Thoat
echo ----------------------------------------------------------
set /p CH=Chon: 
if "%CH%"=="1" %PY% mu_toolkit.py all & pause & goto menu
if "%CH%"=="2" goto one
if "%CH%"=="3" %PY% mu_toolkit.py all --force & pause & goto menu
if "%CH%"=="4" %PY% mu_toolkit.py check & pause & goto menu
if "%CH%"=="5" start "" notepad "%~dp0..\assets\mu\mu_report.txt" & goto menu
if "%CH%"=="6" goto cfg
if "%CH%"=="7" goto maps
if "%CH%"=="0" exit /b
goto menu

:maps
set MP=
set /p MP=So map (vd 3,4 - de trong = tat ca): 
%PY% mu_toolkit.py maps %MP%
pause
goto menu

:one
set /p FD=Ten thu muc (cach nhau dau phay): 
%PY% mu_toolkit.py models %FD%
pause
goto menu

:cfg
set /p DR=Duong dan Client\Data (vd E:\MuMain\Client\Data): 
%PY% mu_toolkit.py config "%DR%"
pause
goto menu
