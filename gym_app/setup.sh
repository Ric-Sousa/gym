#!/bin/bash
echo "Configurando git filter para paths dinâmicos..."
git config filter.pathfix.clean "dart tools/fix_paths.dart clean"
git config filter.pathfix.smudge "dart tools/fix_paths.dart smudge"
echo "Filter configurado com sucesso!"
echo ""
echo "Agora execute: git add -f .dart_tool/package_config.json .dart_tool/package_graph.json"
echo "Depois faça commit normalmente."
