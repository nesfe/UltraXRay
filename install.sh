#!/usr/bin/env bash
set -euo pipefail

RAW_URL="https://raw.githubusercontent.com/nesfe/UltraXRay/main/scripts/install-ultraxray.sh"

if [[ -f "./scripts/install-ultraxray.sh" ]]; then
  printf 'Запуск локального установщика UltraXRay\n'
  bash "./scripts/install-ultraxray.sh"
  exit 0
fi

printf 'Загрузка установщика UltraXRay из GitHub\n'
bash <(curl -fsSL "${RAW_URL}")
