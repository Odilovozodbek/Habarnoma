// Run from the havola_flutter project directory. No Python or packages required.
import 'dart:io';

void main() {
  try {
    prepare();
  } catch (error) {
    stderr.writeln('XATO: $error');
    exitCode = 1;
  }
}

void prepare() {
  final root = Directory.current;
  File file(String path) => File('${root.path}/$path');
  final manifest = file('android/app/src/main/AndroidManifest.xml');
  if (!file('pubspec.yaml').existsSync() || !manifest.existsSync()) {
    throw StateError('CMDni havola_flutter papkasida oching. Avval flutter create buyrugi tugagan bolishi kerak.');
  }
  final inputs = ['MainActivity.kt', 'SyncEngine.kt', 'PublicSources.kt', 'Bulletins.kt'];
  for (final name in inputs) {
    if (!file('native/$name').existsSync()) {
      throw StateError('native/$name topilmadi. Loyihaning native papkasi kerak.');
    }
  }
  final target = Directory('${root.path}/android/app/src/main/kotlin/uz/havola/havola');
  target.createSync(recursive: true);
  var text = manifest.readAsStringSync();
  if (!text.contains('<application') || !text.contains('</application>') || !text.contains('</manifest>')) {
    throw StateError('AndroidManifest.xml tuzilishini tekshiring.');
  }
  // Back up generated files before the first edit. Re-running is safe.
  backup(manifest);
  for (final name in inputs) {
    final destination = File('${target.path}/$name');
    if (destination.existsSync()) backup(destination);
    file('native/$name').copySync(destination.path);
  }
  for (final permission in ['INTERNET', 'POST_NOTIFICATIONS', 'RECEIVE_BOOT_COMPLETED']) {
    final value = 'android.permission.$permission';
    if (!text.contains('android:name="$value"')) {
      text = text.replaceFirst('<application', '<uses-permission android:name="$value" />\n    <application');
    }
  }
  text = text.replaceAll('android:label="havola"', 'android:label="Habarnoma.uz"');
  text = text.replaceAll('android:label="Havola"', 'android:label="Habarnoma.uz"');
  if (!text.contains('android:allowBackup=')) {
    text = text.replaceFirst('<application', '<application android:allowBackup="false"');
  }
  if (!text.contains('SyncJob"')) {
    text = text.replaceFirst('</application>', '<service android:name=".SyncJob" android:permission="android.permission.BIND_JOB_SERVICE" android:exported="false" />\n    </application>');
  }
  if (!text.contains('android.intent.action.TTS_SERVICE')) {
    const intent = '<intent><action android:name="android.intent.action.TTS_SERVICE" /></intent>';
    if (text.contains('</queries>')) {
      text = text.replaceFirst('</queries>', '$intent\n    </queries>');
    } else {
      text = text.replaceFirst('</manifest>', '<queries>$intent</queries>\n</manifest>');
    }
  }
  final icon = file('android/app/src/main/res/drawable-nodpi/habarnoma.webp');
  icon.parent.createSync(recursive: true);
  file('native/res/drawable-nodpi/habarnoma.webp').copySync(icon.path);
  text = text.replaceAll('@mipmap/ic_launcher', '@drawable/habarnoma');
  final parserTest = file('android/app/src/test/kotlin/uz/havola/havola/PublicSourcesTest.kt');
  parserTest.parent.createSync(recursive: true);
  file('test/PublicSourcesTest.kt').copySync(parserTest.path);
  final build = file('android/app/build.gradle.kts');
  var gradle = build.readAsStringSync();
  if (!gradle.contains('org.jsoup:jsoup:')) {
    gradle += '\ndependencies { implementation("org.jsoup:jsoup:1.18.3"); testImplementation("junit:junit:4.13.2"); testImplementation("org.json:json:20240303") }\n';
  }
  // Install alongside the earlier APK, whose temporary signing key is unavailable.
  gradle = gradle.replaceAll('applicationId = "uz.havola.havola"', 'applicationId = "uz.habarnoma.mobile"');
  build.writeAsStringSync(gradle);
  text = text.replaceAll('android:name=".MainActivity"','android:name="uz.havola.havola.MainActivity"').replaceAll('android:name=".SyncJob"','android:name="uz.havola.havola.SyncJob"');
  manifest.writeAsStringSync(text);
  stdout.writeln('TAYYOR: Android ovoz va bildirishnoma kodlari ulandi.');
  stdout.writeln('Keyingi buyruq: flutter build apk --debug');
}

void backup(File file) {
  final copy = File('${file.path}.before_habarnoma');
  if (!copy.existsSync()) file.copySync(copy.path);
}
