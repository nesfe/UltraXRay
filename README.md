# UltraXRay

![Xray XHTTP REALITY](https://img.shields.io/badge/Xray-XHTTP%20REALITY-0f172a?style=for-the-badge)
![VLESS Encryption](https://img.shields.io/badge/VLESS-ML--KEM--768-1d4ed8?style=for-the-badge)
![Hysteria 2](https://img.shields.io/badge/Hysteria%202-Port%20Hopping-7c3aed?style=for-the-badge)
![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%2B-e95420?style=for-the-badge)
![One Command Install](https://img.shields.io/badge/Install-One%20Command-166534?style=for-the-badge)

`UltraXRay` разворачивает два независимых proxy-ядра на одном VPS:

- `Xray-core`: `VLESS + REALITY + XHTTP` на `443/tcp` с VLESS Encryption, сгенерированной через `xray vlessenc`;
- `Hysteria 2`: UDP-транспорт с port hopping в диапазоне `20000-50000/udp`.

Проект сохраняет стиль `ClearXRay`: строгий `bash`, цветной пошаговый вывод, полная очистка старого proxy-стека, `systemd`, `ufw`, сохранение доступов, готовые ссылки и QR-коды.

## Содержание

- [Зачем два ядра](#зачем-два-ядра)
- [Сетевая схема](#сетевая-схема)
- [Установка одной командой](#установка-одной-командой)
- [Что делает установщик](#что-делает-установщик)
- [Что создаётся на сервере](#что-создаётся-на-сервере)
- [Параметры профилей](#параметры-профилей)
- [Повторный вывод ссылок](#повторный-вывод-ссылок)
- [Диагностика](#диагностика)
- [Документация](#документация)

## Зачем два ядра

`Xray` и `Hysteria 2` решают разные задачи и работают параллельно.

`Xray-core` используется как основной TCP-профиль:

- публичный порт `443/tcp`;
- `REALITY` вместо обычного TLS-сертификата на сервере;
- `XHTTP` вместо старого `raw tcp`/`ws`;
- отдельный случайный `path`;
- VLESS Encryption с ML-KEM-768-профилем, сгенерированным штатной командой `xray vlessenc`.

`Hysteria 2` используется как отдельный UDP-профиль:

- port hopping `20000-50000/udp`;
- самоподписанный сертификат;
- Happ-compatible `hy2://` QR без Salamander obfs;
- `pinSHA256` в official URI для клиентов, которые корректно импортируют pin.

## Сетевая схема

После установки сервер слушает:

| Порт | Протокол | Сервис | Назначение |
| --- | --- | --- | --- |
| `22/tcp` | SSH | OpenSSH | администрирование |
| `443/tcp` | TCP | Xray-core | `VLESS + REALITY + XHTTP` |
| `20000-50000/udp` | UDP | Hysteria 2 | port hopping |

Firewall настраивается через `ufw`. Входящие соединения по умолчанию запрещаются, открываются только перечисленные порты.

## Установка одной командой

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/nesfe/UltraXRay/main/install.sh)
```

Установщик спросит:

- домен или URL для маскировки `REALITY SNI`, по умолчанию `www.mix.com`;
- пароль для `Hysteria 2`; если оставить пустым, пароль будет сгенерирован автоматически.

Можно вводить как `lemanapro.ru`, так и `https://lemanapro.ru/`. Установщик сам приведёт ввод к чистому hostname для `openssl`, REALITY SNI и клиентских ссылок.

## Что делает установщик

Сценарий установки:

1. проверяет запуск от `root`;
2. устанавливает базовые зависимости: `curl`, `openssl`, `ufw`, `qrencode`, `jq`, `unzip`, `iptables`;
3. удаляет Docker, если он найден, вместе с контейнерами, сетями и данными;
4. удаляет остатки Amnezia и Outline;
5. останавливает старые сервисы `xray`, `hysteria-server`, `hysteria`;
6. удаляет старые конфиги и артефакты `UltraXRay`;
7. освобождает `443/tcp` и `20000/udp`;
8. очищает `iptables` и сбрасывает политики в `ACCEPT` перед новой настройкой;
9. проверяет TLS-хост, выбранный для `REALITY`, не меняет введённый SNI и останавливает установку с логом OpenSSL, если хост не подходит;
10. устанавливает актуальный `Xray-core`;
11. устанавливает актуальный `Hysteria 2` через официальный установщик;
12. генерирует `UUID`, `x25519` REALITY keys, `shortId`, `XHTTP path`, `spiderX`;
13. генерирует пару `decryption/encryption` для VLESS Encryption через `xray vlessenc`;
14. записывает `/usr/local/etc/xray/config.json`;
15. проверяет Xray-конфиг через `xray run -test`;
16. генерирует самоподписанный сертификат Hysteria 2;
17. генерирует параметры Hysteria 2 и fingerprint сертификата;
18. записывает `/etc/hysteria/config.yaml`;
19. настраивает `ufw`;
20. включает и запускает `xray` и `hysteria-server.service`;
21. формирует `vless://` и `hy2://` ссылки;
22. печатает обе ссылки и оба QR-кода в терминал;
23. сохраняет все параметры в `/root/ultraproxy.env`.

## Что создаётся на сервере

Основные конфиги:

- `/usr/local/etc/xray/config.json`
- `/etc/hysteria/config.yaml`
- `/etc/hysteria/server.crt`
- `/etc/hysteria/server.key`

Файлы доступа:

- `/root/ultraproxy.env`
- `/root/ultraxray-vless-link.txt`
- `/root/ultraxray-vless-qr.png`
- `/root/ultraxray-hy2-link.txt`
- `/root/ultraxray-hy2-qr.png`

Файл `/root/ultraproxy.env` создаётся с правами `600`.

## Параметры профилей

### VLESS XHTTP REALITY

Типовая ссылка выглядит так:

```text
vless://UUID@SERVER_IP:443?encryption=VLESS_ENCRYPTION&type=xhttp&security=reality&sni=TARGET_HOST&fp=chrome&pbk=PUBLIC_KEY&sid=SHORT_ID&path=XHTTP_PATH&mode=packet-up&spx=SPIDER_X#UltraXRay-XHTTP-REALITY
```

Ключевые параметры:

- `type=xhttp` — новый HTTP-based transport Xray;
- `mode=packet-up` — наиболее совместимый XHTTP-режим;
- `security=reality` — REALITY handshake;
- `sni` — домен, выбранный как маскировочный TLS-хост;
- `pbk` — публичный ключ REALITY;
- `sid` — `shortId`;
- `encryption` — клиентская часть VLESS Encryption, сгенерированная `xray vlessenc`;
- `path` — случайный HTTP path;
- `spx` — Reality spiderX path.

### Hysteria 2

Типовая ссылка выглядит так:

```text
hy2://PASSWORD@SERVER_IP:20000-50000/?security=tls&insecure=1&sni=TARGET_HOST&mportHopInt=30#UltraXRay-Hysteria2-Full
```

Ключевые параметры:

- `20000-50000` — multi-port/port hopping диапазон;
- `insecure=1` — требуется из-за self-signed сертификата;
- `mportHopInt=30` — интервал port hopping для клиентов, которые поддерживают этот параметр;
- `sni` — тот же домен, что указан пользователем при установке.

Установщик сохраняет несколько URI для одного и того же полноценного Hysteria 2 сервера:

- `/root/ultraxray-hy2-link.txt` — `hy2://` с `20000-50000` и `mportHopInt=30`;
- `/root/ultraxray-hy2-single-link.txt` — тот же Hysteria 2, но на одном порту `20000` для клиентов, которые режут multi-port URI;
- `/root/ultraxray-hy2-official-link.txt` — официальный `hysteria2://` URI с `pinSHA256`.

## Повторный вывод ссылок

В локальном клоне:

```bash
bash scripts/generate-links.sh /root/ultraproxy.env
```

На сервере после установки:

```bash
cat /root/ultraproxy.env
cat /root/ultraxray-vless-link.txt
cat /root/ultraxray-hy2-link.txt
qrencode -t ANSIUTF8 < /root/ultraxray-vless-link.txt
qrencode -t ANSIUTF8 < /root/ultraxray-hy2-link.txt
```

## Диагностика

Базовые команды:

```bash
systemctl status xray
systemctl status hysteria-server.service
journalctl -u xray -n 80 --no-pager
journalctl -u hysteria-server.service -n 80 --no-pager
ss -ltnp
ss -lunp
ufw status verbose
```

Диагностический скрипт:

```bash
bash scripts/diagnose-server.sh /root/ultraproxy.env
```

## Ограничения

- Не все клиенты одинаково быстро поддерживают `VLESS Encryption` и `XHTTP`. Если импорт ссылки не сработал, проверьте, что клиент использует свежий Xray-core.
- Hysteria 2 с self-signed сертификатом требует `insecure=1`; для снижения риска MITM в ссылку добавляется `pinSHA256`.
- Port hopping Hysteria 2 работает на Linux и требует прав на настройку firewall/redirect rules, поэтому сервис устанавливается от `root`.
- `REALITY` требует корректный внешний TLS-хост, поддерживающий современные TLS-параметры.

## Документация

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — архитектура двух ядер и причины выбора протоколов;
- [docs/INSTALLER_FLOW.md](docs/INSTALLER_FLOW.md) — подробный разбор шагов установщика;
- [docs/CLIENT_PROFILES.md](docs/CLIENT_PROFILES.md) — параметры клиентских ссылок;
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — диагностика и типовые проблемы;
- [docs/SOURCES.md](docs/SOURCES.md) — первичные источники синтаксиса.
