# IntentCoverage

**Find, review, and test your app's App Intents coverage.**

A local Swift developer tool that connects SwiftUI actions to domain operations, maps existing App Intents, explains missing exposure, and generates a reviewed Search adapter for the included TaskFlow demo.

```text
$ intentcoverage analyze Examples/TaskFlowDemo

App Intent source coverage: 40% (2/5)
Basis: reviewed_source_mapping

○ Change Due Date  [MISSING]
✓ Complete Task    [EXPOSED] CompleteTaskIntent
✓ Create Task      [EXPOSED] CreateTaskIntent
○ Delete Task      [MISSING]
○ Search Tasks     [MISSING]

Runtime validation: not_run
Siri experience: not_checked
```

Status: **0.1.0 preview**. Eleven Swift tests and the physical iPhone 12 five-action workflow passed on the recorded prototype. The generated Search adapter compiled in the app. The separate iOS 27 AppIntentsTesting lane remains unverified. See [verification](docs/verification.md).

## Build and run

Tested with Xcode 26.6 / Swift 6.3.3 on macOS. Python 3.10+ is needed for the demo scripts. SwiftSyntax 603.0.2 is pinned; the initial package build downloads that dependency. Analysis itself makes no network requests and uses no API key.

```sh
swift build --jobs 2
swift test --jobs 2
.build/debug/intentcoverage analyze Examples/TaskFlowDemo
.build/debug/intentcoverage analyze Examples/TaskFlowDemo --json --output report.json
.build/debug/intentcoverage explain search_tasks Examples/TaskFlowDemo
.build/debug/intentcoverage doctor
```

## Reproduce the vertical slice

```sh
python3 scripts/demo.py --build
```

The script creates a disposable copy under `.intentcoverage`, verifies 2/5 exposure, generates a candidate, verifies that generation alone changes nothing, accepts Search into the copy, and verifies 3/5. It builds the accepted app for physical iOS and checks that removing its intent fails the baseline check. The baseline example stays at two intents.

For a binary built with a custom scratch path, pass `--binary /absolute/path/to/intentcoverage`.

Manual generation:

```sh
.build/debug/intentcoverage generate search_tasks Examples/TaskFlowDemo --output /tmp/taskflow-search-candidate
.build/debug/intentcoverage check Examples/TaskFlowDemo --baseline report.json
```

The output directory must be new. Read its `REVIEW.md` before adding files to a target. See [generation contracts](docs/generation.md).

## TaskFlow on the physical iPhone 12

TaskFlow includes five working UI actions, a persistent actor-isolated domain repository, task entities and queries, and Create/Complete App Intents. Its iOS deployment minimum is 17.

The committed project uses a generic bundle identifier and no signing team. Set `bundleIdentifier` in `.intentcoverage-generation.json` to one you control before generating candidates for your app. Then regenerate with your development team:

```sh
python3 scripts/create-xcode-project.py --team YOUR_TEAM_ID
open Examples/TaskFlowDemo/TaskFlowDemo.xcodeproj
```

Select your physical iPhone (recorded QA used an iPhone 12) and the `TaskFlowDemo` scheme. The UI test uses a UUID-scoped test store and exercises all five actions and persistence. Normal tasks use a separate store. Coordinate exclusive device access before installation or testing. No simulator is used by this project.

The generated **AppIntentsTesting** source belongs only in a separate iOS 27+ UI test target. The recorded Xcode 26.6 / iOS 26.6.1 setup cannot compile or execute that lane. A normal UI test, direct `perform()` call, successful app build, or source score must never be labeled an AppIntentsTesting pass. See [verification status](docs/verification.md).

## Scope and evidence

V1 discovers explicit `Type.shared.method(...)` / `Type.method(...)` calls inside SwiftUI `View`/`App` declarations and matches unambiguous domain operation names with a small verb vocabulary. It inspects App Intent declarations, local extension conformances, `@Parameter` properties, entities, query types, and shortcut providers using SwiftSyntax.

This is a controlled MVP, not complete compiler-backed coverage of arbitrary Swift projects. Instance receiver resolution, macro expansion, conditional configurations, UIKit navigation, target membership, external protocol conformances, and full call graphs need additional analysis. Diagnostics keep those limits visible. Malformed Swift, invalid roots, and capability ID collisions fail analysis rather than silently produce a score.

`.intentcoverage.json` selects source roots and records eligibility decisions with reasons. Decisions do not create capabilities: the scanner must rediscover the source evidence. Unreviewed findings are marked provisional; destructive actions need review. Only eligible capabilities enter the denominator. Zero eligible capabilities produce N/A.

Source declarations, runtime validation, and Siri experience are separate. Report v1 always says `runtimeValidation: not_run`; it does not ingest or invent passing test receipts. Test evidence is recorded separately in the verification document. Adding that evidence ingestion is a later step once the compatible framework lane has been verified.

Baseline checks exit 2 for lost exposure, disappeared/new capabilities, changed eligibility decisions, or unreviewed candidates. Errors exit 1. An analyzer-version or source-scope change makes baselines incomparable. A pass does not execute app tests.

- [Report schema](Schemas/report.schema.json)
- [Configuration schema](Schemas/config.schema.json)
- [Phase 0 research](docs/phase-0-research.md)
- [Generation contract](docs/generation.md)
- [Verification record](docs/verification.md)

## Privacy and current boundaries

No source upload, telemetry, provider calls, server, or AI dependency is present. Generated files are separate candidates. The example generation binding is deliberately specific to the reviewed TaskFlow architecture and invalidates if the bound domain/entity source changes. No Store submission or public publishing workflow is included.

## Contributing and license

See [CONTRIBUTING.md](CONTRIBUTING.md), [community conduct](CODE_OF_CONDUCT.md), [security reporting](SECURITY.md), and the [changelog](CHANGELOG.md), and [release checklist](docs/releasing.md). Mac-side CI builds and tests the package and compiles the accepted demo for generic physical iOS; it does not execute iOS UI tests or claim Siri validation.

Original code is [MIT licensed](LICENSE). Dependencies retain their own licenses; see [third-party notices](THIRD_PARTY_NOTICES.md).
