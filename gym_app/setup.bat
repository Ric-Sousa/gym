@echo off
echo Configurando git filter para paths dinamicos...
git config filter.pathfix.clean "dart tools/fix_paths.dart clean"
git config filter.pathfix.smudge "dart tools/fix_paths.dart smudge"
echo Filter configurado com sucesso!
echo.
echo Agora execute: git add -f .dart_tool/package_config.json .dart_tool/package_graph.json
echo Depois faca commit normalmente.
