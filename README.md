# UltraXRay

Версия **2026.10.01**: XHTTP + REALITY, Vision + REALITY, дополнительный **Vision EDGE** и Hysteria 2. Установка рядом с Amnezia/Docker без очистки сервера.

## Профили

| Профиль | Порт | Назначение |
| --- | --- | --- |
| VLESS XHTTP REALITY | 443/tcp | XHTTP packet-up с VLESS Encryption |
| VLESS Vision REALITY | 8443/tcp | Vision с TLS fingerprint `chrome` |
| **VLESS Vision EDGE REALITY** | тот же 8443/tcp | Альтернативный клиентский fingerprint `edge` |
| Hysteria 2 + Salamander | 20000/udp | Независимый UDP-профиль, один порт |

Vision EDGE использует те же UUID, ключ REALITY, shortId, SNI и порт, что обычный Vision. Новый серверный inbound не нужен. В проверенной связке начальное TLS-приветствие Edge было 517 байт, Chrome — около 1800 байт. Edge помог на соединении, где Chrome зависал на начальном обмене. Это результат конкретной проверки, а не гарантия обхода фильтрации у любого провайдера: точная причина потери пакетов не установлена.

## Добавить Edge в существующую установку

**Повторная установка не нужна.** В клоне репозитория выполните от root:

```bash
git pull --ff-only
python3 scripts/add-vision-edge.py
```

Нужен Python 3. Скрипт читает `/root/ultraxray-vless-vision-link.txt`, печатает новую ссылку и создаёт:

- `/root/ultraxray-vless-vision-edge-link.txt`;
- `/root/ultraxray-vless-vision-edge-qr.png`, если установлен `qrencode`.

Конфиги, ключи, исходная ссылка, службы и firewall не меняются. Файлы профиля имеют права `600`. Импортируйте новую ссылку отдельным профилем в клиент.

Для другого пути:

```bash
python3 scripts/add-vision-edge.py /path/to/vision-link.txt --output-dir /path/to/output
```

Чтобы только вывести ссылку без создания файлов:

```bash
python3 scripts/add-vision-edge.py /path/to/vision-link.txt --print-only
```

Если сохранённой Vision-ссылки нет, эта утилита остановится. Она не создаёт серверный Vision-inbound. Старый `scripts/add-vision-fallback.sh` создаёт такой inbound, меняет конфигурацию и перезапускает Xray; это отдельная операция, для уже работающего Vision она не нужна.

## Новая установка

Ubuntu 22.04+ / Debian с systemd. Нужны root, `ss` (iproute2), свободные `443/tcp`, `8443/tcp`, `20000/udp` и отсутствие существующей установки Xray/Hysteria.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/nesfe/UltraXRay/v2026.10.01/install.sh)
```

Установщик спросит домен маскировки REALITY (принимает и URL) и пароль Hysteria; пустой пароль генерируется автоматически.

### Сохранение Amnezia и других сервисов

Режима очистки больше нет:

- Docker, контейнеры, сети, Amnezia и Outline не удаляются и не останавливаются;
- `iptables`/`nftables` не очищаются; чужие процессы на портах не завершаются;
- занятые порты, в том числе опубликованные Docker, приводят к остановке до установки пакетов;
- существующие конфиги, бинарники или systemd-службы Xray/Hysteria приводят к остановке; доступы не перегенерируются;
- если UFW активен, добавляются только правила `443/tcp`, `8443/tcp`, `20000/udp`; остальные правила и политики сохраняются;
- если UFW выключен, он остаётся выключенным. При необходимости откройте три порта в используемом firewall и панели VPS самостоятельно;
- Hysteria в новой установке работает от пользователя `hysteria` на одном порту, без правил port hopping;
- для `needrestart` выбран режим уведомления, а не автоматического перезапуска остальных служб.

Это установщик новой конфигурации, а не механизм обновления или восстановления существующей. Если новая установка прервётся после записи файлов, повторный запуск остановится на проверке наличия установки; сначала нужно разобрать причину, а не удалять существующие данные автоматически.

### Версии компонентов

Новые установки используют **Xray 26.6.27** и **Hysteria 2.12.3**, а не произвольный `latest`. Для Edge важна совместимость серверной и клиентской REALITY-реализации: изменения Xray начиная с 26.9.8 требуют отдельной проверки. Закрепление версий обеспечивает воспроизводимость этого релиза и не заменяет дальнейшие обновления с проверкой совместимости.

В Hysteria 2.12.3 исправлено ошибочное перенаправление исходящего UDP при port hopping. В этой версии UltraXRay port hopping для новых установок вообще не включается.

**Публикация релиза не меняет уже работающий сервер.** В старых установках могут сохраняться диапазон UDP 20000–50000 и старая Hysteria. Их миграция — отдельная операция; утилита добавления Edge их не затрагивает.

## Что сохраняется

Конфигурация:

- `/usr/local/etc/xray/config.json`;
- `/etc/hysteria/config.yaml`, `server.crt`, `server.key`.

Доступы:

- `/root/ultraproxy.env`;
- `/root/ultraxray-vless-link.txt`;
- `/root/ultraxray-vless-vision-link.txt`;
- `/root/ultraxray-vless-vision-edge-link.txt`;
- `/root/ultraxray-hy2-link.txt`;
- `/root/ultraxray-hy2-happ-auth-link.txt`;
- `/root/ultraxray-hy2-single-link.txt`;
- `/root/ultraxray-hy2-official-link.txt`.

Для основных ссылок создаются PNG QR-коды. Ссылки содержат доступы: не публикуйте их и `ultraproxy.env` в репозитории.

Повторный вывод ссылок, включая Edge из старого env-файла:

```bash
bash scripts/generate-links.sh /root/ultraproxy.env
```

Hysteria использует самоподписанный сертификат. Official URI содержит `pinSHA256`; клиент должен поддерживать и проверять этот pin. Остальные варианты ссылок предназначены для разных импортёров и могут содержать `insecure=1` без pin. Совместимость импорта нужно проверять в конкретном приложении.

## Диагностика и проверки разработки

```bash
systemctl status xray hysteria-server.service
journalctl -u xray -u hysteria-server.service -n 80 --no-pager
ss -lntup
bash scripts/diagnose-server.sh /root/ultraproxy.env
```

Диагностический скрипт выводит ссылки доступа: перед публикацией его вывода удалите секреты.

```bash
python3 -m unittest discover -s tests -v
bash -n install.sh
for script in scripts/*.sh; do bash -n "$script"; done
```

Тесты проверяют сохранение параметров профиля, повторный запуск генератора, совместимость старых env-файлов, отказ при занятых портах и существующей установке, а также отсутствие сброса/включения UFW. Они не запускают установку пакетов на настоящем сервере.

## Документация

- [Изменения](CHANGELOG.md)
- [Архитектура](docs/ARCHITECTURE.md)
- [Установщик](docs/INSTALLER_FLOW.md)
- [Клиентские профили](docs/CLIENT_PROFILES.md)
- [Диагностика](docs/TROUBLESHOOTING.md)
- [Источники](docs/SOURCES.md)
