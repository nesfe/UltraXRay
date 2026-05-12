#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-/root/ultraproxy.env}"

section() {
  printf '\n== %s ==\n' "$1"
}

run() {
  printf '\n$ %s\n' "$*"
  "$@" 2>&1 || true
}

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Диагностику сервера нужно запускать от имени root."
  exit 1
fi

section "System"
run hostnamectl
run date -u
run uname -a
run ip -brief addr
run ip route

section "Binaries and services"
run /usr/local/bin/xray version
run /usr/local/bin/hysteria version
run systemctl status xray --no-pager
run systemctl status hysteria-server.service --no-pager
run journalctl -u xray -n 120 --no-pager
run journalctl -u hysteria-server.service -n 120 --no-pager

section "Ports and firewall"
run ss -ltnp
run ss -lunp
run ufw status verbose
run iptables -S
run iptables -t nat -S

section "Configs"
run ls -la /usr/local/etc/xray /etc/hysteria /root/ultraproxy.env
run /usr/local/bin/xray run -test -config /usr/local/etc/xray/config.json

if [[ -f "$ENV_FILE" ]]; then
  section "Saved links"
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  printf 'SERVER_IP=%s\n' "${SERVER_IP:-}"
  printf 'TARGET_HOST=%s\n' "${TARGET_HOST:-}"
  printf 'VLESS_LINK=%s\n' "${VLESS_LINK:-}"
  printf 'VLESS_VISION_LINK=%s\n' "${VLESS_VISION_LINK:-}"
  printf 'HY2_LINK=%s\n' "${HY2_LINK:-}"
fi
