"""Single-user observer API for the Flutter Android client. HTTPS reverse proxy required."""
import argparse
import asyncio
import contextlib
import hmac
import os
import re
import sqlite3
from contextlib import asynccontextmanager
from pathlib import Path
from dotenv import load_dotenv
from fastapi import FastAPI, Depends, Header, HTTPException
from pydantic import BaseModel
from telethon import TelegramClient
from telethon.errors import FloodWaitError, RPCError
from telethon.tl.types import Channel, Chat

os.chdir(Path(__file__).resolve().parent)
os.umask(0o077)
load_dotenv()
CATEGORIES={
 'dars':('dars','imtihon','расписание',"mashg'ulot"), 'hakaton':('hakaton','hackathon','хакатон'), 'tanlov':('tanlov','конкурс'),
 'musobaqa':('musobaqa','olimpiada','олимпиада'),
 'tadbir':('tadbir','seminar','konferensiya','trening','uchrashuv'),
 'grant':('grant','stipendiya'), 'universitet':('universitet','talaba'),
}

def classify(text):
    t=text.lower().replace('‘',"'").replace('’',"'").replace('ʻ',"'")
    future=any(w in t for w in ("bo'lib o'tadi","o'tkaziladi","ro'yxatdan",'ariza','registration','qabul boshlandi','регистрац'))
    past=any(w in t for w in ("bo'lib o'tdi",'yakunlandi',"g'oliblar",'состоялся'))
    category=next((k for k,words in CATEGORIES.items() if any(w in t for w in words)),None)
    if past and not future:return None
    return category if category in ('universitet','dars') or future else None

def connect():
    db=sqlite3.connect('havola.db');db.row_factory=sqlite3.Row
    db.executescript('''
    CREATE TABLE IF NOT EXISTS sources(name TEXT PRIMARY KEY, filter TEXT, cursor INTEGER, status TEXT);
    CREATE TABLE IF NOT EXISTS events(id INTEGER PRIMARY KEY AUTOINCREMENT, source TEXT, message_id INTEGER, category TEXT, text TEXT, url TEXT, UNIQUE(source,message_id));
    CREATE TABLE IF NOT EXISTS fingerprints(text TEXT PRIMARY KEY);
    ''')
    return db

client=None
db=None
async def observer():
    while True:
        for source in db.execute('SELECT * FROM sources').fetchall():
            try:
                async for msg in client.iter_messages(source['name'],min_id=source['cursor'],reverse=True,limit=100):
                    text=msg.raw_text or ''
                    category=classify(text)
                    if category and source['filter'] in ('all',category):
                        fingerprint=re.sub(r'\W+','',re.sub(r'https?://\S+|@\w+','',text.lower()))
                        if db.execute('INSERT OR IGNORE INTO fingerprints VALUES (?)',(fingerprint,)).rowcount:
                            db.execute('INSERT OR IGNORE INTO events(source,message_id,category,text,url) VALUES (?,?,?,?,?)',(source['name'],msg.id,category,text[:12000],f"https://t.me/{source['name']}/{msg.id}"))
                    db.execute('UPDATE sources SET cursor=?,status=? WHERE name=?',(msg.id,'Kuzatilmoqda',source['name']));db.commit()
                db.execute('UPDATE sources SET status=? WHERE name=?',('Kuzatilmoqda',source['name']));db.commit()
            except FloodWaitError as e:
                db.execute('UPDATE sources SET status=? WHERE name=?',(f'Kutish: {e.seconds}s',source['name']));db.commit()
                await asyncio.sleep(e.seconds)
            except (RPCError,ValueError):
                db.execute('UPDATE sources SET status=? WHERE name=?',('Kirish imkoni yo‘q',source['name']));db.commit()
            except Exception:
                db.execute('UPDATE sources SET status=? WHERE name=?',('Ulanishda xato, qayta tekshiriladi',source['name']));db.commit()
            await asyncio.sleep(2)
        await asyncio.sleep(60)

@asynccontextmanager
async def lifespan(app):
    global client,db
    if not os.getenv('API_ID') or not os.getenv('API_HASH') or len(os.getenv('ACCESS_TOKEN',''))<32:
        raise RuntimeError('API_ID, API_HASH va kamida 32 belgilik ACCESS_TOKEN ni server .env faylida sozlang.')
    db=connect();client=TelegramClient('observer',int(os.environ['API_ID']),os.environ['API_HASH'])
    await client.connect()
    if not await client.is_user_authorized():
        await client.disconnect();raise RuntimeError('Avval python server.py --login buyrug‘ini bajaring.')
    task=asyncio.create_task(observer())
    try:yield
    finally:
        task.cancel()
        with contextlib.suppress(asyncio.CancelledError):await task
        await client.disconnect();db.close()

app=FastAPI(title='Havola observer',lifespan=lifespan,docs_url=None,redoc_url=None,openapi_url=None)
async def auth(authorization: str=Header(default='')):
    expected='Bearer '+os.getenv('ACCESS_TOKEN','')
    if len(os.getenv('ACCESS_TOKEN',''))<32 or not hmac.compare_digest(authorization.encode(),expected.encode()):
        raise HTTPException(401,'Unauthorized')

class Source(BaseModel):
    name:str
    filter:str='all'

@app.get('/sources',dependencies=[Depends(auth)])
async def sources():return [dict(row) for row in db.execute('SELECT name,filter,status FROM sources').fetchall()]

@app.post('/sources',dependencies=[Depends(auth)])
async def add_source(source:Source):
    name=source.name.lower()
    if not re.fullmatch(r'[a-z][a-z0-9_]{3,31}',name) or source.filter not in ('all',*CATEGORIES):raise HTTPException(422,'Invalid source/filter')
    if db.execute('SELECT 1 FROM sources WHERE name=?',(name,)).fetchone():return {'status':'already_added'}
    try:
        entity=await client.get_entity(name)
        if not isinstance(entity,(Channel,Chat)):raise HTTPException(422,'Not a channel/group')
        latest=await client.get_messages(entity,limit=1)
    except FloodWaitError:raise HTTPException(429,'Try later')
    except (RPCError,ValueError):raise HTTPException(403,'Cannot access source')
    db.execute('INSERT OR IGNORE INTO sources VALUES (?,?,?,?)',(name,source.filter,latest[0].id if latest else 0,'Kuzatilmoqda'));db.commit()
    return {'status':'added'}

@app.delete('/sources/{name}',dependencies=[Depends(auth)])
async def remove_source(name:str):
    db.execute('DELETE FROM sources WHERE name=?',(name,));db.commit();return {'status':'removed'}

@app.get('/events',dependencies=[Depends(auth)])
async def events(after:int=0):
    if after<0:raise HTTPException(422,'Invalid cursor')
    return [dict(row) for row in db.execute('SELECT * FROM events WHERE id>? ORDER BY id LIMIT 200',(after,)).fetchall()]

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--login',action='store_true');args=parser.parse_args()
    if args.login:
        async def login():
            if not os.getenv('API_ID') or not os.getenv('API_HASH'):raise SystemExit('API_ID/API_HASH ni .env da sozlang.')
            c=TelegramClient('observer',int(os.environ['API_ID']),os.environ['API_HASH'])
            await c.start();await c.disconnect()
        asyncio.run(login())
    else:
        import uvicorn
        uvicorn.run(app,host='127.0.0.1',port=8000)
