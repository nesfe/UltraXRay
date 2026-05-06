# Troubleshooting

## Проверить Сервисы

```bash
systemctl status xray
systemctl status hysteria-server.service
```

## Проверить Логи

```bash
journalctl -u xray -n 120 --no-pager
journalctl -u hysteria-server.service -n 120 --no-pager
```

## Проверить Порты

```bash
ss -ltnp
ss -lunp
```

Ожидаемо:

- `443/tcp` слушает `xray`;
- Hysteria 2 слушает UDP и настраивает port hopping через firewall rules.

## Проверить Firewall

```bash
ufw status verbose
iptables -S
iptables -t nat -S
```

Ожидаемо открыты:

- `22/tcp`;
- `443/tcp`;
- `20000:50000/udp`.

## Проверить Конфиг Xray

```bash
/usr/local/bin/xray run -test -config /usr/local/etc/xray/config.json
```

Ожидаемый результат:

```text
Configuration OK.
```

## Ошибка Проверки TLS-Хоста

Если при установке появляется ошибка вида:

```text
s_client: -connect argument or target parameter malformed or ambiguous
```

значит в старой версии установщика URL был передан в `openssl` без нормализации. Актуальная версия принимает `https://domain/` и приводит его к `domain`.

Актуальная версия не останавливает установку на временной ошибке TLS-проверки. Она использует ровно тот hostname, который ввёл пользователь, и продолжает установку с предупреждением.

Для ручной проверки используйте чистый hostname:

```bash
echo | openssl s_client -connect lemanapro.ru:443 -servername lemanapro.ru -verify_hostname lemanapro.ru
```

## Клиент Не Импортирует VLESS

Проверьте:

- поддерживает ли клиент `XHTTP`;
- поддерживает ли клиент VLESS Encryption;
- обновлён ли встроенный Xray-core;
- не потерялся ли длинный параметр `encryption`;
- сохранились ли `path`, `mode`, `pbk`, `sid`, `sni`.

Если клиент старый, он может поддерживать `REALITY`, но не поддерживать новый `XHTTP` или VLESS Encryption.

## Hysteria 2 Не Подключается

Проверьте:

- открыт ли UDP диапазон у VPS-провайдера;
- не блокирует ли провайдер входящий UDP;
- совпадает ли `obfs-password`;
- совпадает ли основной пароль Hysteria;
- импортировался ли `pinSHA256`;
- не урезал ли клиент multi-port формат `20000-50000`.

## Повторно Вывести Доступы

```bash
cat /root/ultraproxy.env
cat /root/ultraxray-vless-link.txt
cat /root/ultraxray-hy2-link.txt
```

Или:

```bash
bash scripts/generate-links.sh /root/ultraproxy.env
```
