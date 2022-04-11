rem
rem Development environment installer for Windows
rem
rem This script installs:
rem - MSYS2
rem - MinGW along with cmake and all the libs required to compile some gems
rem - rbenv-win
rem - Ruby within rbenv
rem - Bundler
rem

@echo off
setlocal

for /f "delims=" %%x in (%~dp0..\.ruby-version) do set RUBY_VERSION=%%x
echo "Set HOME, PATH and RBENV_ROOT for %RUBY_VERSION%"
set instpath="%USERPROFILE%\.rbenv-win"
set RBENV_ROOT="%instpath%"
set HOME=%~dp0
set PATH=C:\MSYS2\usr\bin;C:\MSYS2\usr\local\bin;%instpath%\versions\%RUBY_VERSION%\bin;%instpath%\bin;%instpath%\shims;%PATH%
setx RBENV_ROOT %instpath%
setx HOME %~dp0

rem Get current path from registry
for /f "skip=2 delims=" %%a in ('reg query HKCU\Environment /v Path') do set orgpath=%%a

rem Set it back with all our new locations
reg add HKCU\Environment /v Path /d "C:\MSYS2\usr\bin;C:\MSYS2\usr\local\bin;%instpath%\versions\%RUBY_VERSION%\bin;%instpath%\bin;%instpath%\shims;%orgpath:~22%" /f

rem check new PATH environment
for /f "skip=2 delims=" %%a in ('reg query HKCU\Environment /v Path') do set orgpath=%%a
echo New PATH user local environment variable :"%orgpath:~22%"
echo

echo "Installing MSYS2"
if not exist "%~dp0msys2-x86_64-20220319.exe" (
  cscript "%~dp0getmsys2.vbs"
)

if not exist C:\MSYS2\ (
  call %~dp0msys2-x86_64-20220319.exe install --root C:\MSYS2 --confirm-command

  echo "Installing MinGW"
  pacman -Sy
  pacman --needed --noconfirm -S mingw-w64-i686-toolchain
  pacman --needed --noconfirm -S mingw-w64-i686-cmake
  pacman --needed --noconfirm -S base-devel
  pacman --needed --noconfirm -S git
)

echo "Cloning rbenv-win"
if exist %instpath%\ (
  pushd %~dp0
  cd %instpath%
  git pull
  popd
) else (
  git clone https://github.com/tarekziade/rbenv-win.git %instpath%
)

echo "Installing Ruby"
call rbenv install -s "%RUBY_VERSION%"
call rbenv global "%RUBY_VERSION%"
