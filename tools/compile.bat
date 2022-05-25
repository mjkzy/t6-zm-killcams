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

for /F %%x in ('dir /B/D "%SEARCHPATH%\*.gsc"') do (
  type %SEARCHPATH%\%%x >> %cd%\tmp\main.gsc
)

set FileName=%1

:: copy all folders from .\src\gsc\ into %cd%\temp\
for /F %%i in ('dir /a:d /b "%SEARCHPATH%\*"') do (
  robocopy %SEARCHPATH%\%%i %cd%\tmp\%%i /s /e > nul
)

:: compile all files from temp
gsc-tool.exe comp t6 %cd%\tmp\ > nul

echo - compiled gsc

:: type setup.txt into tmp
echo %cd%\setup.txt
type %cd%\setup.txt >> %cd%\tmp\setup.txt

:: ZIP all the gsc together
start /wait 7za a %FileName% .\tmp\* > nul
echo - zipped gsc
