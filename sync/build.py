"""Build the offline application using only Python's standard library."""
from pathlib import Path
import json
root = Path(__file__).resolve().parent
source = root / 'src'
page = (source / 'page.html').read_text()
engine = (root / 'vendor/zip-no-worker.min.js').read_text()
license_text = (root / 'vendor/ZIPJS-LICENSE').read_text()
constants = []
for key, name in [('FORM_TEMPLATE', 'form.html'), ('RESTORE_SOURCE', 'tiklash.py'), ('BOT_SOURCE', 'telegram.py')]:
    value = json.dumps((source / name).read_text(), ensure_ascii=False).replace('<', r'\u003c')
    constants.append(f'const {key} = {value};')
page = page.replace('<!--ENGINE-->', '<!-- zip.js 2.7.57\n' + license_text + '-->\n<script>' + engine + '</script>')
page = page.replace('/*APP*/', '\n'.join(constants) + '\n' + (source / 'app.js').read_text() + '\n' + (source / 'workspace.js').read_text())
(root / 'Habarnoma_Sinxron.html').write_text(page)
print(root / 'Habarnoma_Sinxron.html')
