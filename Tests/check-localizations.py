import collections
import json
import pathlib
import re
import subprocess

root = pathlib.Path(__file__).resolve().parent.parent
catalogs = {}
for language in ('cs', 'sk'):
    path = root / 'Resources' / f'{language}.lproj' / 'Localizable.strings'
    subprocess.run(['plutil', '-lint', str(path)], check=True)
    catalogs[language] = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(path)]))
assert catalogs['cs'].keys() == catalogs['sk'].keys(), 'Missing translation keys'
for key, value in catalogs['sk'].items():
    assert value.strip(), f'Empty translation: {key}'
    placeholders = lambda text: collections.Counter(re.findall(r'%(?:lld|@)', text))
    assert placeholders(key) == placeholders(value), f'Placeholder mismatch: {key}'
for path in (root / 'Sources/Webshare').glob('*.swift'):
    for raw in re.findall(r'"((?:\\.|[^"\\])*)"', path.read_text()):
        if r'\(' in raw or not re.search('[áčďéěíňóřšťúůýžÁČĎÉĚÍŇÓŘŠŤÚŮÝŽ]', raw):
            continue
        value = json.loads('"' + raw + '"')
        assert value in catalogs['sk'], f'Untranslated source text in {path.name}: {value}'
print(f'Lokalizace cs/sk: {len(catalogs["sk"])} textů, úplnost a formátovací zástupci v pořádku.')
