#!/usr/bin/env python3
"""Sign the archive using the private key retained in macOS Keychain."""
import email.utils
import hashlib
import json
import pathlib
import plistlib
import shutil
import subprocess
import xml.etree.ElementTree as ET

root = pathlib.Path(__file__).resolve().parent.parent
config = json.loads((root / 'updates/config.json').read_text())
info = plistlib.loads((root / 'dist/Webshare Manager.app/Contents/Info.plist').read_bytes())
version, build = info['CFBundleShortVersionString'], info['CFBundleVersion']
asset = f'Webshare-Manager-{version}-arm64.zip'
archive = root / 'dist' / asset
shutil.copyfile(root / 'dist/Webshare-Manager-macOS.zip', archive)
signer = root / '.build/artifacts/sparkle/Sparkle/bin/sign_update'
signature = subprocess.check_output([str(signer), '-p', str(archive)], text=True).strip()
subprocess.run([str(signer), '--verify', str(archive), signature], check=True)
ns = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle', ns)
rss = ET.Element('rss', {'version': '2.0'})
channel = ET.SubElement(rss, 'channel')
ET.SubElement(channel, 'title').text = 'Webshare Manager'
ET.SubElement(channel, 'link').text = f"https://github.com/{config['repository']}"
ET.SubElement(channel, 'description').text = 'Aktualizace aplikace Webshare Manager'
ET.SubElement(channel, 'language').text = 'cs'
item = ET.SubElement(channel, 'item')
ET.SubElement(item, 'title').text = f'Webshare Manager {version}'
ET.SubElement(item, 'pubDate').text = email.utils.formatdate(usegmt=True)
ET.SubElement(item, f'{{{ns}}}version').text = build
ET.SubElement(item, f'{{{ns}}}shortVersionString').text = version
ET.SubElement(item, f'{{{ns}}}minimumSystemVersion').text = '14.0'
ET.SubElement(item, f'{{{ns}}}hardwareRequirements').text = 'arm64'
notes = (root / 'updates/release-notes.txt').read_text()
ET.SubElement(item, 'description').text = notes
ET.SubElement(item, 'enclosure', {
    'url': f"https://github.com/{config['repository']}/releases/download/v{version}/{asset}",
    'length': str(archive.stat().st_size), 'type': 'application/octet-stream',
    f'{{{ns}}}edSignature': signature,
})
ET.indent(rss)
ET.ElementTree(rss).write(root / 'updates/appcast.xml', encoding='utf-8', xml_declaration=True)
checksum = root / 'dist' / f'{asset}.sha256'
checksum.write_text(f'{hashlib.sha256(archive.read_bytes()).hexdigest()}  {asset}\n')
print(f'Připraveno: {asset}, sestavení {build}')
