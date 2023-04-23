@echo off
setlocal

if /I "%~1" == "-v" (echo %0: _REVISION_) & goto :EOF

:doOpt
if [%1] == [] goto execute
if [%1] == [-s] (set SUBDIR=1) else goto usage
SHIFT /1
goto doOpt

:usage
echo usage: %0 [-v] ^| [-s] [-q]
echo where -v shows version info
echo       -s also shows files in immediate sub-directories
goto :eof

:execute

for %%I in (*) do if /I [%%~xI] neq [.exe] call filever %QUIET% "%%I"

if not defined SUBDIR goto :eof

for /D %%D in (*) do (
    if [%%~nD] neq [] (
        echo %%D\
        for %%I in (%%D\*) do if /I [%%~xI] neq [.exe] call filever "%%I"
    )
)


