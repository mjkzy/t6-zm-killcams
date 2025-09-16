@echo off
setlocal enableDelayedExpansion
setlocal enableExtensions

:: clear out any gsc, zip, and tmp/ files from previous runs
del *.gsc /s /f /q > nul 2>&1
del *.zip /s /f /q > nul 2>&1
rd /s /q tmp > nul 2>&1

mkdir tmp

:: put main gscs into one file
set "crt_dir=%~dp0"
for %%I in ("%crt_dir%\..") do set "root=%%~fI"
set "SEARCHPATH=%root%\src\gsc"

set "MAINFILE=%cd%\tmp\main.gsc"
set "OUTFILE=%cd%\tmp\maps\mp\gametypes_zm\_clientids.gsc"

:: start the file with XB360 define
echo #define XB360 true > "%MAINFILE%"

for /F %%x in ('dir /B/D "%SEARCHPATH%\*.gsc"') do (
  type %SEARCHPATH%\%%x >> "%MAINFILE%"
)

mkdir "%cd%\tmp\maps\mp\gametypes_zm"
copy /Y "%MAINFILE%" "%OUTFILE%" >nul
set "FileName=%1"
del "%MAINFILE%" /s /f /q > nul 2>&1

:: compile all files from temp
gsc-tool.exe -m comp -g t6 -s xb2 %cd%\tmp\

echo - compiled gsc for xboz 360

:: ZIP all the gsc together
start /wait 7za a %FileName% .\tmp\* > nul
echo - zipped gsc

pause