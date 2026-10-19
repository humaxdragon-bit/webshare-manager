import json
import os
import pathlib
import plistlib
import sys

app = pathlib.Path(sys.argv[1])
config = json.loads(pathlib.Path('updates/config.json').read_text())
path = app / 'Contents/Info.plist'
info = plistlib.loads(path.read_bytes())
info.update(SUFeedURL=config['feed_url'], SUPublicEDKey=config['public_key'], SUVerifyUpdateBeforeExtraction=True, SUEnableAutomaticChecks=True, SUAutomaticallyUpdate=False, SUSendProfileInfo=False)
if os.environ.get('APP_VERSION'):
    info['CFBundleShortVersionString'] = os.environ['APP_VERSION']
if os.environ.get('APP_BUILD'):
    info['CFBundleVersion'] = os.environ['APP_BUILD']
path.write_bytes(plistlib.dumps(info))
