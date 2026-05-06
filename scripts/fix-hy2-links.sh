#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Скрипт необходимо запускать от имени root."
  exit 1
fi

ENV_FILE="${1:-/root/ultraproxy.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Файл доступов не найден: $ENV_FILE"
  exit 1
fi

urlencode() {
  jq -rn --arg value "$1" '$value|@uri'
}

env_value() {
  printf '%q' "$1"
}

require_var() {
  local name="$1"
  local value="${!name:-}"
  if [[ -z "$value" ]]; then
    echo "В $ENV_FILE нет обязательного значения: $name"
    exit 1
  fi
}

# shellcheck disable=SC1090
source "$ENV_FILE"

require_var SERVER_IP
require_var TARGET_HOST
require_var HYSTERIA_PASSWORD
require_var HYSTERIA_OBFS_PASSWORD

HYSTERIA_PIN_SHA256="${HYSTERIA_PIN_SHA256:-}"
HY2_LINK="hysteria2://$(urlencode "$HYSTERIA_PASSWORD")@${SERVER_IP}:20000/?insecure=1&obfs=salamander&obfs-password=$(urlencode "$HYSTERIA_OBFS_PASSWORD")&sni=$(urlencode "$TARGET_HOST")#UltraXRay-Hysteria2-Happ"
HY2_HOPPING_LINK="hysteria2://$(urlencode "$HYSTERIA_PASSWORD")@${SERVER_IP}:20000-50000/?insecure=1&obfs=salamander&obfs-password=$(urlencode "$HYSTERIA_OBFS_PASSWORD")&sni=$(urlencode "$TARGET_HOST")"
HY2_HOPPING_ALIAS_LINK="hy2://$(urlencode "$HYSTERIA_PASSWORD")@${SERVER_IP}:20000-50000/?insecure=1&obfs=salamander&obfs-password=$(urlencode "$HYSTERIA_OBFS_PASSWORD")&sni=$(urlencode "$TARGET_HOST")"

if [[ -n "$HYSTERIA_PIN_SHA256" ]]; then
  HY2_HOPPING_LINK="${HY2_HOPPING_LINK}&pinSHA256=$(urlencode "$HYSTERIA_PIN_SHA256")"
  HY2_HOPPING_ALIAS_LINK="${HY2_HOPPING_ALIAS_LINK}&pinSHA256=$(urlencode "$HYSTERIA_PIN_SHA256")"
fi

HY2_HOPPING_LINK="${HY2_HOPPING_LINK}#UltraXRay-Hysteria2-PortHopping"
HY2_HOPPING_ALIAS_LINK="${HY2_HOPPING_ALIAS_LINK}#UltraXRay-Hysteria2-PortHopping"

tmp_env="$(mktemp)"
awk '!/^(HY2_LINK|HY2_HOPPING_LINK|HY2_HOPPING_ALIAS_LINK)=/' "$ENV_FILE" > "$tmp_env"
{
  printf 'HY2_LINK=%s\n' "$(env_value "$HY2_LINK")"
  printf 'HY2_HOPPING_LINK=%s\n' "$(env_value "$HY2_HOPPING_LINK")"
  printf 'HY2_HOPPING_ALIAS_LINK=%s\n' "$(env_value "$HY2_HOPPING_ALIAS_LINK")"
} >> "$tmp_env"
cat "$tmp_env" > "$ENV_FILE"
rm -f "$tmp_env"
chmod 600 "$ENV_FILE"

printf '%s\n' "$HY2_LINK" > /root/ultraxray-hy2-link.txt
printf '%s\n' "$HY2_HOPPING_LINK" > /root/ultraxray-hy2-hopping-link.txt
printf '%s\n' "$HY2_HOPPING_ALIAS_LINK" > /root/ultraxray-hy2-hopping-alias-link.txt

if command -v qrencode >/dev/null 2>&1; then
  printf '%s' "$HY2_LINK" | qrencode -o /root/ultraxray-hy2-qr.png
  printf '%s' "$HY2_HOPPING_LINK" | qrencode -o /root/ultraxray-hy2-hopping-qr.png
fi

echo "Hysteria 2 ссылка для Happ:"
echo
printf '%s\n' "$HY2_LINK"
echo
if command -v qrencode >/dev/null 2>&1; then
  printf '%s' "$HY2_LINK" | qrencode -t ANSIUTF8
fi
echo
echo "Port Hopping ссылка сохранена в /root/ultraxray-hy2-hopping-link.txt"
