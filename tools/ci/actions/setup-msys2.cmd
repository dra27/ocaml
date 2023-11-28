@rem ***********************************************************************
@rem *                                                                     *
@rem *                                 OCaml                               *
@rem *                                                                     *
@rem *                        David Allsopp, Tarides                       *
@rem *                                                                     *
@rem *   Copyright 2023 David Allsopp Ltd.                                 *
@rem *                                                                     *
@rem *   All rights reserved.  This file is distributed under the terms    *
@rem *   of the GNU Lesser General Public License version 2.1, with the    *
@rem *   special exception on linking described in the file LICENSE.       *
@rem *                                                                     *
@rem ***********************************************************************

@setlocal
@echo off

:: GitHub Actions runners include an MSYS2 installation, but it doesn't include
:: the packages we need. The msys2/setup-msys2 action can maintain an
:: installation, but it only caches packages, so we end up with a non-trivial
:: amount of installation work for every CI run. We avoid this by instead
:: maintaining our own complete installation, which is fully cached.

:: Assumptions:
::  - Git checkout located at %GITHUB_WORKSPACE%
::  - Runner's installation of MSYS2 is at C:\msys64 (cf. https://github.com/actions/runner-images/blob/main/images/windows/Windows2022-Readme.md#msys2)
::  - MSYS2 installation maintained in D:\
::  - TODO XXX ...

:: Put the ASCII Escape Code into %ESC%
for /f "delims=#" %%e in ('prompt #$E# ^& for %%a in ^(1^) do rem') do set ESC=%%e

:: Stage 1: Set-up the PATH, etc. for the msys2 shell
if not exist %GITHUB_WORKSPACE%\bin\nul md %GITHUB_WORKSPACE%\bin
if not exist %GITHUB_WORKSPACE%\ocaml\tools\ci\actions\msys2.cmd (
  call :Error msys2.cmd script not found in the sources checkout - cannot proceed
  exit /b 1
)
copy /y %GITHUB_WORKSPACE%\ocaml\tools\ci\actions\msys2.cmd %GITHUB_WORKSPACE%\bin\msys2.cmd > nul
echo %GITHUB_WORKSPACE%\bin>> %GITHUB_PATH%

:: Stage 2: Determine version of the base installation

:: Either clone msys2/msys2-installer or fetch the latest
if exist %GITHUB_WORKSPACE%\msys2-installer\nul (
  git -C %GITHUB_WORKSPACE%\msys2-installer fetch upstream --tags
  if errorlevel 1 (
    call :Warning Failed to update cached clone of msys2/msys2-installer
  )
) else (
  git -C %GITHUB_WORKSPACE% clone -o upstream https://github.com/msys2/msys2-installer.git
  if errorlevel 1 (
    call :Error Failed to clone msys2/msys2-installer - cannot proceed
    exit /b 1
  )
)

set LATEST_INSTALLER_VERSION=unknown
for /f "delims=" %%t in ('git -C %GITHUB_WORKSPACE%\msys2-installer tag ^| findstr "[0-9]*-[0-9]*-[0-9]*" ^| sort') do (
  set LATEST_INSTALLER_VERSION=%%t
)
if "%LATEST_INSTALLER_VERSION%" equ "unknown" (
  call :Error Unable to determine MSYS2 installer version - cannot proceed
  exit /b 1
)

:: TODO Remove this!
set LATEST_INSTALLER_VERSION=2023-01-27

if not exist %GITHUB_WORKSPACE%\msys2\current (
  set CURRENT_INSTALLER_VERSION=unknown
) else (
  for /f "delims=" %%v in ('type %GITHUB_WORKSPACE%\msys2\current') do set CURRENT_INSTALLER_VERSION=%%v
)

if "%CURRENT_INSTALLER_VERSION%" equ "unknown" (
  call :Info No previous version found: first time set-up assumed
) else (
  call :Info Current base version: %CURRENT_INSTALLER_VERSION%
  if not exist %GITHUB_WORKSPACE%\msys2\msys2.tar (
    call :Warning Installation cache not found - reinstalling
    del %GITHUB_WORKSPACE%\msys2\current
    set CURRENT_INSTALLER_VERSION=unknown
  )
)
set INSTALLER=msys2-base-x86_64-%LATEST_INSTALLER_VERSION:-=%.sfx.exe
set INSTALLER_URL=https://github.com/msys2/msys2-installer/releases/download/%LATEST_INSTALLER_VERSION%/%INSTALLER%
if "%LATEST_INSTALLER_VERSION%" equ "%CURRENT_INSTALLER_VERSION%" (
  call :Info Current base is up-to-date
  C:\msys64\usr\bin\tar.exe -C /d -pxf %GITHUB_WORKSPACE%\msys2\msys2.tar
  goto Finish
)

:: Fresh installation of MSYS2

:: Download and extract the base installation
call :Info New version: %LATEST_INSTALLER_VERSION%
for %%f in (current msys2.tar) do if exist %GITHUB_WORKSPACE%\msys2\%%f del %GITHUB_WORKSPACE%\msys2\%%f
if not exist %GITHUB_WORKSPACE%\msys2 md %GITHUB_WORKSPACE%\msys2
curl --location --no-progress-meter --output %GITHUB_WORKSPACE%\msys2\%INSTALLER% %INSTALLER_URL%
if errorlevel 1 (
  call :Error Failed to download %INSTALLER_URL%
  exit /b 1
)
echo ::group::Extracting MSYS2
%GITHUB_WORKSPACE%\msys2\%INSTALLER% -y -oD:\
if errorlevel 1 (
  del %GITHUB_WORKSPACE%\msys2\%INSTALLER%
  call :Error Base installation failed to extract
  exit /b 1
)
del %GITHUB_WORKSPACE%\msys2\%INSTALLER%
echo Done
echo ::endgroup::

:: Set-up procedure adapted from msys2/setup-msys2
:: Disable Key Refresh
:: Windows equivalent of sed -i.orig -e '/--refresh-keys/d' /etc/post-install/07-pacman-key.post
ren D:\msys64\etc\post-install\07-pacman-key.post 07-pacman-key.post.orig
findstr /V /C:--refresh-keys D:\msys64\etc\post-install\07-pacman-key.post.orig > D:\msys64\etc\post-install\07-pacman-key.post

echo ::group::Running MSYS2 for the first time
D:\msys64\usr\bin\bash.exe -lec uname -a
if errorlevel 1 (
  call :Error First-time operation failed - unable to proceed
  exit /b 1
)
echo ::endgroup::

:: Disable disk space checking in Pacman
ren D:\msys64\etc\pacman.conf pacman.conf.orig
findstr /V /C:CheckSpace D:\msys64\etc\pacman.conf.orig > D:\msys64\etc\pacman.conf

echo ::group::Updating the base installation
D:\msys64\usr\bin\bash.exe -lec "pacman --noconfirm -Syuu --overwrite *"
taskkill /F /FI "MODULES eq msys-2.0.dll"
D:\msys64\usr\bin\bash.exe -lec "pacman --noconfirm -Syuu --overwrite *"
if errorlevel 1 (
  call :Error Updating MSYS2 has failed - unable to proceed
  exit /b 1
)
dir D:\msys64\etc\pacman.conf*
dir D:\msys64\etc\post-install\07*
exit /b 1
echo ::endgroup::

echo %LATEST_INSTALLER_VERSION%> %GITHUB_WORKSPACE%\msys2\current

:Finish

echo msys2-release=%LATEST_INSTALLER_VERSION%>> %GITHUB_ENV%

rem TODO When testing this, the msys2 cache should be written _even_ if the build itself fails (unlike actions/cache)
rem TODO Is this part of the later stage?
D:\msys64\usr\bin\bash.exe -le %GITHUB_WORKSPACE%\ocaml\tools\ci\actions\msys2.sh
if errorlevel 1 (
  call :Error Checking MSYS2 failed - unable to proceed
  exit /b 1
)

if not exist %GITHUB_WORKSPACE%\msys2\msys2.tar (
  call :Info Updating cache
  pushd %GITHUB_WORKSPACE%\msys2 > nul
  C:\msys64\usr\bin\tar.exe -C /d -pcf msys2.tar msys64
  popd > nul
  echo Done
)

goto :EOF

:Info
echo [%ESC%[1;34mINFO%ESC%[0m] %*
goto :EOF

:Error
echo [%ESC%[1;31mERROR%ESC%[0m] %*
goto :EOF

:Warning
echo [%ESC%[1;33mWARNING%ESC%[0m] %*
goto :EOF
