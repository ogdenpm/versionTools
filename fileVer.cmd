@echo off
SETLOCAL ENABLEDELAYEDEXPANSION
REM  This offers a subset of the utility revisions.pl and only handles one file
::
:: Console output only
if /I "%~1" == "-v" (echo %0: Rev _REVISION_) & goto :EOF
if "%~1" == "-q" (
    SHIFT /1
)
if [%1] == [] goto USAGE
if not exist "%~1" goto USAGE
::
:: find the containing directory of the file
set PATHTO=%~p1
:: get the directory as a filename by removing trailing \
for %%I in ("%PATHTO:~,-1%") do set PARENT=%%~nxI
set FILE=%~1
if "%~1" neq "%~nx1" set HASDIR=YES
set FILE="%~1"

REM ===================
REM Entry Point
REM ===================
:START
CALL :GET_VERSION_STRING

:: pretty print the information on a single line
set FILE=%~nx1
call :pad FILE 20
if [%GIT_SHA1%] == [] echo %FILE% Untracked & goto :eof


if [%GIT_BRANCH%] neq [master] if [%GIT_BRAHCN%] neq [main] set GIT_VERSION=%GIT_BRANCH%-%GIT_VERSION%

echo %FILE% %GIT_VERSION% [%GIT_SHA1%]
exit /b 0

:: --------------------
:USAGE
:: --------------------
ECHO usage: fileVer [-v] ^| [-q] file
ECHO where -v shows version info
GOTO :EOF



REM ====================
REM FUNCTIONS
REM ====================
:: --------------------
:GET_VERSION_STRING
:: --------------------

:: Get which branch we are on and whether any outstanding commits in current tree
for /f "tokens=1,2 delims=. " %%A in ('git status -s -b -uno -- "%FILE%" 2^>NUL') do (
    if [%%A] == [##] (
        set GIT_BRANCH=%%B
    ) else (
        if [%%A%%B] neq [] (
            set GIT_QUALIFIER=+
            goto :gotQualifier
        )
    )
)
:gotQualifier
:: error then no git or not in a repo (ERRORLEVEL not reliable)
IF not defined GIT_BRANCH goto :EOF

:: get the current SHA1 and commit time for the file and the total number of commits
set COMMITS=0
for /f "tokens=1,2" %%A in ('git log  --follow -M100%% --first-parent "--format=%%h %%ct" -- "%FILE:"=%"') do (
    if !COMMITS! == 0 (
        set GIT_SHA1=%%A
        call :timeToVer GIT_VERSION %%B
    )
    set /A COMMITS=!COMMITS!+1
)

set GIT_VERSION=%GIT_VERSION%.%COMMITS%%GIT_QUALIFIER%
call :pad GIT_VERSION 14
goto :EOF


:: pad a field to a specified width
:pad str width
setlocal
set FIELD=!%~1!
set TWENTYSPACES=                    
call set TFIELD="!FIELD:~0,%~2!"
IF ["%FIELD%"] == [%TFIELD%] (
    set FIELD=%FIELD%%TWENTYSPACES%
    call set FIELD=!FIELD:~0,%~2!
)
endlocal & set %~1=%FIELD%
goto :EOF

:: convert unix time to gmt yyyy-mm-dd hh:mm:ss
:timeToVer verstr utime
setlocal
set /a z=%2/86400+719468,d=z%%146097,y=^(d-d/1460+d/36525-d/146096^)/365,d-=365*y+y/4-y/100,m=^(5*d+2^)/153
set /a d-=^(153*m+2^)/5-1,y+=z/146097*400+m/11,m=^(m+2^)%%12+1
endlocal & set %1=%y%.%m%.%d%
goto :EOF
