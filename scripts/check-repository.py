#!/usr/bin/env python3
"""Check portable fixtures, local documentation links, and tracked-file hygiene."""
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import unquote, urlsplit

repo = Path(__file__).resolve().parents[1]
tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=repo).decode().split('\0')
files = [repo / name for name in tracked if name]
failures = []
for file in files:
    relative = file.relative_to(repo)
    if any(part in {'.build', '.swiftpm', '.intentcoverage', 'DerivedData', 'bin', '.local'} for part in relative.parts) or file.suffix in {'.p12', '.p8', '.ipa', '.mobileprovision', '.provisionprofile'}:
        failures.append(f'Local artifact tracked: {relative}')
    if not file.is_file():
        failures.append(f'Tracked file missing: {relative}')
        continue
    if file.suffix == '.png':
        continue
    try:
        content = file.read_text()
    except UnicodeDecodeError:
        failures.append(f'Unexpected binary: {relative}')
        continue
    patterns = [r'/' + 'Users' + r'/[^/\s]+/', r'/' + 'Volumes' + r'/[^/\s]+/',
                r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
                r'\bgh[pousr]_[A-Za-z0-9]{30,}', r'\bgithub_pat_[A-Za-z0-9_]{40,}',
                r'\bAKIA[A-Z0-9]{16}\b']
    if any(re.search(pattern, content) for pattern in patterns):
        failures.append(f'Potential private path or credential: {relative}')
    if file.suffix == '.pbxproj' and re.search(r'DEVELOPMENT_TEAM\s*=\s*"[A-Z0-9]+"', content):
        failures.append(f'Personal signing team tracked: {relative}')
    if file.suffix == '.json':
        json.loads(content)
    if file.suffix == '.md':
        for link in re.findall(r'\]\(([^)]+)\)', content):
            link = link.strip('<>')
            parsed = urlsplit(link)
            if parsed.scheme or parsed.netloc or not parsed.path:
                continue
            if not (file.parent / unquote(parsed.path)).exists():
                failures.append(f'Broken local link in {relative}: {link}')

demo = repo / 'Examples/TaskFlowDemo'
binding = json.loads((demo / '.intentcoverage-generation.json').read_text())
for name, expected in binding['contractDigests'].items():
    if hashlib.sha256((demo / name).read_bytes()).hexdigest() != expected:
        failures.append(f'Stale generation contract: {name}')
with tempfile.TemporaryDirectory(prefix='intentcoverage-portability-') as temporary:
    copy = Path(temporary) / 'TaskFlowDemo'
    shutil.copytree(demo, copy)
    project = Path('TaskFlowDemo.xcodeproj/project.pbxproj')
    subprocess.run(['python3', str(repo/'scripts/create-xcode-project.py'), '--root', str(copy)], check=True, capture_output=True)
    if (demo/project).read_bytes() != (copy/project).read_bytes():
        failures.append('Committed Xcode project does not match deterministic unsigned generation')
    # A changed app identity must reach the generated Xcode targets.
    custom = dict(binding, bundleIdentifier='org.example.custom.taskflow')
    (copy/'.intentcoverage-generation.json').write_text(json.dumps(custom))
    subprocess.run(['python3', str(repo/'scripts/create-xcode-project.py'), '--root', str(copy)], check=True, capture_output=True)
    generated = (copy/project).read_text()
    if 'org.example.custom.taskflow' not in generated or binding['bundleIdentifier'] in generated:
        failures.append('Custom generation binding was not applied to Xcode targets')

if failures:
    raise SystemExit('\n'.join(failures))
print(f'Repository checks passed: {len(files)} tracked files, links, contracts and portable project generation.')
print('Pattern scanning is a limited hygiene check, not a comprehensive secret audit.')
