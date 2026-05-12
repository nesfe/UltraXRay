#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Скрипт необходимо запускать от имени root."
  exit 1
fi

ENV_FILE="${1:-/root/ultraproxy.env}"
XRAY_CONFIG="/usr/local/etc/xray/config.json"
VISION_PORT="${VISION_PORT:-8443}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Файл доступов не найден: $ENV_FILE"
  exit 1
fi

if [[ ! -f "$XRAY_CONFIG" ]]; then
  echo "Конфиг Xray не найден: $XRAY_CONFIG"
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

if [[ -z "${VISION_UUID:-}" ]]; then
  VISION_UUID="$("/usr/local/bin/xray" uuid)"
fi
if [[ -z "${VISION_PRIVATE_KEY:-}" || -z "${VISION_PUBLIC_KEY:-}" ]]; then
  VISION_KEYS="$("/usr/local/bin/xray" x25519 2>&1)"
  VISION_PRIVATE_KEY="$(awk -F': ' '/PrivateKey/ {print $2}' <<<"$VISION_KEYS")"
  VISION_PUBLIC_KEY="$(awk -F': ' '/Password \(PublicKey\)/ {print $2}' <<<"$VISION_KEYS")"
fi
if [[ -z "${VISION_SHORT_ID:-}" ]]; then
  VISION_SHORT_ID="$(openssl rand -hex 8)"
fi

tmp_config="$(mktemp)"
jq --argjson port "$VISION_PORT" \
  --arg uuid "$VISION_UUID" \
  --arg target "${TARGET_HOST}:443" \
  --arg serverName "$TARGET_HOST" \
  --arg privateKey "$VISION_PRIVATE_KEY" \
  --arg shortId "$VISION_SHORT_ID" '
  .inbounds = (
    [.inbounds[] | select(.port != $port)] + [{
      "listen": "0.0.0.0",
      "port": $port,
      "protocol": "vless",
      "settings": {
        "clients": [{
          "id": $uuid,
          "flow": "xtls-rprx-vision",
          "email": "ultraxray-vision"
        }],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "raw",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "target": $target,
          "xver": 0,
          "serverNames": [$serverName],
          "privateKey": $privateKey,
          "shortIds": [$shortId]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"]
      }
    }]
  )
  ' "$XRAY_CONFIG" > "$tmp_config"

"/usr/local/bin/xray" run -test -config "$tmp_config"
cp "$XRAY_CONFIG" "${XRAY_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
cat "$tmp_config" > "$XRAY_CONFIG"
rm -f "$tmp_config"

if command -v ufw >/dev/null 2>&1; then
  ufw allow "${VISION_PORT}/tcp" comment 'Xray VLESS Vision REALITY fallback' >/dev/null || true
fi

systemctl restart xray
sleep 2
systemctl is-active --quiet xray

VLESS_VISION_LINK="vless://${VISION_UUID}@${SERVER_IP}:${VISION_PORT}?encryption=none&type=tcp&security=reality&sni=$(urlencode "$TARGET_HOST")&fp=chrome&pbk=$(urlencode "$VISION_PUBLIC_KEY")&sid=${VISION_SHORT_ID}&flow=xtls-rprx-vision#UltraXRay-Vision-REALITY"

tmp_env="$(mktemp)"
awk '!/^(VISION_PORT|VISION_UUID|VISION_PRIVATE_KEY|VISION_PUBLIC_KEY|VISION_SHORT_ID|VLESS_VISION_LINK)=/' "$ENV_FILE" > "$tmp_env"
{
  printf 'VISION_PORT=%s\n' "$(env_value "$VISION_PORT")"
  printf 'VISION_UUID=%s\n' "$(env_value "$VISION_UUID")"
  printf 'VISION_PRIVATE_KEY=%s\n' "$(env_value "$VISION_PRIVATE_KEY")"
  printf 'VISION_PUBLIC_KEY=%s\n' "$(env_value "$VISION_PUBLIC_KEY")"
  printf 'VISION_SHORT_ID=%s\n' "$(env_value "$VISION_SHORT_ID")"
  printf 'VLESS_VISION_LINK=%s\n' "$(env_value "$VLESS_VISION_LINK")"
} >> "$tmp_env"
cat "$tmp_env" > "$ENV_FILE"
rm -f "$tmp_env"
chmod 600 "$ENV_FILE"

printf '%s\n' "$VLESS_VISION_LINK" > /root/ultraxray-vless-vision-link.txt
if command -v qrencode >/dev/null 2>&1; then
  printf '%s' "$VLESS_VISION_LINK" | qrencode -o /root/ultraxray-vless-vision-qr.png
fi

echo "VLESS Vision fallback добавлен на ${VISION_PORT}/tcp"
echo
printf '%s\n' "$VLESS_VISION_LINK"
echo
if command -v qrencode >/dev/null 2>&1; then
  printf '%s' "$VLESS_VISION_LINK" | qrencode -t ANSIUTF8
fi
