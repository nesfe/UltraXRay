#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Скрипт необходимо запускать от имени root."
  exit 1
fi

umask 077
ENV_FILE="${1:-/root/ultraproxy.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Файл доступов не найден: $ENV_FILE"
  exit 1
fi

yaml_quote() {
  local value="${1//\'/\'\'}"
  printf "'%s'" "$value"
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

require_var TARGET_HOST
require_var HYSTERIA_PASSWORD
require_var HYSTERIA_OBFS_PASSWORD

if [[ ! -f /etc/hysteria/server.crt || ! -f /etc/hysteria/server.key ]]; then
  echo "Не найден сертификат Hysteria: /etc/hysteria/server.crt или /etc/hysteria/server.key"
  exit 1
fi

# Keep the current listener: never add a broad UDP redirect during a repair.
HYSTERIA_LISTEN="$(awk '$1 == "listen:" {print $2; exit}' /etc/hysteria/config.yaml)"
if [[ ! "$HYSTERIA_LISTEN" =~ ^:[0-9]+(-[0-9]+)?$ ]]; then
  echo "Не удалось прочитать listen; конфигурация не изменена."
  exit 1
fi
cp -p /etc/hysteria/config.yaml "/etc/hysteria/config.yaml.bak.$(date +%Y%m%d%H%M%S)"
cat > /etc/hysteria/config.yaml <<EOF
listen: ${HYSTERIA_LISTEN}

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key
  sniGuard: disable

obfs:
  type: salamander
  salamander:
    password: $(yaml_quote "$HYSTERIA_OBFS_PASSWORD")

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

systemctl restart hysteria-server.service
sleep 2
systemctl is-active --quiet hysteria-server.service

bash <(curl -fsSL https://raw.githubusercontent.com/nesfe/UltraXRay/main/scripts/fix-hy2-links.sh) "$ENV_FILE"

echo
echo "Hysteria 2 config rewritten with Salamander obfs and restarted."
