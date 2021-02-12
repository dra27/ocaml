@setlocal
@echo off

if not exist %CACHE_ROOT%\base\base.wim (
  echo Internal fault: %CACHE_ROOT%\base\base.wim not found
  echo This step should not have been executed
  exit /b 1
)

pushd D:\
"C:\Program Files\7-Zip\7z.exe" x %CACHE_ROOT%\base\base.wim
popd

if not exist %CACHE_ROOT%\build md %CACHE_ROOT%\build

if exist %CACHE_ROOT%\build\build.wim (
  fc %CACHE_ROOT%\base\stamp %CACHE_ROOT%\build\stamp > nul
  if errorlevel 1 (
    echo Base Cygwin image updated - resetting build cache
    del %CACHE_ROOT%\build\build.wim
  )
)

if not exist %CACHE_ROOT%\build\build.wim (
  copy /y %CACHE_ROOT%\base\stamp %CACHE_ROOT%\build\stamp > nul
  if "%1" neq "" (
    robocopy /e %CYG_ROOT%\ %CYG_ROOT%.bak\ > nul
    %CYG_ROOT%\setup.exe --quiet-mode --no-shortcuts --no-startmenu --no-desktop --only-site --root "%CYG_ROOT%" --site "%CYG_MIRROR%" --local-package-dir "%CYG_CACHE%" --packages %*
    for /f "tokens=1,2* delims=\" %%n in ('dir /s/b/a-d %CYG_ROOT%.bak') do (
      if exist "%CYG_ROOT%\%%p" (
        for /f "delims=" %%a in ("%CYG_ROOT%.bak\%%p") do (
          for /f "delims=" %%b in ("%CYG_ROOT%\%%p") do (
            if "%%~ta" equ "%%~tb" (
              attrib -s "%CYG_ROOT%\%%p"
              del /f "%CYG_ROOT%\%%p"
            )
          )
        )
      )
    )
    "C:\Program Files\7-Zip\7z.exe" a -snl -twim %CACHE_ROOT%\build\build.wim %CYG_ROOT%
    rd /s/q %CYG_ROOT%
    pushd D:\
    "c:\Program Files\7-Zip\7z.exe" x %CACHE_ROOT%\base\base.wim
    popd
  )
)

if exist %CACHE_ROOT%\build\build.wim (
  pushd D:\
  "C:\Program Files\7-Zip\7z.exe" x -aoa %CACHE_ROOT%\build\build.wim
  popd
)
