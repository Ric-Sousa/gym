#!/bin/bash

echo "============================================"
echo " Configuracao de filtro git para paths"
echo "============================================"
echo ""

FLUTTER_PATH=$(which flutter 2>/dev/null)

if [ -z "$FLUTTER_PATH" ]; then
  if [ -f /c/Flutter/flutter/bin/dart ]; then
    DART_PATH="/c/Flutter/flutter/bin/dart"
    echo "Flutter SDK: /c/Flutter/flutter"
  elif [ -f /usr/local/flutter/bin/dart ]; then
    DART_PATH="/usr/local/flutter/bin/dart"
    echo "Flutter SDK: /usr/local/flutter"
  else
    echo "[ERRO] Flutter nao encontrado."
    echo "Adicione flutter ao PATH ou edite este script"
    echo "com o caminho correto do executavel dart."
    exit 1
  fi
else
  FLUTTER_DIR=$(dirname "$FLUTTER_PATH")
  DART_PATH="$FLUTTER_DIR/dart"
  echo "Flutter SDK: $FLUTTER_DIR"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/tools/fix_paths.dart"

echo ""

git config filter.pathfix.clean "$DART_PATH \"$SCRIPT_PATH\" clean"
git config filter.pathfix.smudge "$DART_PATH \"$SCRIPT_PATH\" smudge"

echo "[OK] Filter configurado com sucesso!"
echo ""
