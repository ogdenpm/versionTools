@echo off
setlocal

if /I "%~1" == "-v" (echo %0: Rev _REVISION_) & goto :EOF

:doOpt
if [%1] == [] goto execute
if [%1] == [-q] (set QUIET=%1) else if [%1] == [-r] (set RECURSE=1) else goto usage
SHIFT /1
goto doOpt

:usage
echo usage: %0 [-v] ^| [-r] [-q]
echo where -v shows version info
echo       -r does a recursive listing
echo       -q supresses no Git info for file message
goto :eof

:execute

for %%I in (*) do if /I [%%~xI] neq [.exe] if [%%~nI] neq [] call filever %QUIET% %%I

if not defined RECURSE goto :eof

for /D %%D in (*) do (
    if [%%~nD] neq [] (
        echo %%D\
        for %%I in (%%D\*) do if /I [%%~xI] neq [.exe] if [%%~nI] neq [] call filever %QUIET% %%I
    )
)


