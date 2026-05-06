# UltraXRay

`UltraXRay` разворачивает два независимых proxy-ядра на одном VPS:

- `Xray-core`: `VLESS + REALITY + XHTTP` на `443/tcp` с VLESS Encryption, сгенерированной через `xray vlessenc`.
- `Hysteria 2`: UDP transport с `Salamander` obfuscation и port hopping `20000-50000/udp`.

Скрипт сохраняет стиль ClearXRay: строгий bash, пошаговый вывод, полная очистка старых конфигов, `systemd`, `ufw`, ссылки и QR-коды.

## Установка

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/nesfe/UltraXRay/main/install.sh)
```

Установщик спросит:

- домен для REALITY SNI;
- пароль Hysteria 2, либо сгенерирует его, если оставить поле пустым.

## Что Создаётся

- `/usr/local/etc/xray/config.json`
- `/etc/hysteria/config.yaml`
- `/root/ultraproxy.env`
- `/root/ultraxray-vless-link.txt`
- `/root/ultraxray-vless-qr.png`
- `/root/ultraxray-hy2-link.txt`
- `/root/ultraxray-hy2-qr.png`

## Сетевые Порты

- `22/tcp` для SSH;
- `443/tcp` для Xray VLESS XHTTP REALITY;
- `20000-50000/udp` для Hysteria 2 port hopping.

## Повторный Вывод Ссылок

```bash
bash scripts/generate-links.sh /root/ultraproxy.env
```

На сервере после установки:

```bash
cat /root/ultraproxy.env
cat /root/ultraxray-vless-link.txt
cat /root/ultraxray-hy2-link.txt
```

## Источники Синтаксиса

- Xray VLESS/XHTTP/REALITY: официальные `XTLS/Xray-examples` и документация Project X.
- VLESS Encryption: `xray vlessenc`.
- Hysteria 2: официальная документация Hysteria 2 по server config, Salamander, URI scheme и port hopping.
