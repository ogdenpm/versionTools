rem @echo off
setlocal ENABLEDELAYEDEXPANSION

if [%~1] == [] goto START
if /i [%~1] neq [major] goto USAGE
set wantMAJOR=1
goto START

::--------
:USAGE
::--------
echo Usage: release [major]
echo Requires confirmation if outstanding commits or on master branch
goto :EOF


::--------
:START
::--------

set DEFAULTS_FILE=version.in
:: Application directory
for %%I in (%CD%) do set APPDIR=%%~nxI

call :getAPPID
:: Get which branch we are on and whether any outstanding commits in current tree
for /f "tokens=1,2 delims=. " %%A in ('"git status -s -b -uno -- . 2>NUL"') do (
    if [%%A] == [##] (
        set BRANCH=%%B
    ) else (
        if [%%A%%B] neq [] (
            set DIRTY=y
            goto :gotQualifier
        )
    )
)
:gotQualifier
if [%BRANCH%] == [HEAD] echo Cannot continue. Fix headless state before retrying & goto :eof
if defined DIRTY call :askYN YN "Outstanding Commits. Continue anyway y/N" & if [!YN!] neq [y] goto :eof
if [%BRANCH%] == [master] call :askYN YN "On master branch. Continue anyway y/N" & if [!YN!] neq [y] goto :eof


if [%APPID%] neq [] set strPREFIX=%APPID%-
:: Use git tag to get the lastest tag applicable to the contents of this directory
for /f "tokens=1"  %%A in ('"git tag -l %strPREFIX%[0-9]*.*[0-9] --sort=-v:refname --merged %GIT_SHA1% 2>NUL"') do (
    set strTAG=%%A
    goto :haveTag
)
:haveTag

@echo on
if [%strTAG%] == [] (
    if defined wantMAJOR (set newVERSION=1.0) else (set newVERSION=0.1)
    goto gotVersion
) 
if [%wantMAJOR%] neq [1] (
    :: get highest allocated Minor version for current Major version
    for /f "tokens=1 delims=." %%A in ("%strTAG:*-=%") do set curMAJOR=%%A
    for /f "tokens=2 delims=."  %%A in ('"git tag -l %strPREFIX%!curMAJOR!.*[0-9] --sort=-v:refname 2>NUL"') do (
        set /a newMINOR=%%A+1
        set newVERSION=!curMAJOR!.!newMINOR!
        goto gotVersion
    )
)
:: get highest allocated Major version number
for /f "tokens=1 delims=."  %%A in ('"git tag -l %strPREFIX%[0-9]*.*[0-9] --sort=-v:refname 2>NUL"') do (
    set tag=%%A
    set tag=!tag:*-=!
    set /a newMAJOR+=!tag!+1
    set newVERSION=!newMAJOR!.0
    goto gotVersion
    )
:gotVersion

set GIT_VERSION=%newVERSION%.0.X
if [%BRANCH%] neq [master] set GIT_VERSION=%GIT_VERSION%-%BRANCH%

call :gmtNow NOW


if defined writeDEFAULT (
    echo // Autogenerated default version file>"%DEFAULTS_FILE%"
    echo #ifndef v%newVERSION:.=_%_0_3>>"%DEFAULTS_FILE%"
    echo #define v%newVERSION:.=_%_0_3>>"%DEFAULTS_FILE%"
    if [%APPID%] neq [] echo #define GIT_APPID       "%APPID%">>"%DEFAULTS_FILE%"
    echo #define GIT_VERSION     "%GIT_VERSION%">>"%DEFAULTS_FILE%"
    echo #define GIT_VERSION_RC  %newVERSION:.=,%,0,3>>"%DEFAULTS_FILE%"
    echo #define GIT_SHA1        "untracked">>"%DEFAULTS_FILE%"
    echo #define GIT_BUILDTYPE   3>>"%DEFAULTS_FILE%"
    echo #define GIT_APPDIR      "%APPDIR%">>"%DEFAULTS_FILE%"
    echo #define GIT_TIME        "%NOW%">>"%DEFAULTS_FILE%"
    echo #define GIT_YEAR        "%NOW:~,4%">>"%DEFAULTS_FILE%"
    echo #endif>>"%DEFAULTS_FILE%"
    if [%writeDEFAULT%] == [2] git add %DEFAULTS_FILE%
    git add -u -- .
)
set GIT_COMMITTER_DATE=%NOW% +0000
if [%APPID%] neq [] (set newTAG=%APPID%-%newVERSION%) else (set newTAG=%newVERSION%)
if defined wantMAJOR (
    set newMsg=Major release %newVersion%.0 tag %newTAG%
) else (
    set newMsg=Minor release %newVersion%.0 tag %newTAG%
)
git commit -m "%newMsg%" -e -- .
git tag -a -m "%newMsg%" %newTAG%
goto :eof

:getAPPID
if exist %DEFAULTS_FILE% (
    set writeDEFAULT=1
    for /f "tokens=1,2,*" %%A in (%DEFAULTS_FILE%) do (
        if [%%B] == [GIT_APPID] (
            set APPID=%%~C
            goto :eof
        )
    )
    goto :eof
) 
set /p YN=No %DEFAULTS_FILE%. Create one y/N? 
if [%YN%] == [] goto :eof
if /i [%YN:~,1%] neq [y] goto :EOF
set writeDEFAULT=2
set /p APPID=Enter AppId - using . will default to %APPDIR%? 
if [%APPID%] == [.] set APPID=%APPDIR%
goto :EOF


:askYN  yn prompt
setlocal
set /p YN=%~2?
set YN=%YN%X
if /i [%YN:~0,1%] == [y] set YN=y
endlocal & set %1=%YN%
goto :eof




:gmtNow var
setlocal
:: wmic leave milliseconds blank and FOR doesn't pick this up so tokens adjusted accordingly
for /f "tokens=2,4,5,6,8,10 skip=1 delims=," %%A in ('wmic path Win32_UTCTime get /format:csv') do (
        if %%A lss 10 (set d=0%%A) else (set d=%%A)
        if %%B lss 10 (set h=0%%B) else (set h=%%B)
        if %%C lss 10 (set n=0%%C) else (set n=%%C)
        if %%D lss 10 (set m=0%%D) else (set m=%%D)
        if %%E lss 10 (set s=0%%E) else (set s=%%E)
        set y=%%F
    )
)
endlocal & set %1=%y%-%m%-%d% %h%:%n%:%s%
goto :eof
