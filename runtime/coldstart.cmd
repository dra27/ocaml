@setlocal
@echo off

if "%1" equ "genprims" goto GenPrims
if "%1" equ "genopnames" goto GenOpnames
if "%1" equ "genversion" goto GenVersion

setlocal enabledelayedexpansion

set BYTECODE=
set PRIMS=
for /f "delims=" %%F in ('findstr /R "^[^#]" ALL_C_SOURCES') do (
  for %%C in (%%F) do (
    call :DisplayFile %%C
  )
)

(
  for /f "tokens=1,2,3 delims=( " %%P in ('findstr /R /C:"^CAMLprim " %PRIMS%') do echo %%R
  for /f "tokens=2 delims=()" %%F in ('findstr /R "^CAMLprim_int64" ints.c') do (
    echo caml_int64_%%F
    echo caml_int64_%%F_native
  )
) > primitives.t
set LAST=
(
  for /f %%P in ('sort /L C primitives.t') do if "%%P" neq "!LAST!" (
    set LAST=%%P
    echo %%P
  )
) > primitives
del primitives.t

call %0 genprims > prims.c
call %0 genopnames > caml\opnames.h
call %0 genversion > caml\version.h

rem @@DRA These still need checking!
cl -c -nologo -O2 -Gy- -MD -D_CRT_SECURE_NO_DEPRECATE -DCAML_NAME_SPACE -DUNICODE -D_UNICODE -DWINDOWS_UNICODE=1 -DOCAML_STDLIB_DIR="L""C:/ocamlms64/lib/ocaml""" -I C:\flexdll-0.37 %BYTECODE% prims.c
link -lib -nologo -machine:AMD64 -out:libcamlrun.lib%BYTECODE:.c=.obj%
flexlink -x64 -exe -link /ENTRY:wmainCRTStartup prims.obj libcamlrun.lib advapi32.lib ws2_32.lib version.lib -o ocamlrun.exe

goto :EOF

:DisplayFile
if "%1" equ "$(UNIX_OR_WIN32)" (
  set FILE=win32
) else (
  set FILE=%1
)
if "%FILE:~0,1%" equ ":" (
  set PRIM=1
) else (
  set PRIM=0
)
set FILE=%FILE::=%
set FILE=%FILE:PLATFORM=_byt%
if "%FILE:~0,1%" neq "N" (
  set BYTE=1
  if "%FILE:~0,1%" equ "B" (
    set FILE=%FILE:~1%.c
  ) else (
    set FILE=%FILE%.c
  )
) else (
  set BYTE=0
)
if %BYTE% equ 1 set BYTECODE=%BYTECODE% %FILE%
if %PRIM% equ 1 set PRIMS=%PRIMS% %FILE%
goto :EOF

:GenPrims
echo #define CAML_INTERNALS
echo #include "caml/mlvalues.h"
echo #include "caml/prims.h"
for /f %%L in (primitives) do echo extern value %%L();
echo c_primitive caml_builtin_cprim[] = {
for /f %%L in (primitives) do echo   %%L,
echo   0 };
echo char * caml_names_of_builtin_cprim[] = {
for /f %%L in (primitives) do echo   "%%L",
echo   0 };
goto :EOF

:GenOpnames
echo static char * names_of_instructions [] = {
for /f "tokens=1-8,* delims=, " %%A in ('findstr /R /C:"^  [A-Z]" caml\instruct.h') do (
  if "%%I" neq "" (
    rem This gets hit if there are too many instructions on a single line
    echo Scripting fault in %~nx0 - insufficient tokens to generate caml\opnames.h>&2
    exit /b 1
  )
  if "%%H" equ "" (
    if "%%G" equ "" (
      if "%%F" equ "" (
        if "%%E" equ "" (
          if "%%D" equ "" (
            if "%%C" equ "" (
              if "%%B" equ "" (
                echo   "%%A",
              ) else (
                echo   "%%A", "%%B",
              )
            ) else (
              echo   "%%A", "%%B", "%%C",
            )
          ) else (
            echo   "%%A", "%%B", "%%C", "%%D",
          )
        ) else (
          echo   "%%A", "%%B", "%%C", "%%D", "%%E",
        )
      ) else (
        echo   "%%A", "%%B", "%%C", "%%D", "%%E", "%%F",
      )
    ) else (
      echo   "%%A", "%%B", "%%C", "%%D", "%%E", "%%F", "%%G"
    )
  ) else (
    echo   "%%A", "%%B", "%%C", "%%D", "%%E", "%%F", "%%G", "%%H",
  )
)
echo "FIRST_UNIMPLEMENTED_OP"};
goto :EOF

:GenVersion
for /f "tokens=1-4,* delims=.+" %%A in ('findstr /R "^[^#]" ..\VERSION') do (
  if "%%E" neq "" (
    echo Error parsing version number>&2
    exit /b 1
  )
  echo #define OCAML_VERSION_MAJOR %%A
  call :OutputVersionMinor %%B
  echo #define OCAML_VERSION_PATCHLEVEL %%C
  if "%%D" equ "" (
    echo #undef OCAML_VERSION_ADDITIONAL
  ) else (
    echo #define OCAML_VERSION_ADDITIONAL "%%D"
  )
  if %%C lss 10 (
    echo #define OCAML_VERSION %%A%%B0%%C
  ) else (
    echo #define OCAML_VERSION %%A%%B%%C
  )
)
for /f "delims=" %%V in ('findstr /R "^[^#]" ..\VERSION') do echo #define OCAML_VERSION_STRING "%%V"
goto :EOF
:OutputVersionMinor
set MINOR=%1
if "%MINOR:~0,1%" equ "0" (
  echo #define OCAML_VERSION_MINOR %MINOR:~1%
) else (
  echo #define OCAML_VERSION_MINOR %MINOR%
)
goto :EOF
