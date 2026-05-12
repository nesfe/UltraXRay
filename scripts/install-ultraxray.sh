#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Установщик необходимо запускать от имени root."
  exit 1
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'
ULTRAXRAY_VERSION="2026-05-06.4"

title() { printf "\n${BLUE}UltraXRay${NC}\n"; }
step() { printf "\n${CYAN}== %s ==${NC}\n\n" "$1"; }
ok() { printf "${GREEN}[OK] %s${NC}\n" "$1"; }
warn() { printf "${YELLOW}[!] %s${NC}\n" "$1"; }
err() { printf "${RED}[ОШИБКА] %s${NC}\n" "$1"; }
info() { printf "    %s\n" "$1"; }

normalize_hostname() {
  local value="$1"
  value="$(printf '%s' "$value" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  value="${value#http://}"
  value="${value#https://}"
  value="${value%%\#*}"
  value="${value%%\?*}"
  value="${value%%/*}"
  value="${value##*@}"
  value="$(printf '%s' "$value" | sed -E 's/:[0-9]+$//')"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
  printf '%s' "$value"
}

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

require_nonempty() {
  local name="$1"
  local value="$2"
  if [[ -z "$value" ]]; then
    err "Пустое обязательное значение: ${name}"
    exit 1
  fi
}

validate_hostname() {
  local value="$1"
  if [[ ! "$value" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$ ]]; then
    return 1
  fi
}

download_file() {
  local url="$1"
  local output="$2"
  curl -fL --show-error --connect-timeout 15 --max-time 180 --retry 3 --retry-delay 2 "$url" -o "$output"
}

check_tls_host() {
  local host="$1"
  local log_file="$2"
  timeout 20 openssl s_client \
    -connect "${host}:443" \
    -servername "$host" \
    -verify_hostname "$host" \
    </dev/null >"$log_file" 2>&1
}

title
printf "Установщик двухъядерной конфигурации Xray XHTTP REALITY и Hysteria 2\n"
printf "Режим установки: полная пересборка proxy-стека на сервере\n"
printf "Версия установщика: %s\n" "$ULTRAXRAY_VERSION"

TARGET_HOST_DEFAULT="www.mix.com"
read -r -p "Домен или URL для маскировки REALITY SNI [${TARGET_HOST_DEFAULT}]: " TARGET_HOST_INPUT
TARGET_HOST_INPUT="${TARGET_HOST_INPUT:-$TARGET_HOST_DEFAULT}"
TARGET_HOST="$(normalize_hostname "$TARGET_HOST_INPUT")"
if [[ -z "$TARGET_HOST" || "$TARGET_HOST" == *://* || "$TARGET_HOST" == *"/"* ]] || ! validate_hostname "$TARGET_HOST"; then
  err "Некорректный домен для REALITY SNI: ${TARGET_HOST_INPUT}"
  exit 1
fi
ok "REALITY SNI: ${TARGET_HOST}"

read -r -s -p "Пароль для Hysteria 2 [оставьте пустым для генерации]: " HYSTERIA_PASSWORD
printf "\n"

warn "Будут удалены старые Xray/Hysteria, очищены iptables и сброшен UFW."
warn "Xray займёт 443/tcp и 8443/tcp, Hysteria 2 займёт 20000-50000/udp."

step "Установка базовых зависимостей"
DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get update -qq
DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get install -y -qq curl openssl ufw ca-certificates qrencode jq unzip iptables
ok "Системные зависимости установлены"

if [[ -z "$HYSTERIA_PASSWORD" ]]; then
  HYSTERIA_PASSWORD="$(openssl rand -base64 24 | tr '+/' '-_' | tr -d '=')"
  ok "Пароль Hysteria сгенерирован"
fi

step "Полная очистка старого proxy-стека"
if command -v docker >/dev/null 2>&1; then
  warn "Обнаружен Docker. Выполняется удаление контейнеров, сетей и пакетов."
  docker stop $(docker ps -aq) 2>/dev/null || true
  docker rm $(docker ps -aq) 2>/dev/null || true
  docker network prune -f 2>/dev/null || true
  systemctl stop docker.socket docker.service 2>/dev/null || true
  apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
  apt-get purge -y docker docker.io containerd runc 2>/dev/null || true
  rm -rf /var/lib/docker /var/lib/containerd /etc/docker
  ok "Docker удалён"
else
  ok "Docker не найден"
fi

rm -rf /opt/amnezia /etc/amnezia 2>/dev/null || true
rm -rf /opt/outline /etc/outline 2>/dev/null || true
ok "Остатки Amnezia и Outline удалены"

systemctl stop xray 2>/dev/null || true
systemctl disable xray 2>/dev/null || true
systemctl stop hysteria-server hysteria hysteria-happ 2>/dev/null || true
systemctl disable hysteria-server hysteria hysteria-happ 2>/dev/null || true

if download_file https://get.hy2.sh/ /tmp/ultraxray-get-hy2.sh >/tmp/ultraxray-hy2-download.log 2>&1; then
  if bash /tmp/ultraxray-get-hy2.sh --remove >/tmp/ultraxray-hy2-remove.log 2>&1; then
    ok "Предыдущая установка Hysteria удалена"
    rm -f /tmp/ultraxray-hy2-remove.log
  else
    warn "Официальный remover Hysteria завершился с предупреждением, продолжаю ручную очистку"
    tail -n 20 /tmp/ultraxray-hy2-remove.log || true
  fi
  rm -f /tmp/ultraxray-get-hy2.sh
  rm -f /tmp/ultraxray-hy2-download.log
else
  warn "Не удалось скачать remover Hysteria, продолжаю ручную очистку"
  sed -n '1,80p' /tmp/ultraxray-hy2-download.log || true
fi

rm -f /etc/systemd/system/hysteria-server.service \
  /etc/systemd/system/hysteria-server@.service \
  /etc/systemd/system/hysteria-happ.service \
  /etc/systemd/system/multi-user.target.wants/hysteria-server.service \
  /etc/systemd/system/multi-user.target.wants/hysteria-server@*.service \
  /etc/systemd/system/multi-user.target.wants/hysteria-happ.service 2>/dev/null || true
systemctl daemon-reload 2>/dev/null || true
userdel -r hysteria 2>/dev/null || true

rm -rf /usr/local/etc/xray \
  /etc/hysteria \
  /var/lib/hysteria \
  /root/ultraproxy.env \
  /root/ultraxray-vless-link.txt \
  /root/ultraxray-vless-qr.png \
  /root/ultraxray-vless-vision-link.txt \
  /root/ultraxray-vless-vision-qr.png \
  /root/ultraxray-hy2-link.txt \
  /root/ultraxray-hy2-single-link.txt \
  /root/ultraxray-hy2-official-link.txt \
  /root/ultraxray-hy2-happ-link.txt \
  /root/ultraxray-hy2-qr.png 2>/dev/null || true

fuser -k 443/tcp 2>/dev/null || true
fuser -k 8443/tcp 2>/dev/null || true
fuser -k 20000/udp 2>/dev/null || true
fuser -k 51000/udp 2>/dev/null || true

iptables -F 2>/dev/null || true
iptables -X 2>/dev/null || true
iptables -t nat -F 2>/dev/null || true
iptables -t nat -X 2>/dev/null || true
iptables -t mangle -F 2>/dev/null || true
iptables -t mangle -X 2>/dev/null || true
iptables -P INPUT ACCEPT 2>/dev/null || true
iptables -P FORWARD ACCEPT 2>/dev/null || true
iptables -P OUTPUT ACCEPT 2>/dev/null || true
ok "Старые сервисы, конфиги и firewall-правила очищены"

step "Проверка TLS-хоста для REALITY"
if echo | openssl s_client -connect "${TARGET_HOST}:443" -servername "${TARGET_HOST}" -verify_hostname "${TARGET_HOST}" >/tmp/ultraxray-target.log 2>&1; then
  ok "Сертификат ${TARGET_HOST} успешно проверен"
else
  err "Проверка сертификата ${TARGET_HOST} не прошла"
  sed -n '1,80p' /tmp/ultraxray-target.log || true
  exit 1
fi

step "Установка Xray-core"
info "Скачиваю официальный установщик Xray-core"
download_file https://github.com/XTLS/Xray-install/raw/main/install-release.sh /tmp/ultraxray-xray-install.sh
info "Запускаю установщик Xray-core"
bash /tmp/ultraxray-xray-install.sh install
rm -f /tmp/ultraxray-xray-install.sh
test -x /usr/local/bin/xray
ok "$(/usr/local/bin/xray version | head -1)"

step "Установка Hysteria 2"
info "Скачиваю официальный установщик Hysteria 2"
download_file https://get.hy2.sh/ /tmp/ultraxray-get-hy2.sh
info "Запускаю установщик Hysteria 2"
HYSTERIA_USER=root bash /tmp/ultraxray-get-hy2.sh
rm -f /tmp/ultraxray-get-hy2.sh
test -x /usr/local/bin/hysteria
ok "$(/usr/local/bin/hysteria version | head -1)"

step "Генерация параметров Xray"
SERVER_IP="$(curl -s --max-time 10 https://api.ipify.org || true)"
XRAY_UUID="$("/usr/local/bin/xray" uuid)"
REALITY_KEYS="$("/usr/local/bin/xray" x25519 2>&1)"
REALITY_PRIVATE_KEY="$(awk -F': ' '/PrivateKey/ {print $2}' <<<"$REALITY_KEYS")"
REALITY_PUBLIC_KEY="$(awk -F': ' '/Password \(PublicKey\)/ {print $2}' <<<"$REALITY_KEYS")"
REALITY_SHORT_ID="$(openssl rand -hex 8)"
XHTTP_PATH="/api/$(openssl rand -hex 6)/events"
SPIDER_X="/assets/$(openssl rand -hex 4)"
VISION_PORT="8443"
VISION_UUID="$("/usr/local/bin/xray" uuid)"
VISION_KEYS="$("/usr/local/bin/xray" x25519 2>&1)"
VISION_PRIVATE_KEY="$(awk -F': ' '/PrivateKey/ {print $2}' <<<"$VISION_KEYS")"
VISION_PUBLIC_KEY="$(awk -F': ' '/Password \(PublicKey\)/ {print $2}' <<<"$VISION_KEYS")"
VISION_SHORT_ID="$(openssl rand -hex 8)"

VLESS_ENC_OUTPUT="$("/usr/local/bin/xray" vlessenc)"
VLESS_DECRYPTION="$(awk '/Authentication: ML-KEM-768/{flag=1; next} flag && /"decryption":/{gsub(/.*"decryption": "/,""); gsub(/".*/,""); print; exit}' <<<"$VLESS_ENC_OUTPUT")"
VLESS_ENCRYPTION="$(awk '/Authentication: ML-KEM-768/{flag=1; next} flag && /"encryption":/{gsub(/.*"encryption": "/,""); gsub(/".*/,""); print; exit}' <<<"$VLESS_ENC_OUTPUT")"

require_nonempty "SERVER_IP" "$SERVER_IP"
require_nonempty "XRAY_UUID" "$XRAY_UUID"
require_nonempty "REALITY_PRIVATE_KEY" "$REALITY_PRIVATE_KEY"
require_nonempty "REALITY_PUBLIC_KEY" "$REALITY_PUBLIC_KEY"
require_nonempty "REALITY_SHORT_ID" "$REALITY_SHORT_ID"
require_nonempty "VISION_UUID" "$VISION_UUID"
require_nonempty "VISION_PRIVATE_KEY" "$VISION_PRIVATE_KEY"
require_nonempty "VISION_PUBLIC_KEY" "$VISION_PUBLIC_KEY"
require_nonempty "VISION_SHORT_ID" "$VISION_SHORT_ID"
require_nonempty "VLESS_DECRYPTION" "$VLESS_DECRYPTION"
require_nonempty "VLESS_ENCRYPTION" "$VLESS_ENCRYPTION"

ok "IP: ${SERVER_IP}"
ok "Xray UUID: ${XRAY_UUID}"
ok "REALITY PublicKey: ${REALITY_PUBLIC_KEY}"
ok "REALITY Short ID: ${REALITY_SHORT_ID}"
ok "XHTTP path: ${XHTTP_PATH}"
ok "Vision fallback port: ${VISION_PORT}"
ok "Vision UUID: ${VISION_UUID}"
ok "Vision PublicKey: ${VISION_PUBLIC_KEY}"
ok "Vision Short ID: ${VISION_SHORT_ID}"
ok "VLESS Encryption: ML-KEM-768 профиль сгенерирован"

step "Запись конфигурации Xray"
mkdir -p /usr/local/etc/xray
cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${XRAY_UUID}",
            "email": "ultraxray-xhttp"
          }
        ],
        "decryption": "${VLESS_DECRYPTION}"
      },
      "streamSettings": {
        "network": "xhttp",
        "xhttpSettings": {
          "mode": "packet-up",
          "path": "${XHTTP_PATH}"
        },
        "security": "reality",
        "realitySettings": {
          "show": false,
          "target": "${TARGET_HOST}:443",
          "xver": 0,
          "serverNames": [
            "${TARGET_HOST}"
          ],
          "privateKey": "${REALITY_PRIVATE_KEY}",
          "shortIds": [
            "${REALITY_SHORT_ID}"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"]
      }
    },
    {
      "listen": "0.0.0.0",
      "port": ${VISION_PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${VISION_UUID}",
            "flow": "xtls-rprx-vision",
            "email": "ultraxray-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "raw",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "target": "${TARGET_HOST}:443",
          "xver": 0,
          "serverNames": [
            "${TARGET_HOST}"
          ],
          "privateKey": "${VISION_PRIVATE_KEY}",
          "shortIds": [
            "${VISION_SHORT_ID}"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "block"
      },
      {
        "type": "field",
        "protocol": ["bittorrent"],
        "outboundTag": "block"
      }
    ]
  }
}
EOF

"/usr/local/bin/xray" run -test -config /usr/local/etc/xray/config.json
ok "Конфиг Xray валиден"

step "Генерация сертификата и конфигурации Hysteria 2"
mkdir -p /etc/hysteria /var/www/ultraxray-masq
cat > /var/www/ultraxray-masq/index.html <<EOF
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>${TARGET_HOST}</title></head>
<body><h1>${TARGET_HOST}</h1></body>
</html>
EOF

openssl req -x509 -nodes -newkey ec \
  -pkeyopt ec_paramgen_curve:prime256v1 \
  -keyout /etc/hysteria/server.key \
  -out /etc/hysteria/server.crt \
  -days 3650 \
  -subj "/CN=${TARGET_HOST}" \
  -addext "subjectAltName=DNS:${TARGET_HOST}" >/dev/null 2>&1
chmod 600 /etc/hysteria/server.key

HYSTERIA_CERT_FINGERPRINT="$(openssl x509 -noout -fingerprint -sha256 -in /etc/hysteria/server.crt | sed 's/^sha256 Fingerprint=//; s/^SHA256 Fingerprint=//')"
HYSTERIA_PIN_SHA256="$(printf '%s' "$HYSTERIA_CERT_FINGERPRINT" | tr -d ':' | tr '[:upper:]' '[:lower:]')"
HYSTERIA_OBFS_PASSWORD="$(openssl rand -base64 24 | tr '+/' '-_' | tr -d '=')"

cat > /etc/hysteria/config.yaml <<EOF
listen: :20000-50000

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

ok "Конфиг Hysteria 2 записан"
ok "Hysteria Salamander password: ${HYSTERIA_OBFS_PASSWORD}"

step "Настройка firewall"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 443/tcp comment 'Xray VLESS XHTTP REALITY'
ufw allow 8443/tcp comment 'Xray VLESS Vision REALITY fallback'
ufw allow 20000:50000/udp comment 'Hysteria 2 UDP port hopping'
ufw --force enable
ok "UFW настроен"

step "Запуск systemd-сервисов"
systemctl enable xray
systemctl restart xray
systemctl enable hysteria-server.service
systemctl restart hysteria-server.service
sleep 2
systemctl is-active --quiet xray
systemctl is-active --quiet hysteria-server.service
ok "Xray и Hysteria 2 запущены"

if ss -ltnp | grep -q ':443'; then
  ok "443/tcp слушает Xray"
else
  err "443/tcp не слушает"
  exit 1
fi

if ss -ltnp | grep -q ':8443'; then
  ok "8443/tcp слушает Xray Vision fallback"
else
  err "8443/tcp не слушает"
  exit 1
fi

if ss -lunp | grep -Eq ':(20000|[2-4][0-9]{4}|50000)'; then
  ok "UDP port hopping диапазон Hysteria активен"
else
  warn "Не вижу UDP-сокет диапазона в ss; проверьте journalctl -u hysteria-server.service"
fi

step "Сохранение доступов"
VLESS_LINK="vless://${XRAY_UUID}@${SERVER_IP}:443?encryption=$(urlencode "$VLESS_ENCRYPTION")&type=xhttp&security=reality&sni=$(urlencode "$TARGET_HOST")&fp=chrome&pbk=$(urlencode "$REALITY_PUBLIC_KEY")&sid=${REALITY_SHORT_ID}&path=$(urlencode "$XHTTP_PATH")&mode=packet-up&spx=$(urlencode "$SPIDER_X")#UltraXRay-XHTTP-REALITY"
VLESS_VISION_LINK="vless://${VISION_UUID}@${SERVER_IP}:${VISION_PORT}?encryption=none&type=tcp&security=reality&sni=$(urlencode "$TARGET_HOST")&fp=chrome&pbk=$(urlencode "$VISION_PUBLIC_KEY")&sid=${VISION_SHORT_ID}&flow=xtls-rprx-vision#UltraXRay-Vision-REALITY"
HY2_LINK="hy2://$(urlencode "$HYSTERIA_PASSWORD")@${SERVER_IP}:20000-50000/?security=tls&insecure=1&obfs=salamander&obfs-password=$(urlencode "$HYSTERIA_OBFS_PASSWORD")&sni=$(urlencode "$TARGET_HOST")&mportHopInt=30#UltraXRay-Hysteria2-Full"
HY2_HAPP_AUTH_LINK="hy2://${SERVER_IP}:20000-50000/?auth=$(urlencode "$HYSTERIA_PASSWORD")&security=tls&insecure=1&obfs=salamander&obfs-password=$(urlencode "$HYSTERIA_OBFS_PASSWORD")&sni=$(urlencode "$TARGET_HOST")&mportHopInt=30#UltraXRay-Hysteria2-HappAuth"
HY2_SINGLE_LINK="hy2://$(urlencode "$HYSTERIA_PASSWORD")@${SERVER_IP}:20000/?security=tls&insecure=1&obfs=salamander&obfs-password=$(urlencode "$HYSTERIA_OBFS_PASSWORD")&sni=$(urlencode "$TARGET_HOST")#UltraXRay-Hysteria2-SinglePort"
HY2_OFFICIAL_LINK="hysteria2://$(urlencode "$HYSTERIA_PASSWORD")@${SERVER_IP}:20000-50000/?insecure=1&obfs=salamander&obfs-password=$(urlencode "$HYSTERIA_OBFS_PASSWORD")&sni=$(urlencode "$TARGET_HOST")&pinSHA256=$(urlencode "$HYSTERIA_PIN_SHA256")#UltraXRay-Hysteria2-Official"

cat > /root/ultraproxy.env <<EOF
SERVER_IP=$(env_value "$SERVER_IP")
TARGET_HOST=$(env_value "$TARGET_HOST")
XRAY_UUID=$(env_value "$XRAY_UUID")
REALITY_PRIVATE_KEY=$(env_value "$REALITY_PRIVATE_KEY")
REALITY_PUBLIC_KEY=$(env_value "$REALITY_PUBLIC_KEY")
REALITY_SHORT_ID=$(env_value "$REALITY_SHORT_ID")
XHTTP_PATH=$(env_value "$XHTTP_PATH")
SPIDER_X=$(env_value "$SPIDER_X")
VLESS_DECRYPTION=$(env_value "$VLESS_DECRYPTION")
VLESS_ENCRYPTION=$(env_value "$VLESS_ENCRYPTION")
VISION_PORT=$(env_value "$VISION_PORT")
VISION_UUID=$(env_value "$VISION_UUID")
VISION_PRIVATE_KEY=$(env_value "$VISION_PRIVATE_KEY")
VISION_PUBLIC_KEY=$(env_value "$VISION_PUBLIC_KEY")
VISION_SHORT_ID=$(env_value "$VISION_SHORT_ID")
HYSTERIA_PASSWORD=$(env_value "$HYSTERIA_PASSWORD")
HYSTERIA_OBFS_PASSWORD=$(env_value "$HYSTERIA_OBFS_PASSWORD")
HYSTERIA_CERT_FINGERPRINT=$(env_value "$HYSTERIA_CERT_FINGERPRINT")
HYSTERIA_PIN_SHA256=$(env_value "$HYSTERIA_PIN_SHA256")
VLESS_LINK=$(env_value "$VLESS_LINK")
VLESS_VISION_LINK=$(env_value "$VLESS_VISION_LINK")
HY2_LINK=$(env_value "$HY2_LINK")
HY2_HAPP_AUTH_LINK=$(env_value "$HY2_HAPP_AUTH_LINK")
HY2_SINGLE_LINK=$(env_value "$HY2_SINGLE_LINK")
HY2_OFFICIAL_LINK=$(env_value "$HY2_OFFICIAL_LINK")
EOF
chmod 600 /root/ultraproxy.env

printf '%s\n' "$VLESS_LINK" > /root/ultraxray-vless-link.txt
printf '%s\n' "$VLESS_VISION_LINK" > /root/ultraxray-vless-vision-link.txt
printf '%s\n' "$HY2_LINK" > /root/ultraxray-hy2-link.txt
printf '%s\n' "$HY2_HAPP_AUTH_LINK" > /root/ultraxray-hy2-happ-auth-link.txt
printf '%s\n' "$HY2_SINGLE_LINK" > /root/ultraxray-hy2-single-link.txt
printf '%s\n' "$HY2_OFFICIAL_LINK" > /root/ultraxray-hy2-official-link.txt
printf '%s' "$VLESS_LINK" | qrencode -o /root/ultraxray-vless-qr.png
printf '%s' "$VLESS_VISION_LINK" | qrencode -o /root/ultraxray-vless-vision-qr.png
printf '%s' "$HY2_LINK" | qrencode -o /root/ultraxray-hy2-qr.png
printf '%s' "$HY2_HAPP_AUTH_LINK" | qrencode -o /root/ultraxray-hy2-happ-auth-qr.png
printf '%s' "$HY2_SINGLE_LINK" | qrencode -o /root/ultraxray-hy2-single-qr.png

ok "Сохранён /root/ultraproxy.env"
ok "Сохранён /root/ultraxray-vless-link.txt"
ok "Сохранён /root/ultraxray-vless-qr.png"
ok "Сохранён /root/ultraxray-vless-vision-link.txt"
ok "Сохранён /root/ultraxray-vless-vision-qr.png"
ok "Сохранён /root/ultraxray-hy2-link.txt"
ok "Сохранён /root/ultraxray-hy2-qr.png"
ok "Сохранён /root/ultraxray-hy2-happ-auth-link.txt"
ok "Сохранён /root/ultraxray-hy2-happ-auth-qr.png"
ok "Сохранён /root/ultraxray-hy2-single-link.txt"
ok "Сохранён /root/ultraxray-hy2-single-qr.png"

step "Результат установки"
info "Xray: VLESS + REALITY + XHTTP + VLESS Encryption"
info "Xray port: 443/tcp"
info "Xray fallback: VLESS + REALITY + Vision на 8443/tcp"
info "Hysteria 2: Salamander + UDP port hopping"
info "Hysteria UDP range: 20000-50000/udp"
info "Файл доступов: /root/ultraproxy.env"

printf "\n${GREEN}VLESS XHTTP REALITY ссылка${NC}\n\n"
cat /root/ultraxray-vless-link.txt
printf "\n\n${GREEN}VLESS QR-код${NC}\n\n"
printf '%s' "$VLESS_LINK" | qrencode -t ANSIUTF8

printf "\n\n${GREEN}VLESS Vision REALITY fallback ссылка${NC}\n\n"
cat /root/ultraxray-vless-vision-link.txt
printf "\n\n${GREEN}VLESS Vision fallback QR-код${NC}\n\n"
printf '%s' "$VLESS_VISION_LINK" | qrencode -t ANSIUTF8

printf "\n\n${GREEN}Hysteria 2 Full ссылка${NC}\n\n"
cat /root/ultraxray-hy2-link.txt
printf "\n\n${GREEN}Hysteria 2 Full QR-код${NC}\n\n"
printf '%s' "$HY2_LINK" | qrencode -t ANSIUTF8

printf "\n\n${GREEN}Hysteria 2 Single-port ссылка${NC}\n\n"
cat /root/ultraxray-hy2-single-link.txt
printf "\n\n${GREEN}Hysteria 2 Single-port QR-код${NC}\n\n"
printf '%s' "$HY2_SINGLE_LINK" | qrencode -t ANSIUTF8

printf "\n\n${CYAN}Полезные команды${NC}\n"
printf "  systemctl status xray\n"
printf "  systemctl status hysteria-server.service\n"
printf "  journalctl -u xray -n 80 --no-pager\n"
printf "  journalctl -u hysteria-server.service -n 80 --no-pager\n"
printf "  cat /root/ultraproxy.env\n"
