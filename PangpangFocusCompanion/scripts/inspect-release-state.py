"""Read-only summary; never emit user task/record text. Only compare app-owned keys."""
import hashlib, json, plistlib, subprocess, sys
from pathlib import Path
raw = subprocess.check_output(['defaults', 'export', 'com.tiantian.pangpang-desktop-pet', '-'])
values = plistlib.loads(raw)
owned = {key: value for key, value in values.items() if key.startswith('pangpang.')}
hashes = {key: hashlib.sha256(plistlib.dumps({'value': value}, sort_keys=True)).hexdigest() for key, value in owned.items()}
snapshot = json.loads(owned.get('pangpang.pomodoro.snapshot', b'{}'))
summary = {'phase': snapshot.get('phase'), 'endDate': snapshot.get('endDate'), 'records': len(snapshot.get('records', [])), 'hashes': hashes}
path = Path(sys.argv[1])
if len(sys.argv) > 2 and sys.argv[2] == '--save':
    path.write_text(json.dumps(summary)); path.chmod(0o600)
else:
    previous = json.loads(path.read_text())
    changed = sorted(key for key in hashes.keys() | previous['hashes'].keys() if hashes.get(key) != previous['hashes'].get(key))
    print('Changed app-owned keys:', changed)
    if changed: sys.exit('State changed; review before declaring installation verified')
print('State:', summary['phase'], 'records:', summary['records'], 'deadline preserved:', summary['endDate'] is not None)
