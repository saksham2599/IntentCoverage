#!/usr/bin/env python3
"""Reproduce discovery -> candidate generation -> explicit demo-copy acceptance -> reanalysis."""
import argparse, json, shutil, subprocess
from datetime import datetime, timezone
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument('--binary',type=Path)
parser.add_argument('--build',action='store_true',help='Also compile the accepted demo for generic physical iOS; no simulator')
args=parser.parse_args()
repo=Path(__file__).resolve().parents[1]
binary=(args.binary or repo/'.build/debug/intentcoverage').resolve()
if not binary.is_file(): raise SystemExit('Build first: swift build --jobs 4')
run=repo/'.intentcoverage'/('demo-'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'))
run.mkdir(parents=True)
copy=run/'TaskFlowDemo'; shutil.copytree(repo/'Examples/TaskFlowDemo',copy)
def analyze(destination):
    result=subprocess.run([str(binary),'analyze',str(copy),'--json'],check=True,capture_output=True,text=True)
    destination.write_text(result.stdout)
    return json.loads(result.stdout)
before=analyze(run/'before.json')
assert before['coverage']['eligible']==5 and before['coverage']['exposed']==2, before['coverage']
subprocess.run([str(binary),'generate','search_tasks',str(copy),'--output',str(run/'candidate')],check=True)
unchanged=analyze(run/'candidate-only.json')
assert unchanged['coverage']==before['coverage']
# This script explicitly accepts only into its newly created disposable demo copy.
shutil.copy2(run/'candidate/SearchTasksIntent.swift',copy/'Intents/SearchTasksIntent.swift')
(copy/'TaskFlowIntentTests').mkdir(exist_ok=True)
shutil.copy2(run/'candidate/TaskFlowIntentTests.swift',copy/'TaskFlowIntentTests/TaskFlowIntentTests.swift')
after=analyze(run/'after.json')
assert after['coverage']['eligible']==5 and after['coverage']['exposed']==3, after['coverage']
subprocess.run(['python3',str(repo/'scripts/create-xcode-project.py'),'--root',str(copy)],check=True)
subprocess.run([str(binary),'check',str(copy),'--baseline',str(run/'before.json')],check=True,capture_output=True)
# Prove an exposure regression is caught by the CLI's nonzero exit code.
search=copy/'Intents/SearchTasksIntent.swift'; accepted=search.read_text()
search.unlink()
regression=subprocess.run([str(binary),'check',str(copy),'--baseline',str(run/'after.json')],capture_output=True,text=True)
search.write_text(accepted)
(run/'regression-check.txt').write_text(regression.stdout+regression.stderr)
assert regression.returncode==2, 'Missing intent did not fail the baseline check'
search.write_text(accepted.replace('SearchTasksIntent', 'FindTasksIntent'))
renamed=analyze(run/'renamed.json')
assert renamed['coverage']['percent']==60
rename_check=subprocess.run([str(binary),'check',str(copy),'--baseline',str(run/'after.json')],capture_output=True,text=True)
search.write_text(accepted)
(run/'rename-regression-check.txt').write_text(rename_check.stdout+rename_check.stderr)
assert rename_check.returncode==2, 'Renaming a mapped intent must require review even at the same coverage'
if args.build:
    with (run/'accepted-build.log').open('w') as log:
        subprocess.run(['xcodebuild','-project',str(copy/'TaskFlowDemo.xcodeproj'),'-scheme','TaskFlowDemo','-configuration','Debug','-sdk','iphoneos','-destination','generic/platform=iOS','-derivedDataPath',str(run/'DerivedData'),'-jobs','2','CODE_SIGNING_ALLOWED=NO','build'],stdout=log,stderr=subprocess.STDOUT,check=True)
print('Source exposure: 2/5 (40%) -> 3/5 (60%)')
print('Generated candidates alone do not increase coverage. Missing accepted intent fails the baseline check.')
print('Runtime validation: NOT RUN. AppIntentsTesting requires Xcode 27 and iOS 27.')
print('Artifacts:',run)
(repo/'.intentcoverage/latest-demo.txt').write_text(str(run)+'\n')
