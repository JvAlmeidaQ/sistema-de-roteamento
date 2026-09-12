#!/bin/bash
set -e

GRUPO_DIR="grupoNN"
OUTPUT_ZIP="${GRUPO_DIR}.zip"

if [ ! -d "$GRUPO_DIR" ]; then
  echo "Erro: Diretório $GRUPO_DIR não encontrado na raiz."
  exit 1
fi

rm -f "$OUTPUT_ZIP"

# Compacta estritamente o diretório grupoNN ignorando arquivos temporários
zip -r "$OUTPUT_ZIP" "$GRUPO_DIR" -x "*.DS_Store" "*__pycache__*" "*.git*"

echo "Pacote gerado com sucesso: $OUTPUT_ZIP"
