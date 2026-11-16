#!/usr/bin/env bash
set -euo pipefail

echo "=== 1. Compilando Frontend em modo Banco de Dados (VITE_APP_MODE=bd) ==="
(
  cd grupo10/app/frontend
  npm install
  npm run build:bd
)

echo "=== 2. Empacotando entrega limpa (grupo10.zip) ==="
./package.sh
