@echo off
setlocal
title Rebuild palette_maker
cd /d "%~dp0"

set "ROOT=%~dp0..\..\..\.."
for %%I in ("%ROOT%") do set "ROOT=%%~fI"

set "N2F=%ROOT%\..\Next2Flash"
if not exist "%N2F%\app\n2f.py" set "N2F=%USERPROFILE%\Documents\GitHub\Next2Flash"
if not exist "%N2F%\app\n2f.py" (
  echo Next2Flash app\n2f.py not found.
  echo Expected next to SSF2 Shell Base, or under Documents\GitHub\Next2Flash.
  goto :fail
)

set "AIR_DIR=%N2F%\toolchain\aflex_lite\templates\air"
set "AIR_XML=%AIR_DIR%\descriptor-template.xml"
if not exist "%AIR_XML%" (
  echo Creating missing AIR descriptor template...
  mkdir "%AIR_DIR%" 2>nul
  >"%AIR_XML%" (
    echo ^<?xml version="1.0" encoding="utf-8" standalone="no" ?^>
    echo ^<!-- Minimal AIR descriptor so asconfigc can compile. --^>
    echo ^<application xmlns="http://ns.adobe.com/air/application/32.0"^>
    echo.  ^<id^>APPLICATIONNAMESPACE.id^</id^>
    echo.  ^<versionNumber^>APPLICATIONVERSION^</versionNumber^>
    echo.  ^<filename^>APPLICATIONFILENAME^</filename^>
    echo.  ^<description/^>
    echo.  ^<name^>APPLICATIONTITLE^</name^>
    echo.  ^<copyright/^>
    echo.  ^<initialWindow^>
    echo.    ^<title^>APPLICATIONTITLE^</title^>
    echo.    ^<content^>APPLICATIONCONTENT^</content^>
    echo.    ^<systemChrome^>standard^</systemChrome^>
    echo.    ^<transparent^>false^</transparent^>
    echo.    ^<visible^>true^</visible^>
    echo.  ^</initialWindow^>
    echo ^</application^>
  )
  if not exist "%AIR_XML%" (
    echo Failed to write %AIR_XML%
    goto :fail
  )
)

echo Compiling palette_maker...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\tools\build-mod.ps1" palette_maker
if errorlevel 1 goto :fail

echo.
echo OK — quit the game fully before testing the new swf.
pause
exit /b 0

:fail
echo.
echo FAILED.
pause
exit /b 1
