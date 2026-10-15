@echo off
setlocal

set "BUILDER_DIR=%~dp0"
set "SOURCE_DIR=%~1"
if not defined SOURCE_DIR set "SOURCE_DIR=%BUILDER_DIR%..\shandalar-sdl3"
for %%i in ("%SOURCE_DIR%") do set "SOURCE_DIR=%%~fi"
if not exist "%SOURCE_DIR%\CMakeLists.txt" (
  echo Source checkout not found: "%SOURCE_DIR%" >&2
  exit /b 1
)

set "VS_INSTALL="
for /f "usebackq tokens=*" %%i in (`call "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -version "[18.0,19.0)" -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VS_INSTALL=%%i"
if not defined VS_INSTALL (
  echo Visual Studio 2026 C++ x86 tools are required. >&2
  exit /b 1
)
call "%VS_INSTALL%\Common7\Tools\VsDevCmd.bat" -arch=x86 -host_arch=x64
if errorlevel 1 exit /b %errorlevel%
set "PATH=%ProgramFiles%\LLVM\bin;%VS_INSTALL%\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja;%PATH%"
clang-cl --version
if errorlevel 1 exit /b %errorlevel%

cmake -S "%SOURCE_DIR%" -B "%BUILDER_DIR%out/build" -G Ninja ^
  -DCMAKE_BUILD_TYPE=MinSizeRel ^
  -DCMAKE_C_COMPILER=clang-cl ^
  -DCMAKE_CXX_COMPILER=clang-cl ^
  -DCMAKE_C_COMPILER_TARGET=i686-pc-windows-msvc ^
  -DCMAKE_CXX_COMPILER_TARGET=i686-pc-windows-msvc ^
  -DCMAKE_EXE_LINKER_FLAGS=/machine:x86 ^
  -DCMAKE_SHARED_LINKER_FLAGS=/machine:x86 ^
  -DCMAKE_MODULE_LINKER_FLAGS=/machine:x86 ^
  -DCMAKE_STATIC_LINKER_FLAGS=/machine:x86 ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  -DCMAKE_RUNTIME_OUTPUT_DIRECTORY="%BUILDER_DIR%out/bin" ^
  -DSHANDALAR_DEFAULT_ASSET_DIR=. ^
  -DSHANDALAR_BUILD_FACEMAKER=OFF ^
  -DSHANDALAR_BUILD_SHANDALAR=ON ^
  -DSHANDALAR_BUILD_DECK=OFF ^
  -DSHANDALAR_BUILD_TESTS=OFF
if errorlevel 1 exit /b %errorlevel%
cmake --build "%BUILDER_DIR%out/build" --parallel
exit /b %errorlevel%

