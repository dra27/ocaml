@setlocal
@echo off

dir c:\cache

rem TODO THis really should be in the global env
set CYG_ROOT=C:\cygwin64
set PORT=%1

pushd C:\
time < nul
time < nul
popd

rem TODO check the open PR for what needs doing with the C# tests
if "%PORT%" equ "msvc64" call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\VC\Auxiliary\Build\vcvars64.bat"
if "%PORT%" equ "msvc32" call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\VC\Auxiliary\Build\vcvars32.bat"

chcp 65001 > nul
set BUILD_PREFIX=🐫реализация
set OCAMLROOT=%PROGRAMFILES%\Бактріан🐫

git worktree add "..\%BUILD_PREFIX%-%PORT%" -b build-%PORT%

echo %CD%
dir ..
cd "..\%BUILD_PREFIX%-%PORT%"
echo %CD%
echo %GITHUB_WORKSPACE%
if exist %GITHUB_WORKSPACE%\flexdll\Makefile git submodule update --init flexdll

dir C:\
dir %CYG_ROOT%
dir %CYG_ROOT%\bin

rem XXX Tee hee
set GITHUB_WORKSPACE=D:/a/ocaml/ocaml
"%CYG_ROOT%\bin\bash.exe" -lc "%GITHUB_WORKSPACE%/tools/ci/actions/windows.sh" || exit /b 1
