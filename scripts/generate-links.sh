#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-/root/ultraproxy.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Файл доступов не найден: $ENV_FILE"
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

echo "VLESS XHTTP REALITY ссылка:"
echo
printf '%s\n' "$VLESS_LINK"
echo
echo "VLESS QR-код:"
echo
if command -v qrencode >/dev/null 2>&1; then
  printf '%s' "$VLESS_LINK" | qrencode -t ANSIUTF8
else
  echo "qrencode не установлен. Установите пакет: apt-get install -y qrencode"
fi

echo
echo "Hysteria 2 ссылка для Happ:"
echo
printf '%s\n' "$HY2_LINK"
echo
echo "Hysteria 2 QR-код:"
echo
if command -v qrencode >/dev/null 2>&1; then
  printf '%s' "$HY2_LINK" | qrencode -t ANSIUTF8
else
  echo "qrencode не установлен. Установите пакет: apt-get install -y qrencode"
fi

if [[ -n "${HY2_HOPPING_LINK:-}" ]]; then
  echo
  echo "Hysteria 2 Port Hopping ссылка:"
  echo
  printf '%s\n' "$HY2_HOPPING_LINK"
  echo
  echo "Hysteria 2 Port Hopping QR-код:"
  echo
  if command -v qrencode >/dev/null 2>&1; then
    printf '%s' "$HY2_HOPPING_LINK" | qrencode -t ANSIUTF8
  else
    echo "qrencode не установлен. Установите пакет: apt-get install -y qrencode"
  fi
fi

if [[ -n "${HY2_HAPP_LINK:-}" ]]; then
  echo
  echo "Hysteria 2 Happ compatibility ссылка:"
  echo
  printf '%s\n' "$HY2_HAPP_LINK"
  echo
  echo "Hysteria 2 Happ compatibility QR-код:"
  echo
  if command -v qrencode >/dev/null 2>&1; then
    printf '%s' "$HY2_HAPP_LINK" | qrencode -t ANSIUTF8
  else
    echo "qrencode не установлен. Установите пакет: apt-get install -y qrencode"
  fi
fi
