# Разбор Установщика

Основной файл:

```text
scripts/install-ultraxray.sh
```

## Strict Mode

Скрипт запускается в режиме:

```bash
set -euo pipefail
```

Это означает:

- остановку при ошибке команды;
- ошибку при использовании неинициализированной переменной;
- корректную обработку ошибок в pipeline.

## Интерактивные Параметры

Скрипт спрашивает:

- `TARGET_HOST_INPUT` — домен или URL для REALITY SNI;
- `HYSTERIA_PASSWORD` — пароль Hysteria 2.

Если пароль Hysteria пустой, он генерируется автоматически.

`TARGET_HOST_INPUT` нормализуется перед использованием:

- `https://lemanapro.ru/` превращается в `lemanapro.ru`;
- `lemanapro.ru:443/path` превращается в `lemanapro.ru`;
- результат используется в `openssl s_client`, `realitySettings.serverNames`, `target`, Hysteria SNI и клиентских ссылках.

## Очистка

Перед установкой выполняется:

- остановка `xray`;
- остановка `hysteria-server`;
- попытка удаления Hysteria через официальный `get.hy2.sh --remove`;
- удаление старых конфигов;
- удаление старых access-файлов;
- освобождение `443/tcp`;
- очистка `iptables`;
- дальнейший `ufw reset`.

## Xray

Скрипт:

1. устанавливает Xray через официальный installer;
2. генерирует `UUID`;
3. генерирует REALITY `x25519`;
4. генерирует `shortId`;
5. генерирует `XHTTP_PATH`;
6. запускает `xray vlessenc`;
7. берёт ML-KEM-768 `decryption` и `encryption`;
8. пишет `/usr/local/etc/xray/config.json`;
9. проверяет конфиг через `xray run -test`.

## Hysteria 2

Скрипт:

1. устанавливает Hysteria 2 через `get.hy2.sh`;
2. генерирует self-signed ECDSA certificate;
3. вычисляет SHA-256 fingerprint;
4. генерирует Salamander obfuscation password;
5. пишет `/etc/hysteria/config.yaml`;
6. запускает `hysteria-server.service`.

У Hysteria 2.8.2 нет отдельной команды `server ... check`, поэтому валидность подтверждается успешным стартом сервиса.

## Сохранение Доступов

В конце создаются:

- `VLESS_LINK`;
- `HY2_LINK`;
- `/root/ultraproxy.env`;
- текстовые файлы ссылок;
- PNG QR-коды.

`/root/ultraproxy.env` получает права `600`.
