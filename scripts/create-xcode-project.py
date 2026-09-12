#!/usr/bin/env python3
"""Generate the small demo project deterministically; no external project generator required."""
import argparse, hashlib, json, re
from pathlib import Path
from xml.sax.saxutils import escape

parser = argparse.ArgumentParser()
parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1] / 'Examples/TaskFlowDemo')
parser.add_argument('--team', default='')
parser.add_argument('--with-app-intents-testing', action='store_true', help='Requires Xcode 27; adds a separate iOS 27 UI test target')
args = parser.parse_args(); root = args.root.resolve()
binding = json.loads((root / '.intentcoverage-generation.json').read_text())
bundle_id = binding['bundleIdentifier']
if not re.fullmatch(r'[A-Za-z0-9]+(?:[.-][A-Za-z0-9]+)+', bundle_id):
    raise SystemExit('Invalid bundleIdentifier in .intentcoverage-generation.json')
objects = {}
def uid(key): return hashlib.sha256(key.encode()).hexdigest()[:24].upper()
def add(key, body):
    ident = uid(key); objects[ident] = '{ ' + body + ' };'; return ident

def quote(value): return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'
def refs(values): return '(' + ', '.join(values) + (',' if values else '') + ')'
app_sources = sorted(p for folder in ['App','Domain','Intents'] for p in (root / folder).glob('*.swift'))
ui_sources = sorted((root/'TaskFlowUITests').glob('*.swift'))
unit_sources = sorted((root/'TaskFlowUnitTests').glob('*.swift'))
targets = [('TaskFlowDemo', app_sources, 'application', '')]
if ui_sources: targets.append(('TaskFlowUITests', ui_sources, 'bundle.ui-testing', 'TaskFlowDemo'))
if unit_sources: targets.append(('TaskFlowUnitTests', unit_sources, 'bundle.unit-test', 'TaskFlowDemo'))
if args.with_app_intents_testing:
    sources = sorted((root/'TaskFlowIntentTests').glob('*.swift'))
    if not sources: raise SystemExit('No AppIntentsTesting source; generate and add it first.')
    targets.append(('TaskFlowIntentTests', sources, 'bundle.ui-testing', 'TaskFlowDemo'))
file_refs = []
product_refs = []
for target, sources, kind, host in targets:
    for p in sources:
        rel = p.relative_to(root).as_posix()
        ref = add('file:'+rel, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quote(rel)}; sourceTree = "<group>";')
        if ref not in file_refs: file_refs.append(ref)
    ext = 'app' if kind == 'application' else 'xctest'
    product_refs.append(add('product:'+target, f'isa = PBXFileReference; explicitFileType = {"wrapper.application" if ext == "app" else "wrapper.cfbundle"}; path = {target}.{ext}; sourceTree = BUILT_PRODUCTS_DIR;'))
products = add('products', f'isa = PBXGroup; children = {refs(product_refs)}; name = Products; sourceTree = "<group>";')
main = add('main', f'isa = PBXGroup; children = {refs(file_refs+[products])}; sourceTree = "<group>";')
project_configs = []
for config in ['Debug','Release']:
    settings = {'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SWIFT_VERSION':'6.0','CLANG_ENABLE_MODULES':'YES','SWIFT_STRICT_CONCURRENCY':'complete','CODE_SIGN_STYLE':'Automatic','SUPPORTED_PLATFORMS':'iphoneos','TARGETED_DEVICE_FAMILY':'1','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if config=='Debug' else '-O','DEBUG_INFORMATION_FORMAT':'dwarf' if config=='Debug' else 'dwarf-with-dsym'}
    if config == 'Debug': settings.update({'SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG','ENABLE_TESTABILITY':'YES'})
    if args.team: settings['DEVELOPMENT_TEAM'] = args.team
    project_configs.append(add('project-config:'+config, 'isa = XCBuildConfiguration; name = '+config+'; buildSettings = { '+' '.join(k+' = '+quote(v)+';' for k,v in settings.items())+' };'))
project_config = add('project-configs', f'isa = XCConfigurationList; buildConfigurations = {refs(project_configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target_ids = []
for index,(target,sources,kind,host) in enumerate(targets):
    builds = [add('build:'+target+':'+p.relative_to(root).as_posix(), 'isa = PBXBuildFile; fileRef = '+uid('file:'+p.relative_to(root).as_posix())+';') for p in sources]
    phases = [add('sources:'+target, f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {refs(builds)}; runOnlyForDeploymentPostprocessing = 0;'),add('frameworks:'+target,'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;'),add('resources:'+target,'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')]
    configs = []
    for config in ['Debug','Release']:
        bundle = bundle_id + ('.'+target.lower() if host else '')
        settings = {'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':bundle,'GENERATE_INFOPLIST_FILE':'YES','CURRENT_PROJECT_VERSION':'1','MARKETING_VERSION':'0.1.0','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks @loader_path/Frameworks'}
        if not host: settings.update({'INFOPLIST_KEY_CFBundleDisplayName':'TaskFlow','INFOPLIST_KEY_UILaunchScreen_Generation':'YES','INFOPLIST_KEY_UIApplicationSceneManifest_Generation':'YES','INFOPLIST_KEY_UISupportedInterfaceOrientations':'UIInterfaceOrientationPortrait'})
        else: settings['TEST_TARGET_NAME'] = host
        if kind=='bundle.unit-test': settings.update({'TEST_HOST':'$(BUILT_PRODUCTS_DIR)/TaskFlowDemo.app/TaskFlowDemo','BUNDLE_LOADER':'$(TEST_HOST)'})
        if target=='TaskFlowIntentTests': settings['IPHONEOS_DEPLOYMENT_TARGET']='27.0'
        configs.append(add('config:'+target+config,'isa = XCBuildConfiguration; name = '+config+'; buildSettings = { '+' '.join(k+' = '+quote(v)+';' for k,v in settings.items())+' };'))
    config_list = add('configs:'+target,f'isa = XCConfigurationList; buildConfigurations = {refs(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
    dependencies=[]
    if host:
        proxy=add('proxy:'+target,f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("target:"+host)}; remoteInfo = {host};')
        dependencies=[add('dep:'+target,f'isa = PBXTargetDependency; target = {uid("target:"+host)}; targetProxy = {proxy};')]
    target_ids.append(add('target:'+target,f'isa = PBXNativeTarget; buildConfigurationList = {config_list}; buildPhases = {refs(phases)}; buildRules = (); dependencies = {refs(dependencies)}; name = {target}; productName = {target}; productReference = {product_refs[index]}; productType = "com.apple.product-type.{kind}";'))
add('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2660; }}; buildConfigurationList = {project_config}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {main}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = {refs(target_ids)};')
project = root/'TaskFlowDemo.xcodeproj'; project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(k+' = '+v for k,v in sorted(objects.items()))+'\n}; rootObject = '+uid('project')+'; }\n')
def buildable(target):
    ext='app' if target=='TaskFlowDemo' else 'xctest'
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target:"+target)}" BuildableName="{target}.{ext}" BlueprintName="{target}" ReferencedContainer="container:TaskFlowDemo.xcodeproj"/>'
schemes = project/'xcshareddata/xcschemes'; schemes.mkdir(parents=True,exist_ok=True)
for scheme in ['TaskFlowDemo'] + (['TaskFlowIntentTests'] if args.with_app_intents_testing else []):
    testing=[name for name,_,_,host in targets if host and ((name=='TaskFlowIntentTests') == (scheme=='TaskFlowIntentTests'))]
    tests=''.join('<TestableReference skipped="NO">'+buildable(name)+'</TestableReference>' for name in testing)
    xml=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2660" version="1.3">
<BuildAction parallelizeBuildables="NO" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{buildable('TaskFlowDemo')}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables>{tests}</Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="NO"><BuildableProductRunnable runnableDebuggingMode="0">{buildable('TaskFlowDemo')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable('TaskFlowDemo')}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
    (schemes/(scheme+'.xcscheme')).write_text(xml)
print(project)
