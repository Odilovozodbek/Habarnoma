# Habarnoma Sinxron

ChatGPT’dagi reja, Claude’dagi kod, Gemini’dagi dizayn va Telegram’dagi qarorlarni bitta loyihaga jamlaydigan oflayn dastur.

## Ishga tushirish

Habarnoma_Sinxron.html faylini yuklab, kompyuterdagi Chrome yoki Edge bilan oching. Har bir loyiha alohida saqlanadi. Qaydlar brauzerning IndexedDB bazasida turadi. Boshqa kompyuterga ko‘chirish uchun JSON nusxasini eksport qiling.

1. Loyiha yarating va maqsad hamda keyingi vazifani kiriting.
2. Manba nomi va suhbat havolasini qo‘shing.
3. Qaysi manbaga tegishli ekanini tanlab, chat eksportini yoki javob matnini qo‘shing.
4. Qaydlarni qaror, bajarilgan ish, ochiq masala yoki kod sifatida belgilang.
5. Eski qarorni “Eski versiya” qilib belgilang. Uni “Oldingi versiyalar” orqali qayta faollashtirish mumkin.
6. “AI uchun paket” bo‘limida keyingi AI va kontekst hajmini tanlang. Tayyor Markdown matnini yangi chatga yuboring.

ChatGPT va Claude JSON eksportlari, Telegram Desktop JSON, TXT/MD hamda Habarnoma JSON nusxalari qabul qilinadi. Bir nechta suhbatli eksportda kerakli suhbatlarni tanlaysiz. Takroriy qaydlar bir manba doirasida qayta qo‘shilmaydi. Import qilingan loyiha nusxalari loyiha ID raqami bo‘yicha birlashtiriladi.

## Katta loyihalar

Papka, ZIP yoki alohida fayllarni oching. Boshlang‘ich tanlov kod va hujjatlarni oladi. Build, kesh, media va kalit saqlashi mumkin bo‘lgan fayllar ro‘yxatda belgilanadi. Kerakli fayllarni tekshirib tanlang.

Har bir ZIP uchun MB chegarasini kiriting. Masalan, 480 MB. Limitdan katta bitta fayl ham qismlarga ajratiladi. Barcha qismlar mustaqil ZIP hisoblanadi. Qismlar yoniga dasturdan olingan tiklash.py faylini qo‘yib, Python 3.8+ orqali ishga tushirsangiz, yangi papkaga tiklanadi. ZIP qismlarida fayllar siqishsiz saqlanadi, hajmga ajratish natijasi oldindan hisoblanadi.

Kontekst hajmi KB bo‘yicha cheklanadi. Matn qoidalar va kalit so‘zlar bilan saralanadi. Uzun fayllarning boshi, o‘rtasi va oxiridan parcha olinadi. Qamrov hisoboti ko‘rinadi. Rasm, audio va videoning mazmunini tushunish uchun AI/OCR hali ulanmagan. Ular asl fayl sifatida ZIP’ga kirishi mumkin.

## Guruh bilan ishlash

“So‘rovni ulashish” umumiy loyiha promptini beradi. “Javob shaklini olish” jamoa a’zolariga yuboriladigan oflayn HTML yaratadi. Ular qaytargan JSON loyihaning ID raqami bilan qayta import qilinadi.

Telegram yordamchisini dastur ichidan yuklash mumkin. Python 3.8+ bilan ishga tushiring, BotFather tokenini terminalga kiriting va botni guruhga qo‘shing. Terminaldagi bir martalik ulash buyrug‘idan keyin kerakli xabarga /jamla@bot_nomi deb javob bering. Yordamchi ochiq turgan vaqtda belgilangan matnlar mahalliy JSON fayliga yig‘iladi.

## Ulanish holati

Havolalar manba va dalil sifatida saqlanadi. Bir xil Google akkauntini serverda tasdiqlash va yopiq AI suhbatlarini havoladan avtomatik o‘qish hali ulanmagan. Bu versiyada Google OAuth sozlamalari va bulut sinxronlash mavjud emas. Akkauntlar tasdiqlangan deb ko‘rsatilmaydi. Suhbat matnlari foydalanuvchi import qilgan ma’lumotlardan olinadi.

Shaxsiy ChatGPT Share havolalariga havolani olganlar kira oladi. Google akkauntiga kirish uchinchi tomonning yopiq chat tarixini o‘qish ruxsatini avtomatik bermaydi. Kelajakdagi ulanishda akkaunt identifikatsiyasi va suhbatga kirish ruxsati har ikkisi alohida tekshirilishi kerak.

## Tekshirish va yig‘ish

~~~sh
python3 sync/build.py
node sync/tests/core.cjs
~~~

Yig‘ish Python standart kutubxonasidan foydalanadi. Tekshiruv Node.js 22+ talab qiladi. zip.js 2.7.57 BSD-3-Clause litsenziyasi bilan vendor ichida joylashgan.

Avtomatik sinov manbalar, loyihalar izolyatsiyasi, chat shoxlari, eski versiyalar, kontekst hajmi, ZIP bo‘lish va baytma-bayt tiklashni tekshiradi. To‘liq brauzer UI sinovi ushbu muhitda Chromium ishga tushmagani sabab bajarilmadi. Jonli Telegram ulanishi va telefon brauzerlari tekshirilmagan.
