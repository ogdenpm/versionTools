@echo off
SETLOCAL ENABLEDELAYEDEXPANSION
REM  Simplified version of version.cmd that shows the revisions to a specific file
REM  since creation.
REM  Limitation is that it does not track moves or renames (except case change)
::
:: Console output only
if /I "%~1" == "-v" (echo %0: Rev _REVISION_) & goto :EOF
set FILE=%~1
if [%FILE%] == [] goto USAGE
if exist "%FILE%" goto START
::
:: --------------------
:USAGE
:: --------------------
ECHO usage: fileVer file
GOTO :EOF


REM ===================
REM Entry Point
REM ===================
:START
CALL :GET_VERSION_STRING
if [%GIT_SHA1%] == [] (
        echo Cannot find Git information for %1
        exit /b 1
)
echo File:       %FILE%
echo Revision:   %GIT_COMMITS%%GIT_QUALIFIER%
echo Branch:     %GIT_BRANCH%
echo Git hash:   %GIT_SHA1%
echo Committed:  %GIT_CTIME%
exit /b 0



REM ====================
REM FUNCTIONS
REM ====================
:: --------------------
:GET_VERSION_STRING
:: --------------------
set SCOPE=:(icase)%FILE%

:: Get which branch we are on and whether any outstanding commits in current tree
for /f "tokens=1,2 delims=. " %%A in ('"git status -s -b -uno -- %SCOPE% 2>NUL"') do (
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

::
:: get the current SHA1 and commit time for items in this directory
for /f "tokens=1,2" %%A in ('git log -1 "--format=%%h %%ct" -- "%SCOPE%"') do (
    set GIT_SHA1=%%A
    call :gmTime GIT_CTIME %%B
)
:: get the commits in play
for /f "tokens=1" %%A in ('git rev-list --count HEAD -- "%SCOPE%"') do set GIT_COMMITS=%%A

goto :EOF

:: convert unix time to gmt yyyy-mm-dd hh:mm:ss
:gmtime gmtstr utime
setlocal
set /a z=%2/86400+719468,d=z%%146097,y=^(d-d/1460+d/36525-d/146096^)/365,d-=365*y+y/4-y/100,m=^(5*d+2^)/153
set /a d-=^(153*m+2^)/5-1,y+=z/146097*400+m/11,m=^(m+2^)%%12+1
set /a h=%2/3600%%24,mi=%2%%3600/60,s=%2%%60
if %m% lss 10 set m=0%m%
if %d% lss 10 set d=0%d%
if %h% lss 10 set h=0%h%
if %mi% lss 10 set mi=0%mi%
if %s% lss 10 set s=0%s%
endlocal & set %1=%y%-%m%-%d% %h%:%mi%:%s%
goto :EOF
