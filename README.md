# Habarnoma (Havola) · Android

Havola loyihasining Flutter ilovasi va Telegram kanallaridagi e’lonlarni kuzatuvchi shaxsiy server. Telefonda ilova **Habarnoma.uz** nomi bilan ko‘rinadi.

## APK yuklab olish

1. GitHub hisobingizga kiring va [Android APK](https://github.com/Odilovozodbek/Habarnoma/actions/workflows/android.yml) sahifasini oching.
2. Yashil belgi qo‘yilgan oxirgi yig‘ishni oching.
3. Sahifaning pastidagi **Artifacts** bo‘limida **Habarnoma.apk** faylini bosing. Yuklangan APK faylini Android telefonda oching.

`main` tarmog‘iga kod yuklanganda GitHub APK’ni avtomatik yig‘adi. Shu sahifadagi **Run workflow** orqali ham yig‘ishni boshlash mumkin. Bu shaxsiy sinov uchun debug APK.

## 0.3 versiyasidan foydalanish

**Manbalar → Sayt yoki Telegram qo‘shish** oynasiga ochiq kanal, sayt yoki RSS/Atom havolasini kiriting. Telefon ochiq Telegram kanallarining veb-ko‘rinishini, saytning yangiliklar tasmasini yoki sahifa matnini o‘qiydi. Manba ilk bor tekshirilganda mavjud xabarlar katalogga tushadi. Keyingi yangi xabarlar bildirishnoma beradi. Rasm ichidagi jadvallar va kirish talab qiladigan sahifalar uchun matnli ochiq manba kerak.

Katalogning yuqori menyusida **Dars vaqtlari**, **Tanlovlar** yoki boshqa toifani tanlang. Tanlov bildirishnomalarga ham qo‘llanadi. Xulosada e’lonning muhim jumlalari, matnda berilgan sana va vaqt ko‘rsatiladi. **Batafsil → Manbani ochish** asl e’longa olib boradi.

**Sozlamalar → Musiqa tanlash** telefondagi audio faylni bildirishnoma tovushi sifatida belgilaydi. Natijani **Signalni tekshirish** orqali eshiting. Fondagi tekshiruv Android ruxsatlari va batareya sozlamalariga bog‘liq. Shaxsiy Telegram serverini ham sozlamalar orqali ulash mumkin.

0.3 versiyasi avvalgi sinov APK’si bilan yonma-yon o‘rnatiladi. Manbalar va sozlamalar har bir nusxada alohida saqlanadi.

## Android ishga tushirish

GitHub’dagi yig‘ishda Flutter 3.38.9 va Java 17 ishlatiladi. Kompyuterda yig‘ish uchun Android SDK ham kerak. Buyruqlarni `pubspec.yaml` joylashgan papkada bajaring.

```
flutter create --no-pub --platforms=android --org uz.havola --project-name havola .
dart tool/prepare_android.dart
flutter pub get
flutter test
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter run
```

`flutter create` Android papkasini yaratadi. `tool/prepare_android.dart` loyihadagi Kotlin kodini, bildirishnoma ruxsatlarini va fon xizmatini Android ilovasiga qo‘shadi. APK’ni kompyuterda olish uchun `flutter build apk --debug` buyrug‘ini bajaring. Fayl `build/app/outputs/flutter-apk/app-debug.apk` manziliga yoziladi.

## Telegram server (shaxsiy bir foydalanuvchili)

```
cd server
python -m venv .venv
# Linux: source .venv/bin/activate
# Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

`.env.example` dan `.env` yarating:
- API_ID/API_HASH: https://my.telegram.org → API development tools.
- ACCESS_TOKEN: `python -c "import secrets; print(secrets.token_urlsafe(32))"` bilan o‘zingizning terminalingizda yarating. Bu OpenAI kaliti emas.

```
python server.py --login
python server.py
```

Kodni o‘z terminalingizda Telegram akkauntiga ulang; SMS/Telegram kodi, 2FA paroli, sessiya fayli va tokenlarni chat yoki GitHubga bermang. Servis akkaunt avtomatik guruhlarga qo‘shilmaydi. Kuzatuvchi faqat o‘zi kira oladigan ochiq guruh/kanallarni oladi.

Server 127.0.0.1:8000 da tinglaydi. Uni HTTPS reverse proxy ortida o‘z domeningizda joylashtiring; ilova HTTP yoki yo‘naltirishni qabul qilmaydi. Ilovada Sozlamalar → HTTPS manzil va ACCESS_TOKEN ni kiriting → Saqlash va ulanish. Keyin Manbalar bo‘limida kanal havolasini qo‘shing.

Server — shaxsiy bir foydalanuvchi rejimi. Token telefonda private SharedPreferences ichida saqlanadi, Android backup o‘chirilgan. Ko‘p foydalanuvchili xizmat uchun autentifikatsiya, rate-limit, token aylantirish, encrypted storage va push tizimini alohida kuchaytirish kerak. Server bazasini almashtirsangiz ilova sozlamasida serverni vaqtincha bo‘shatib qayta ulang (cursor tozalanadi). Android faqat eng oxirgi 1000 ta yozuvni lokal saqlaydi; manba o‘chirilganda eski e’lonlar qoladi.

## Tekshiruvlar

```
cd server
python -m unittest -v
```

Flutter testi havola validatsiyasini, Python testi saralashni tekshiradi. `tool/prepare.py` qayta bajarishga mos.

Manbalar: https://docs.flutter.dev/platform-integration/platform-channels va https://developer.android.com/develop/ui/views/notifications/channels
