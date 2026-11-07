#!/bin/bash
set -e

GRUPO_DIR="grupo10"
OUTPUT_ZIP="${GRUPO_DIR}.zip"

if [ ! -d "$GRUPO_DIR" ]; then
  echo "Erro: Diretório $GRUPO_DIR não encontrado na raiz."
  exit 1
fi

rm -f "$OUTPUT_ZIP"

# Compacta estritamente o diretório grupo10 ignorando arquivos temporários e pastas de build/dependências
zip -r "$OUTPUT_ZIP" "$GRUPO_DIR" -x "*.DS_Store" "*__pycache__*" "*.git*" "*node_modules/*" "*target/*" "*dist/*"

echo "Pacote gerado com sucesso: $OUTPUT_ZIP"
