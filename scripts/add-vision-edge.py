#!/usr/bin/env python3
"""Create an Edge client profile without changing the server or its credentials."""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit


def edge_uri(uri):
    uri = uri.strip()
    if not uri or any(c.isspace() for c in uri):
        raise ValueError("Ожидается одна VLESS-ссылка без пробелов.")
    parsed = urlsplit(uri)
    if parsed.scheme != "vless" or not parsed.username or not parsed.hostname or not parsed.port:
        raise ValueError("Ожидается VLESS-ссылка с адресом, портом и UUID.")
    pairs = parse_qsl(parsed.query, keep_blank_values=True)
    params = dict(pairs)
    if len(params) != len(pairs):
        raise ValueError("В ссылке повторяются параметры; исправьте исходный профиль.")
    if (params.get("security") != "reality" or params.get("flow") != "xtls-rprx-vision"
            or params.get("type") not in ("tcp", "raw") or params.get("encryption") != "none"):
        raise ValueError("Нужен исходный профиль VLESS + REALITY + Vision, encryption=none.")
    if any(not params.get(key) for key in ("sni", "pbk", "sid")):
        raise ValueError("В исходном профиле отсутствует sni, pbk или sid.")
    params["fp"] = "edge"
    return urlunsplit((parsed.scheme, parsed.netloc, parsed.path, urlencode(params),
                      "UltraXRay-Vision-EDGE-REALITY"))


def private_write(path, data):
    fd, temp = tempfile.mkstemp(dir=path.parent, prefix=".ultraxray-edge-")
    try:
        with os.fdopen(fd, "wb") as output:
            output.write(data)
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", nargs="?", default="/root/ultraxray-vless-vision-link.txt",
                        help="Файл Vision-ссылки или - для stdin")
    parser.add_argument("--output-dir", type=Path, default=None)
    parser.add_argument("--print-only", action="store_true", help="Только вывод ссылки, без записи файлов")
    args = parser.parse_args()
    try:
        original = sys.stdin.read() if args.source == "-" else Path(args.source).read_text()
        link = edge_uri(original)
        if not args.print_only:
            if args.source == "-" and args.output_dir is None:
                parser.error("Для stdin укажите --output-dir или --print-only")
            destination = args.output_dir or Path(args.source).resolve().parent
            destination.mkdir(mode=0o700, parents=True, exist_ok=True)
            private_write(destination / "ultraxray-vless-vision-edge-link.txt", (link + "\n").encode())
            encoder = shutil.which("qrencode")
            if encoder:
                png = subprocess.run([encoder, "-o", "-"], input=link.encode(),
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True).stdout
                private_write(destination / "ultraxray-vless-vision-edge-qr.png", png)
            print(f"Edge-профиль сохранён в {destination}. Конфигурация сервера не изменена.", file=sys.stderr)
        print(link)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Ошибка: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
