#!/usr/bin/env python3
"""Habarnoma Telegram yordamchisi. Python 3.8+. Tokenni o‘z kompyuteringizda kiriting."""
import datetime
import getpass
import json
import os
import re
import secrets
import sqlite3
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

PROJECT = json.loads(bytes.fromhex("__PROJECT_HEX__").decode("utf-8"))
ROOT = Path(__file__).resolve().parent


class BotError(Exception):
    pass


def api(token, method, **params):
    req = urllib.request.Request(
        "https://api.telegram.org/bot" + token + "/" + method,
        data=json.dumps(params).encode(), headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=48) as resp:
            result = json.load(resp)
    except urllib.error.HTTPError as exc:
        raise BotError("Telegram HTTP " + str(exc.code)) from None
    except (OSError, ValueError) as exc:
        raise BotError("Telegram bilan aloqa uzildi.") from None
    if not result.get("ok"):
        raise BotError("Telegram so‘rovni qabul qilmadi.")
    return result["result"]


def db_init(db):
    db.executescript("""
        CREATE TABLE IF NOT EXISTS state (key TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS notes
            (chat INTEGER, msg INTEGER, source TEXT, body TEXT, at TEXT, PRIMARY KEY(chat,msg));
    """)


def state(db, key, fallback=""):
    value = db.execute("SELECT value FROM state WHERE key=?", (key,)).fetchone()
    return value[0] if value else fallback


def put(db, key, value):
    db.execute("INSERT OR REPLACE INTO state VALUES (?, ?)", (key, str(value)))


def handle(db, update, username, pair):
    msg = update.get("message") or {}
    chat = msg.get("chat") or {}
    if chat.get("type") not in ("group", "supergroup") or msg.get("from", {}).get("is_bot"):
        return None
    text = (msg.get("text") or "").strip()
    match = re.fullmatch(r"/(ulash|jamla)(?:@(\w+))?(?:\s+([\s\S]*))?", text, re.I)
    if not match or (match[2] and match[2].lower() != username.lower()):
        return None
    group = str(chat["id"])
    bound = state(db, "group")
    arg = (match[3] or "").strip()
    if match[1].lower() == "ulash":
        if not bound and secrets.compare_digest(arg.encode(), pair.encode()):
            put(db, "group", group)
            return "Guruh ulandi. Belgilangan loyiha xabarlariga /jamla@" + username + " bilan javob bering."
        return None
    if group != bound:
        return None
    item = msg if arg else msg.get("reply_to_message") or {}
    body = arg or item.get("text") or item.get("caption") or ""
    if not body.strip():
        return "Loyiha matnini buyruqdan keyin yozing yoki matnli xabarga javob bering."
    author = item.get("from") or {}
    name = " ".join(filter(None, [author.get("first_name"), author.get("last_name")])) or "Guruh"
    at = datetime.datetime.fromtimestamp(item.get("date", 0), datetime.timezone.utc).isoformat()
    cursor = db.execute("INSERT OR IGNORE INTO notes VALUES (?,?,?,?,?)",
                        (chat["id"], item["message_id"], "Telegram · " + name, body, at))
    return "Loyiha qaydiga qo‘shildi." if cursor.rowcount else "Bu xabar avval qo‘shilgan."


def export_file(db, path):
    notes = [{"title": PROJECT["name"] + " · Guruh", "source": s, "body": b, "at": t}
             for s, b, t in db.execute("SELECT source,body,at FROM notes ORDER BY at,msg")]
    data = {"format": "habarnoma-project-v1", "project": {**PROJECT, "notes": notes}}
    tmp = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, encoding="utf-8", delete=False) as f:
            tmp = Path(f.name)
            json.dump(data, f, ensure_ascii=False)
        tmp.replace(path)
    finally:
        if tmp and tmp.exists():
            tmp.unlink()


def main():
    token = os.getenv("HABARNOMA_TELEGRAM_TOKEN") or getpass.getpass("BotFather bergan bot tokeni (ekranda ko‘rinmaydi): ").strip()
    if not re.fullmatch(r"\d+:[A-Za-z0-9_-]+", token):
        raise ValueError("Bot tokeni formati yaroqsiz.")
    me = api(token, "getMe")
    username = me["username"]
    base = "habarnoma-" + PROJECT["id"] + "-" + str(me["id"])
    db = sqlite3.connect(ROOT / (base + ".sqlite3"))
    result = ROOT / (base + ".json")
    db_init(db)
    pair = secrets.token_hex(5)
    if not state(db, "group"):
        print("Botni kerakli guruhga qo‘shing va guruhda shu buyruqni yuboring:")
        print("/ulash@" + username + " " + pair)
    print("Saqlash: /jamla@" + username + " matn  yoki xabarga javoban /jamla@" + username)
    print("JSON natija:", result)
    print("Dasturni ochiq qoldiring. To‘xtatish: Ctrl+C.")
    export_file(db, result)
    try:
        while True:
            try:
                updates = api(token, "getUpdates", offset=int(state(db, "offset", "0")),
                              timeout=30, allowed_updates=["message"])
                for update in updates:
                    with db:
                        reply = handle(db, update, username, pair)
                        put(db, "offset", update["update_id"] + 1)
                    if reply:
                        export_file(db, result)
                        msg = update["message"]
                        options = {"message_thread_id": msg["message_thread_id"]} if msg.get("message_thread_id") else {}
                        api(token, "sendMessage", chat_id=msg["chat"]["id"], text=reply, **options)
            except BotError as e:
                if str(e) in ("Telegram HTTP 401", "Telegram HTTP 409", "Telegram HTTP 404"):
                    raise BotError(str(e) + " — tokenni yoki shu bot boshqa joyda ishlayotganini tekshiring.") from None
                print(str(e), "5 soniyadan so‘ng qayta uriniladi.", file=sys.stderr)
                time.sleep(5)
    finally:
        db.close()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("To‘xtatildi.")
    except (BotError, OSError, ValueError, sqlite3.Error) as e:
        print("Xato:", e, file=sys.stderr)
        sys.exit(1)
