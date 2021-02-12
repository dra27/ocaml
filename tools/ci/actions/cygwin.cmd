@setlocal
@echo off

exit /b 1

set PLATFORM=%1

set CYG_ROOT=%CYG_ROOT%\%PLATFORM%
set CYG_CACHE=%CYG_ROOT%\var\cache\setup

if not exist C:\cache\nul md C:\cache
if not exist %CYG_ROOT%\nul md %CYG_ROOT%

  powershell -command "Invoke-WebRequest -Uri 'https://www.cygwin.com/setup-x86_64.exe' -OutFile '%CYG_ROOT%\setup-x86_64.exe'"
  if not exist %CYG_ROOT%\setup-x86_64.exe (
    echo Something went wrong with setup-x86_64.exe
    exit /b 1
  )
  powershell -command "Invoke-WebRequest -Uri 'https://github.com/alainfrisch/flexdll/archive/%FLEXDLL_VERSION%.tar.gz' -OutFile 'C:\cache\flexdll.tar.gz'"
  if not exist C:\cache\flexdll.tar.gz (
    echo Something went wrong with flexdll.tar.gz
    exit /b 1
  )
  powershell -command "Invoke-WebRequest -Uri 'https://github.com/alainfrisch/flexdll/releases/download/%FLEXDLL_VERSION%/flexdll-bin-%FLEXDLL_VERSION%.zip' -OutFile 'flexdll.zip'"
  if not exist flexdll.zip (
    echo Something went wrong with flexdll.zip
    exit /b 1
  )
  powershell -command "Expand-Archive -LiteralPath 'flexdll.zip' -DestinationPath 'flexdll'"
  if not exist flexdll\flexlink.exe (
    echo Something went wrong with flexlink.exe
    exit /b 1
  )
  move flexdll\flexlink.exe C:\cache\

  echo %DATE% %TIME%> C:\cache\stamp
  %CYG_ROOT%\setup-x86_64.exe --quiet-mode --no-shortcuts --no-startmenu --no-desktop --only-site --root "%CYG_ROOT%" --site "%CYG_MIRROR%" --local-package-dir "%CYG_CACHE%" --packages make,diffutils > nul
  rem powershell -command "Compress-Archive -LiteralPath C:\cygwin64 -DestinationPath C:\cache\cygwin.zip"
  rem C:\Windows\System32\tar.exe -cPzf C:\cache\cygwin.tgz C:\cygwin64
  echo Compressing C:\cygwin64
  echo This can take some time, with no output to the log
  "c:\Program Files\7-Zip\7z.exe" a -snl -m0=Copy C:\cache\cygwin.7z C:\cygwin64
