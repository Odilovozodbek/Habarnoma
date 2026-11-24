#!/usr/bin/env python3
"""Habarnoma ZIP qismlaridan tanlangan fayllarni tiklash. Python 3.8+."""
import json
import os
import re
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

INDEX = "HABARNOMA-INDEX.json"


def safely_named(path):
    if not isinstance(path, str) or "\\" in path or path.startswith("/") or re.match(r"^[A-Za-z]:", path):
        return False
    components = path.split("/")
    if not all(p and p not in (".", "..") and all(ord(c) >= 32 for c in p) for p in components):
        return False
    if os.name == "nt" and any(re.search(r'[<>:"|?*]|[. ]$', p) or
            re.fullmatch(r"(CON|AUX|PRN|NUL|COM[1-9]|LPT[1-9])(?:\..*)?", p, re.I) for p in components):
        return False
    return True


def gather(paths):
    groups = {}
    for path in paths:
        with zipfile.ZipFile(path) as z:
            if INDEX not in z.namelist():
                continue
            with z.open(INDEX) as f:
                m = json.load(f)
            if m.get("format") != "habarnoma-parts-v1":
                continue
            key, number, total = m["bundle"], m["part"], m["parts"]
            if not isinstance(key, str) or not re.fullmatch("[0-9a-f]{24}", key):
                raise ValueError("Paket ID yaroqsiz.")
            if type(number) is not int or type(total) is not int or not 1 <= number <= total:
                raise ValueError("Qism raqami yaroqsiz.")
            expected, parts = groups.setdefault(key, (total, {}))
            if expected != total or number in parts:
                raise ValueError("Qism takrorlangan yoki jami mos kelmadi.")
            parts[number] = (path, m["files"])
    return groups


def restore(key, total, parts, parent):
    if len(parts) != total:
        missing = [str(i) for i in range(1, total + 1) if i not in parts]
        raise ValueError("Yetishmayotgan qismlar: " + ", ".join(missing[:50]))
    destination = parent / ("restored-" + key[:12])
    if destination.exists():
        raise ValueError(str(destination) + " mavjud. Uni avval boshqa nomga ko‘chiring.")
    stage = Path(tempfile.mkdtemp(prefix="habarnoma-", dir=parent))
    states = {}
    try:
        for i in range(1, total + 1):
            src, rows = parts[i]
            with zipfile.ZipFile(src) as z:
                used = set()
                for row in rows:
                    name, entry = row["path"], row["entry"]
                    offset, length, size = (row[k] for k in ("offset", "length", "size"))
                    if not safely_named(name) or not safely_named(entry) or entry in used or entry == INDEX:
                        raise ValueError("Yaroqsiz yoki takroriy yo‘l.")
                    used.add(entry)
                    if not all(type(v) is int and v >= 0 for v in (offset, length, size)) or offset + length > size:
                        raise ValueError(name + " — uzunlik xatosi.")
                    pos, expected, done = states.get(name, (0, size, False))
                    if done or pos != offset or size != expected or z.getinfo(entry).file_size != length:
                        raise ValueError(name + " — bo‘lak tartibi yoki hajmi mos emas.")
                    target = stage.joinpath(*name.split("/"))
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with z.open(entry) as source, target.open("ab" if pos else "xb") as output:
                        shutil.copyfileobj(source, output, length=1024 * 1024)
                    states[name] = (pos + length, size, pos + length == size)
        if not all(done for _, _, done in states.values()):
            raise ValueError("Fayl to‘liq emas.")
        stage.rename(destination)
        return destination
    finally:
        if stage.exists():
            shutil.rmtree(stage)


if __name__ == "__main__":
    try:
        folder = Path(__file__).resolve().parent
        inputs = [Path(arg) for arg in sys.argv[1:]] or sorted(folder.glob("*.zip"))
        bundles = gather(inputs)
        if not bundles:
            raise ValueError("Skript yoniga Habarnoma ZIP qismlarini joylashtiring.")
        for bundle, (count, content) in bundles.items():
            print("Tiklandi:", restore(bundle, count, content, folder))
    except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile) as error:
        print("Xato:", error, file=sys.stderr)
        sys.exit(1)
