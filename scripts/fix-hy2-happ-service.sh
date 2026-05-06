#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Скрипт необходимо запускать от имени root."
  exit 1
fi

ENV_FILE="${1:-/root/ultraproxy.env}"
HAPP_PORT="${HAPP_PORT:-51000}"
HAPP_CONFIG="/etc/hysteria/config-happ.yaml"
HAPP_SERVICE="/etc/systemd/system/hysteria-happ.service"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Файл доступов не найден: $ENV_FILE"
  exit 1
fi

urlencode() {
  jq -rn --arg value "$1" '$value|@uri'
}

yaml_quote() {
  local value="${1//\'/\'\'}"
  printf "'%s'" "$value"
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

if [[ ! -f /etc/hysteria/server.crt || ! -f /etc/hysteria/server.key ]]; then
  echo "Не найден сертификат Hysteria: /etc/hysteria/server.crt или /etc/hysteria/server.key"
  exit 1
fi

mkdir -p /etc/hysteria
cat > "$HAPP_CONFIG" <<EOF
listen: :${HAPP_PORT}

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key
  sniGuard: disable

auth:
  type: password
  password: $(yaml_quote "$HYSTERIA_PASSWORD")

transport:
  type: udp

quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520
  maxIdleTimeout: 30s
  keepAlivePeriod: 10s
  disablePathMTUDiscovery: true

masquerade:
  type: proxy
  proxy:
    url: https://${TARGET_HOST}/
    rewriteHost: true
EOF

cat > "$HAPP_SERVICE" <<EOF
[Unit]
Description=Hysteria Happ Compatibility Service
Documentation=https://v2.hysteria.network/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria server --config ${HAPP_CONFIG}
Restart=on-failure
RestartSec=5
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

if command -v ufw >/dev/null 2>&1; then
  ufw allow "${HAPP_PORT}/udp" comment 'Hysteria 2 Happ compatibility' >/dev/null || true
fi

systemctl daemon-reload
systemctl enable hysteria-happ.service >/dev/null
systemctl restart hysteria-happ.service
sleep 2
systemctl is-active --quiet hysteria-happ.service

HY2_HAPP_LINK="hy2://$(urlencode "$HYSTERIA_PASSWORD")@${SERVER_IP}:${HAPP_PORT}?security=tls&insecure=1&sni=$(urlencode "$TARGET_HOST")#UltraXRay-Hysteria2-Happ-NoObfs"

tmp_env="$(mktemp)"
awk '!/^(HY2_HAPP_LINK|HAPP_HYSTERIA_PORT)=/' "$ENV_FILE" > "$tmp_env"
{
  printf 'HAPP_HYSTERIA_PORT=%s\n' "$(env_value "$HAPP_PORT")"
  printf 'HY2_HAPP_LINK=%s\n' "$(env_value "$HY2_HAPP_LINK")"
} >> "$tmp_env"
cat "$tmp_env" > "$ENV_FILE"
rm -f "$tmp_env"
chmod 600 "$ENV_FILE"

printf '%s\n' "$HY2_HAPP_LINK" > /root/ultraxray-hy2-happ-link.txt
if command -v qrencode >/dev/null 2>&1; then
  printf '%s' "$HY2_HAPP_LINK" | qrencode -o /root/ultraxray-hy2-happ-qr.png
fi

echo "Hysteria 2 Happ compatibility service запущен на ${HAPP_PORT}/udp"
echo
echo "Hysteria 2 ссылка для Happ:"
echo
printf '%s\n' "$HY2_HAPP_LINK"
echo
if command -v qrencode >/dev/null 2>&1; then
  printf '%s' "$HY2_HAPP_LINK" | qrencode -t ANSIUTF8
fi
echo
echo "Проверка:"
echo "  systemctl status hysteria-happ.service --no-pager"
echo "  journalctl -u hysteria-happ.service -n 80 --no-pager"
