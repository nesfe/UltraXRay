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

if [[ -n "${VLESS_VISION_LINK:-}" ]]; then
  echo
  echo "VLESS Vision REALITY fallback ссылка:"
  echo
  printf '%s\n' "$VLESS_VISION_LINK"
  echo
  echo "VLESS Vision fallback QR-код:"
  echo
  if command -v qrencode >/dev/null 2>&1; then
    printf '%s' "$VLESS_VISION_LINK" | qrencode -t ANSIUTF8
  else
    echo "qrencode не установлен. Установите пакет: apt-get install -y qrencode"
  fi
fi

echo
echo "Hysteria 2 Full ссылка:"
echo
printf '%s\n' "$HY2_LINK"
echo
echo "Hysteria 2 Full QR-код:"
echo
if command -v qrencode >/dev/null 2>&1; then
  printf '%s' "$HY2_LINK" | qrencode -t ANSIUTF8
else
  echo "qrencode не установлен. Установите пакет: apt-get install -y qrencode"
fi

if [[ -n "${HY2_SINGLE_LINK:-}" ]]; then
  echo
  echo "Hysteria 2 Single-port ссылка:"
  echo
  printf '%s\n' "$HY2_SINGLE_LINK"
  echo
  echo "Hysteria 2 Single-port QR-код:"
  echo
  if command -v qrencode >/dev/null 2>&1; then
    printf '%s' "$HY2_SINGLE_LINK" | qrencode -t ANSIUTF8
  else
    echo "qrencode не установлен. Установите пакет: apt-get install -y qrencode"
  fi
fi

if [[ -n "${HY2_HAPP_AUTH_LINK:-}" ]]; then
  echo
  echo "Hysteria 2 Happ auth-param ссылка:"
  echo
  printf '%s\n' "$HY2_HAPP_AUTH_LINK"
  echo
  echo "Hysteria 2 Happ auth-param QR-код:"
  echo
  if command -v qrencode >/dev/null 2>&1; then
    printf '%s' "$HY2_HAPP_AUTH_LINK" | qrencode -t ANSIUTF8
  else
    echo "qrencode не установлен. Установите пакет: apt-get install -y qrencode"
  fi
fi
