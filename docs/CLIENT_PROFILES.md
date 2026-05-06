# Клиентские Профили

## VLESS XHTTP REALITY

Формат:

```text
vless://UUID@SERVER_IP:443?encryption=VLESS_ENCRYPTION&type=xhttp&security=reality&sni=TARGET_HOST&fp=chrome&pbk=PUBLIC_KEY&sid=SHORT_ID&path=XHTTP_PATH&mode=packet-up&spx=SPIDER_X#UltraXRay-XHTTP-REALITY
```

Параметры:

| Параметр | Значение |
| --- | --- |
| `UUID` | идентификатор клиента VLESS |
| `SERVER_IP` | публичный IP VPS |
| `443` | порт Xray |
| `encryption` | VLESS Encryption client string |
| `type=xhttp` | транспорт XHTTP |
| `security=reality` | REALITY handshake |
| `sni` | домен маскировки |
| `fp=chrome` | TLS fingerprint клиента |
| `pbk` | REALITY public key |
| `sid` | REALITY shortId |
| `path` | XHTTP path |
| `mode=packet-up` | XHTTP mode |
| `spx` | Reality spiderX |

## Hysteria 2

Формат:

```text
hy2://PASSWORD@SERVER_IP:20000-50000/?insecure=1&obfs=salamander&obfs-password=OBFS_PASSWORD&sni=TARGET_HOST&pinSHA256=CERT_FINGERPRINT#UltraXRay-Hysteria2
```

Параметры:

| Параметр | Значение |
| --- | --- |
| `PASSWORD` | пароль Hysteria 2 auth |
| `SERVER_IP` | публичный IP VPS |
| `20000-50000` | port hopping range |
| `insecure=1` | разрешение self-signed cert |
| `obfs=salamander` | режим обфускации |
| `obfs-password` | пароль Salamander |
| `sni` | SNI Hysteria TLS |
| `pinSHA256` | fingerprint сертификата без двоеточий, как в официальном `hysteria share` |

## Где Хранятся Ссылки

```text
/root/ultraxray-vless-link.txt
/root/ultraxray-hy2-link.txt
```

QR-коды:

```text
/root/ultraxray-vless-qr.png
/root/ultraxray-hy2-qr.png
```
