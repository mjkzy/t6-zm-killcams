@echo off

:: merge main mod
type "..\src\gsc\main.gsc" > "zm-killcams.gsc"
type "..\src\gsc\functions.gsc" >> "zm-killcams.gsc"
type "..\src\gsc\killcam.gsc" >> "zm-killcams.gsc"
type "..\src\gsc\utils.gsc" >> "zm-killcams.gsc"
echo - Generated zm-killcams file.

:: compile
Compiler.exe zm-killcams.gsc
del /f zm-killcams.gsc
ren "zm-killcams-compiled.gsc" "zm-killcams.gsc"
echo - Compiled zm-killcams file.
