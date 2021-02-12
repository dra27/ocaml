@echo off
if "%2" equ "msvc64" call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\VC\Auxiliary\Build\vcvars64.bat"
if "%2" equ "msvc32" call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\VC\Auxiliary\Build\vcvars32.bat"

if "%1" equ "configure" (
  rem Work-around https://github.com/ocaml/ocaml/issues/9732
  del "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\VC\Tools\MSVC\vctip.exe" /s
)
