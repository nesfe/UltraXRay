#!/usr/bin/env bash
set -euo pipefail

RELEASE="v2026.10.01"
RAW_URL="https://raw.githubusercontent.com/nesfe/UltraXRay/${RELEASE}/scripts/install-ultraxray.sh"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${SCRIPT_DIR}/scripts/install-ultraxray.sh" ]]; then
  printf 'Запуск локального установщика UltraXRay\n'
  bash "${SCRIPT_DIR}/scripts/install-ultraxray.sh"
  exit 0
fi

printf 'Загрузка установщика UltraXRay из GitHub\n'
bash <(curl -fsSL "${RAW_URL}")
