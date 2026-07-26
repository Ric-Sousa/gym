@echo off
setlocal enabledelayedexpansion

echo ============================================
echo  Configuracao de filtro git para paths
echo ============================================
echo.

where flutter >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERRO] Flutter nao encontrado no PATH.
    echo Adicione flutter ao PATH ou execute este script
    echo num terminal que tenha flutter disponivel.
    pause
    exit /b 1
)

for /f "delims=" %%i in ('where flutter') do set FLUTTER_PATH=%%i
for %%i in ("%FLUTTER_PATH%") do set FLUTTER_DIR=%%~dpi
set DART_PATH=%FLUTTER_DIR%dart.exe

set SCRIPT_PATH=%~dp0tools\fix_paths.dart

echo Flutter SDK: %FLUTTER_DIR%
echo.

git config filter.pathfix.clean "%DART_PATH% \"%SCRIPT_PATH%\" clean"
git config filter.pathfix.smudge "%DART_PATH% \"%SCRIPT_PATH%\" smudge"

echo [OK] Filter configurado com sucesso!
echo.
pause
