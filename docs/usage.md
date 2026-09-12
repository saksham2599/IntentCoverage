# Using IntentCoverage

This guide assumes you have cloned the repository, run `swift build --jobs 2`, and added `.build/debug` to your shell's `PATH` as described in the [README](../README.md). Commands run from the repository root unless stated otherwise.

## Choose the workflow

| Goal | Start here |
| --- | --- |
| Understand the product with a known example | `intentcoverage analyze Examples/TaskFlowDemo` |
| Reproduce generation, acceptance and regression checks | `python3 scripts/demo.py --build` |
| Inspect an individual gap | `intentcoverage explain search_tasks Examples/TaskFlowDemo` |
| Evaluate supported patterns in another app | Configure source roots, analyze, then review discoveries. |
| Catch changes in a reviewed project | Save a baseline, then run `check` in your review or CI process. |

The CLI does not install the demo on your phone. The automated demo script compiles for generic physical iOS only when `--build` is provided.

## Analyze an existing project

`<project>` is the root directory whose Swift source you want to inspect. It is independent of your shell's current directory and can be an absolute path.

```sh
intentcoverage analyze /path/to/MyApp
```

With no `.intentcoverage.json`, the scanner starts at `.` and marks discoveries unreviewed. It skips hidden files, symbolic links, common dependency/build folders and directories ending in `Tests`, `.xcodeproj`, or `.xcworkspace`. This is a filesystem scan; it does not resolve Xcode target membership.

Prefer explicit source roots for a real project. Create `.intentcoverage.json` **inside the app's project directory**:

```json
{
  "schemaVersion": 1,
  "sourceRoots": ["App", "Domain", "Intents"],
  "decisions": {}
}
```

Replace those folder names with folders that actually exist. Roots are relative to the analyzed project and must stay inside it. Keep tests, generated candidates, and unrelated example apps outside the selected roots.

### Recognize a supported source pattern

This abbreviated example illustrates the call shape; it is not a complete app:

```swift
struct TaskScreen: View {
    var body: some View {
        Button("Add task") {
            Task {
                _ = try await TaskRepository.shared.createTask(title: "Read")
            }
        }
    }
}
```

The scanner can connect that explicit call to a unique `TaskRepository.createTask` declaration. An intent whose `perform()` directly calls the same symbol can establish a source mapping. By comparison, `repository.createTask(...)` through an injected instance is outside the current receiver-resolution support.

The current operation vocabulary is `create`, `complete`, `delete`, `search`, `change`, `archive`, `share`, `rename`, `duplicate`, `add`, `remove`, and `update`. This heuristic does not discover every possible user-facing operation. Renaming production APIs merely to increase the score is not a useful substitute for broader analysis.

## Review eligibility

Run analysis before filling in decisions. Use discovered capability IDs, such as `create_task` and `search_tasks`, rather than inventing IDs from feature names.

For example, a project that actually exposes the matching domain methods might record:

```json
{
  "schemaVersion": 1,
  "sourceRoots": ["App", "Domain", "Intents"],
  "decisions": {
    "create_task": {
      "eligibility": "eligible",
      "reason": "Creating a task is a user-facing operation suitable for an intent."
    },
    "delete_task": {
      "eligibility": "needs_review",
      "reason": "Confirm the authorization and confirmation behavior before exposure."
    }
  }
}
```

Supported eligibility values are `eligible`, `excluded`, and `needs_review`. Every recorded decision requires a nonempty reason. Only `eligible` capabilities enter the score's denominator.

A capability with no decision has `reviewState: unreviewed`. A recorded `needs_review` decision is different: it explicitly leaves eligibility unresolved and excludes that capability from the denominator. The `check` command does not treat that policy state alone as a failure if it matches the baseline. Review policy decisions independently of the percentage.

Decisions do not create capabilities. If a configured capability is not rediscovered, diagnostics flag it. `explain` helps inspect the underlying source:

```sh
intentcoverage explain search_tasks Examples/TaskFlowDemo
```

The output includes the domain symbol, effect classification, review state, source declaration/call locations, and mapped intent names. Confirm that the evidence represents the user outcome you intend to measure.

## Save and inspect a report

```sh
mkdir -p reports
intentcoverage analyze Examples/TaskFlowDemo --json --output reports/taskflow.json
```

The report includes `capabilities`, `intents`, `entities`, `queries`, `shortcutsProviders`, `diagnostics`, and a source/configuration digest. Capability records include eligibility, reasons, source evidence, and mapped intents. `coverage` summarizes eligible, exposed and unreviewed counts.

Read it with your preferred JSON viewer, or inspect a few fields using Python:

```sh
python3 - <<'PY'
import json
from pathlib import Path
report = json.loads(Path('reports/taskflow.json').read_text())
print(report['coverage'])
for capability in report['capabilities']:
    print(capability['id'], capability['eligibility'], capability['intents'])
PY
```

Treat a full report as the baseline input. A copied JSON excerpt or a manually edited percentage is not a valid replacement: the decoder checks consistency between the summary and capability records. The [report schema](../Schemas/report.schema.json) documents the serialized structure.

Report v1 always records `runtimeValidation: not_run` and `siriExperience: not_checked`. Build and device evidence are separate; editing those strings would not establish a passing test.

## Manually generate and accept the demo adapter

Use a disposable copy so the repository's baseline fixture remains unchanged. These commands use one shell session and a unique temporary parent directory:

```sh
demo_workspace="$(mktemp -d "${TMPDIR:-/tmp}/intentcoverage-guide.XXXXXX")"
cp -R Examples/TaskFlowDemo "$demo_workspace/TaskFlowDemo"
intentcoverage analyze "$demo_workspace/TaskFlowDemo" --output "$demo_workspace/before.json"
intentcoverage generate search_tasks "$demo_workspace/TaskFlowDemo" --output "$demo_workspace/candidate"
intentcoverage analyze "$demo_workspace/TaskFlowDemo"
```

Both analyses should show 40%. The generated directory contains:

| File | Purpose |
| --- | --- |
| `SearchTasksIntent.swift` | App Intent calling the existing repository search and returning task entities. |
| `TaskFlowIntentTests.swift` | Separate candidate system integration test source requiring iOS 27. |
| `REVIEW.md` | Source digest, binding identity, and acceptance instructions. |

Read the candidate files and `REVIEW.md`. Check behavior, parameters, returned entities, the app bundle identifier, and the target where each file belongs. The `.intentcoverage-generation.json` binding is deliberately specific to TaskFlow; copying it into an unrelated app does not make general generation supported.

After review, accept only the Search adapter into the disposable app's Intents folder and regenerate the project:

```sh
cp "$demo_workspace/candidate/SearchTasksIntent.swift" "$demo_workspace/TaskFlowDemo/Intents/SearchTasksIntent.swift"
python3 scripts/create-xcode-project.py --root "$demo_workspace/TaskFlowDemo"
intentcoverage analyze "$demo_workspace/TaskFlowDemo" --output "$demo_workspace/after.json"
intentcoverage check "$demo_workspace/TaskFlowDemo" --baseline "$demo_workspace/before.json"
```

Analysis now shows 60%, and the comparison to the initial baseline passes because the existing mappings remain intact. The report still says runtime validation has not run.

Compile the accepted app without signing:

```sh
xcodebuild \
  -project "$demo_workspace/TaskFlowDemo/TaskFlowDemo.xcodeproj" \
  -scheme TaskFlowDemo \
  -configuration Debug \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$demo_workspace/DerivedData" \
  -jobs 2 CODE_SIGNING_ALLOWED=NO build
```

This establishes compilation only. Do not add the generated integration test to the app target. To prepare its separate future test target, follow the [generation contract](generation.md). Its required framework lane is still unverified in the recorded setup.

## Use a baseline in review or CI

First analyze and review the project, then save the baseline in a location your team chooses to version:

```sh
mkdir -p reports
intentcoverage analyze Examples/TaskFlowDemo --output reports/baseline.json
intentcoverage check Examples/TaskFlowDemo --baseline reports/baseline.json
```

For another app, replace `Examples/TaskFlowDemo` with its project directory. In CI, build the CLI and run `check` against the previously reviewed report. Do not regenerate that baseline immediately before checking: doing so would erase the comparison with the earlier state.

The gate flags:

- Removed mapped intent identities, including a rename that leaves the score unchanged.
- Disappeared or newly discovered capabilities.
- Changed eligibility values or recorded reasons.
- Parameter-name changes on an existing intent.
- Discoveries without recorded decisions.

Changing selected source roots or the analyzer version makes baselines incomparable. Baseline checks are deliberately scoped: they do not detect every semantic behavior change, prove parameter-type compatibility, or execute app tests. A newly exposed intent can pass the gate without runtime validation.

| Exit code | Meaning |
| --- | --- |
| `0` | The requested command completed; for `check`, no supported regression condition was found. |
| `1` | Invalid arguments, analysis/generation error, unsupported report, or incomparable baseline. |
| `2` | A baseline regression or review condition was found. |

After an intentional change, inspect the difference and update the baseline through your normal review process. Do not automatically replace it just to make CI green.

## Run TaskFlow on a physical iPhone

The example app has an iOS 17 minimum. Recorded QA used an iPhone 12; the project and CI do not use an iOS simulator.

1. In `Examples/TaskFlowDemo/.intentcoverage-generation.json`, set `bundleIdentifier` to one you control.
2. Generate the project using your own team:

   ```sh
   python3 scripts/create-xcode-project.py --team YOUR_TEAM_ID
   open Examples/TaskFlowDemo/TaskFlowDemo.xcodeproj
   ```

3. Select the `TaskFlowDemo` scheme and your physical iPhone in Xcode. Complete normal pairing, signing, and device setup as needed.
4. Run the app, or run its UI test to exercise all five operations and persistence.

The UI test uses a UUID-scoped DEBUG store, separate from normal tasks. Coordinate exclusive device access before automated interaction. Do not commit personal signing configuration, provisioning files, or test data.

An ordinary UI pass is not an AppIntentsTesting pass. The generated integration source requires its own iOS 27+ UI test target and compatible Xcode tooling. `intentcoverage doctor` inspects local framework presence, not whether the phone or a system intent actually works.

## Troubleshooting

| Symptom | What to inspect |
| --- | --- |
| `intentcoverage: command not found` | Build first, then add `.build/debug` to `PATH` or invoke the binary directly. |
| First build is slow | SwiftSyntax is downloaded and compiled initially. Use a compatible toolchain and a small job count; source analysis itself needs no network. |
| No Swift files / source root missing | Pass the project directory and select existing source folders, not the `.xcodeproj` bundle. |
| A UI action is missing from the report | Check the explicit receiver shape, operation vocabulary, unique declaration, and configured roots. Unsupported source patterns can be missed. |
| Score is N/A | No discovered capability is currently eligible. Inspect decisions and discovery scope. |
| Score is provisional | At least one discovered capability has no recorded decision. Inspect its evidence before adding a decision. |
| Generation says no binding / unsupported capability | Generic generation is not implemented. Start with the supplied TaskFlow Search example. |
| Generation contract changed | Review the domain/entity changes before refreshing the binding digests. Do not bypass the contract merely to silence the error. |
| Output already exists | Choose a new candidate directory; generation does not overwrite prior files. |
| Output inside scanned roots | Generate outside those roots and explicitly accept reviewed files afterward. |
| Baseline check exits 2 at the same percentage | Inspect mapped intent identities, decisions, parameters and capability changes; the gate compares more than the score. |
| AppIntentsTesting framework absent | Continue source analysis and normal app builds. Keep the separate framework lane unverified until compatible tooling and runtime are available. |

For a bug report, include the commit, toolchain versions, command, and a minimal sanitized Swift/configuration example. Follow [security guidance](../SECURITY.md) for private vulnerabilities and [contribution guidance](../CONTRIBUTING.md) for proposed changes.
