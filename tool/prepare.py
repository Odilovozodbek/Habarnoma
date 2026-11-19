"""Run after flutter create. Idempotently install the Android implementation."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[1]
android=root/'android/app/src/main'
if not android.exists():
    raise SystemExit('Avval flutter create --platforms=android --org uz.havola --project-name havola . buyrug‘ini bajaring.')
target=android/'kotlin/uz/havola/havola'
target.mkdir(parents=True,exist_ok=True)
for file in (root/'native').glob('*.kt'): shutil.copy2(file,target/file.name)
manifest=android/'AndroidManifest.xml'
s=manifest.read_text()
for permission in ['INTERNET','POST_NOTIFICATIONS','RECEIVE_BOOT_COMPLETED']:
    tag=f'    <uses-permission android:name="android.permission.{permission}" />'
    if tag not in s: s=s.replace('<application',tag+'\n    <application',1)
s=s.replace('android:label="havola"','android:label="Havola"')
s=s.replace('<application','<application android:allowBackup="false"',1) if 'android:allowBackup' not in s else s
service='        <service android:name=".SyncJob" android:permission="android.permission.BIND_JOB_SERVICE" android:exported="false" />'
if '.SyncJob' not in s:s=s.replace('</application>',service+'\n    </application>')
queries='<queries><intent><action android:name="android.intent.action.TTS_SERVICE" /></intent></queries>'
if 'android.intent.action.TTS_SERVICE' not in s:s=s.replace('</manifest>',queries+'\n</manifest>')
manifest.write_text(s)
print('Android notification / TTS integration prepared.')
