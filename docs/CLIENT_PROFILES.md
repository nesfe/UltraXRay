# Клиентские профили

## XHTTP REALITY

```text
vless://UUID@SERVER_IP:443?encryption=VLESS_ENCRYPTION&type=xhttp&security=reality&sni=TARGET_HOST&fp=chrome&pbk=PUBLIC_KEY&sid=SHORT_ID&path=XHTTP_PATH&mode=packet-up&spx=SPIDER_X#UltraXRay-XHTTP-REALITY
```

Клиент должен поддерживать XHTTP и VLESS Encryption. При импорте должны сохраняться encryption, path, mode, SNI, public key и shortId.

## Vision REALITY и Vision EDGE

```text
vless://UUID@SERVER_IP:8443?encryption=none&type=tcp&security=reality&sni=TARGET_HOST&fp=chrome&pbk=PUBLIC_KEY&sid=SHORT_ID&flow=xtls-rprx-vision#UltraXRay-Vision-REALITY
vless://UUID@SERVER_IP:8443?encryption=none&type=tcp&security=reality&sni=TARGET_HOST&fp=edge&pbk=PUBLIC_KEY&sid=SHORT_ID&flow=xtls-rprx-vision#UltraXRay-Vision-EDGE-REALITY
```

Это два клиентских представления одного серверного inbound. UUID, ключи, SNI, shortId и порт совпадают. Дополнительные порты или перезапуск не требуются.

Генератор `python3 scripts/add-vision-edge.py` сохраняет исходную ссылку и все её параметры, кроме fingerprint и отображаемого имени. Есть режим `--print-only` без записи файлов. `scripts/generate-links.sh` умеет выводить Edge из старого env, содержащего VLESS_VISION_LINK.

Проверенная серверная версия нового установщика — Xray 26.6.27. После обновления ядра совместимость fingerprint нужно проверять заново; не считать Edge универсальным для всех последующих REALITY-реализаций.

## Hysteria 2

Новые установки используют один порт:

```text
hy2://PASSWORD@SERVER_IP:20000/?security=tls&insecure=1&obfs=salamander&obfs-password=OBFS_PASSWORD&sni=TARGET_HOST#UltraXRay-Hysteria2
hysteria2://PASSWORD@SERVER_IP:20000/?insecure=1&obfs=salamander&obfs-password=OBFS_PASSWORD&sni=TARGET_HOST&pinSHA256=CERT_FINGERPRINT#UltraXRay-Hysteria2-Official
```

Также сохраняются вариант с `auth=` для совместимых импортёров и single-port alias. Для самоподписанного сертификата предпочтителен клиент, который действительно проверяет `pinSHA256`. Некоторые приложения не принимают `insecure` или по-разному импортируют пароли и pin; факт импорта не подтверждает работоспособность.

Скрипт `fix-hy2-links.sh` берёт фактический порт/диапазон из существующего config.yaml. `fix-hy2-full.sh` сохраняет существующее значение listen и делает резервную копию конфигурации, но всё ещё переписывает другие параметры и перезапускает Hysteria. Эти скрипты не нужны для добавления Edge и не переводят старые установки на одиночный порт.

## Файлы

Ссылки и соответствующие PNG сохраняются под `/root/ultraxray-*`. Edge: `ultraxray-vless-vision-edge-link.txt` и `ultraxray-vless-vision-edge-qr.png`. Ссылки являются доступами к серверу и не должны попадать в публичный GitHub.
