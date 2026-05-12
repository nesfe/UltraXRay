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

## VLESS Vision REALITY

Формат:

```text
vless://UUID@SERVER_IP:8443?encryption=none&type=tcp&security=reality&sni=TARGET_HOST&fp=chrome&pbk=PUBLIC_KEY&sid=SHORT_ID&flow=xtls-rprx-vision#UltraXRay-Vision-REALITY
```

Этот профиль предназначен для клиентов, которые поддерживают REALITY/Vision, но нестабильно работают с `XHTTP` или `VLESS Encryption`.

## Hysteria 2

Формат:

```text
hy2://PASSWORD@SERVER_IP:20000-50000/?security=tls&insecure=1&obfs=salamander&obfs-password=OBFS_PASSWORD&sni=TARGET_HOST&mportHopInt=30#UltraXRay-Hysteria2-Full
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
| `mportHopInt=30` | интервал port hopping для клиентов, которые читают Happ-style параметр |

Дополнительно сохраняется официальный URI:

```text
hysteria2://PASSWORD@SERVER_IP:20000-50000/?insecure=1&obfs=salamander&obfs-password=OBFS_PASSWORD&sni=TARGET_HOST&pinSHA256=CERT_FINGERPRINT#UltraXRay-Hysteria2-Official
```

## Где Хранятся Ссылки

```text
/root/ultraxray-vless-link.txt
/root/ultraxray-hy2-link.txt
/root/ultraxray-hy2-happ-auth-link.txt
/root/ultraxray-hy2-single-link.txt
/root/ultraxray-hy2-official-link.txt
```

QR-коды:

```text
/root/ultraxray-vless-qr.png
/root/ultraxray-hy2-qr.png
```
