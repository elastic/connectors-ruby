rem
rem Makefile for Windows
rem
rem This batch script makes the assumption that your rbenv environment is installed.
rem A fully automated install script is provided in win32\install.bat
rem
@echo off
setlocal

set instpath="%USERPROFILE%\.rbenv-win"
set RBENV_ROOT="%instpath%"
set HOME=%~dp0

for /f "delims=" %%x in (%~dp0.ruby-version) do set RUBY_VERSION=%%x
for /f "delims=" %%x in (%~dp0.bundler-version) do set BUNDLER_VERSION=%%x
echo "Ruby %RUBY_VERSION% - Bundler %BUNDLER_VERSION%"

set PATH=C:\MSYS2\usr\bin;C:\MSYS2\usr\local\bin;%instpath%\versions\%RUBY_VERSION%\bin;%instpath%\bin;%instpath%\shims;%PATH%

echo "Install gem dependencies..."
call %instpath%\versions\%RUBY_VERSION%\bin\gem install "bundler:%BUNDLER_VERSION%"
call %instpath%\versions\%RUBY_VERSION%\bin\bundle _%BUNDLER_VERSION%_ install --with test
call rbenv rehash

echo "Running tests..."
copy config\connectors.yml.example config\connectors.yml

call %instpath%\versions\%RUBY_VERSION%\bin\bundle exec %instpath%\versions\%RUBY_VERSION%\bin\rspec spec
