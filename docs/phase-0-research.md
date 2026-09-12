# IntentCoverage — Phase 0

Research date: September 12, 2026. Recommendations below are proposed product decisions, not measured analyzer accuracy. The supplied brief explicitly limits this stage to research and the first implementation step.

## Objective and recommendation

Build a local Swift CLI for discovering, reviewing, and maintaining an application's App Intents interface. Proceed with the controlled demonstration. Do not promise complete automatic discovery of what an arbitrary app can do.

Use **“Find, review, and test your app's App Intents coverage”** as the main promise. “How much of your app can Siri actually use?” can introduce the problem, but the report must distinguish declared exposure from tested runtime behavior and Siri experience checks.

The first customer hypothesis is a developer maintaining an existing SwiftUI productivity app with reusable domain operations and some App Intents adoption. The recurring benefit is seeing new gaps and broken existing integrations during changes. Demand and willingness to pay remain untested. Start with an open-source local CLI; defer hosted services, paid plans, IDE extensions, and generalized agents.

## 1. Apple's relevant architecture

`AppIntent` models an action. `@Parameter` describes its inputs; `perform()` executes the operation and returns an intent result. `AppEntity` models identifiable app content, and entity queries resolve that content. `AppEnum` represents supported choices. These types should adapt the existing domain layer instead of reimplementing its rules. [AppIntent](https://developer.apple.com/documentation/appintents/appintent), [App intents overview](https://developer.apple.com/documentation/appintents/app-intents).

`AppShortcutsProvider` supplies curated `AppShortcut` definitions with phrases and presentation. That is a separate property from merely declaring an intent. A useful coverage tool should record whether a capability has an intent and whether that intent participates in a supplied shortcut. The number of shortcuts must never become the coverage numerator. [App Shortcuts](https://developer.apple.com/documentation/appintents/app-shortcuts).

For newer Siri integrations, also inventory schema annotations, entity indexing, transfer representations, and view annotations as supporting evidence. Do not assume every custom action fits an Apple schema or that declaring an intent makes it work across all Siri experiences. Apple recommends progressing from intent tests to Shortcuts, Spotlight, and full Siri checks. [App Schemas session](https://developer.apple.com/videos/play/wwdc2026/240/).

Execution context matters. Intents can share code with apps and extensions; state ownership, process selection, authentication, and foreground needs affect correctness. The 27 generation introduces further execution and entity APIs. Record their presence, but defer generating these advanced features until the basic slice works. [New App Intents capabilities](https://developer.apple.com/videos/play/wwdc2026/345/).

## 2. AppIntentsTesting: verified capabilities and limits

This is a real Apple framework. It uses a UI testing bundle and executes intents in the app's separate process. The tests identify app types by name instead of importing the app module. It can exercise parameter resolution, returned values, entities, queries, and sequences of intents. It also offers Spotlight and view-annotation checks. Passing such a test is stronger than calling `perform()` directly, but is not proof of spoken recognition or the complete Siri user experience. [WWDC26 testing session](https://developer.apple.com/videos/play/wwdc2026/295/).

Verified API sequence:

1. Launch the signed demo app from its XCUITest target.
2. Construct `IntentDefinitions(bundleIdentifier:)`.
3. Look up `definitions.intents["SearchTasksIntent"]`.
4. Instantiate through `makeIntent(query: ...)` using the actual declared parameter name.
5. Await `run()` and inspect the `ResolvedIntentResult` against an independently defined expectation.

`makeIntent` is a dynamically callable property; `run()` is asynchronous and throwing. The symbol reference specifies plural `intents`. Apple's overview currently contains a singular `definitions.intent` example that disagrees with that reference and the session. Use the symbol reference, then compile with the actual 27 SDK before claiming that generated source works. [IntentDefinitions.intents](https://developer.apple.com/documentation/appintentstesting/intentdefinitions/intents), [makeIntent](https://developer.apple.com/documentation/appintentstesting/appintentdefinition/makeintent), [run](https://developer.apple.com/documentation/appintentstesting/anyappintent/run()).

Entity APIs include `entities(identifiers:)`, `entities(matching:)`, `suggestedEntities()`, `spotlightQuery(_:)`, and `viewAnnotations()`. The generator should only emit assertions backed by the app's entity/query contract. [AppEntityDefinition](https://developer.apple.com/documentation/appintentstesting/appentitydefinition).

Use an isolated, explicitly configured test database. Launch arguments alone cannot reset state in the separate runner's memory. Make the app select its test store before constructing dependencies. If a test-only reset intent is needed, compile it only in the test configuration and exclude it from coverage. Never reset the ordinary user database.

## 3. Minimum versions and this machine

| Component | Requirement or recommendation |
| --- | --- |
| Basic App Intents | Framework availability begins at iOS 16 / macOS 13; Xcode 14-era API baseline |
| TaskFlow demo | Recommend iOS 17+ for a focused SwiftUI implementation; use the currently installed Xcode initially |
| Analyzer CLI | Recommend Swift 6.3 / macOS 13+ as an initial declared build baseline, to be verified by a package build |
| AppIntentsTesting target | Xcode 27 SDK and iOS 27+ runtime; macOS alternative also needs macOS 27+ |
| Xcode 27 RC host | Apple lists macOS 26.6+ and Swift 6.4 |

AppIntent and AppIntentsTesting minimum versions were checked directly in Apple's DocC metadata. The framework's deployment minimum is separate from the consuming application's deployment target: the demo can support older iOS while the dedicated test target requires iOS 27. [AppIntent](https://developer.apple.com/documentation/appintents/appintent), [AppIntentsTesting](https://developer.apple.com/documentation/appintentstesting), [Xcode requirements](https://developer.apple.com/xcode/system-requirements).

Live local inspection found **Xcode 26.6 (17F113), Swift 6.3.3, iOS SDK 26.5, macOS 26.6.2**, and a connected **iPhone 12 running iOS 26.6.1**. AppIntentsTesting was absent from both the active iPhone SDK framework directory and Xcode's iPhone Developer framework directory. The current setup cannot run it. No builds, device tests, installs, or system updates were performed during this research.

Apple lists iPhone 12 among iOS 27-compatible devices. That supports a future test path on the same physical phone; it does not establish an AppIntentsTesting pass or Apple Intelligence feature availability. Keep Apple Intelligence-dependent experience checks separate. No simulator or substitute device is part of this project's test plan. [Apple's compatibility list](https://www.apple.com/os/ios/).

## 4. Static analysis choice

Use **SwiftParser + SwiftSyntax** through Swift Package Manager, with a toolchain-aligned version pinned in the lockfile. For the installed Swift 6.3 toolchain, start by checking the 603.x line; do not adopt a prerelease merely because it has the newest number. SwiftSyntax supplies a source-accurate syntax tree suitable for declarations, attributes, calls, and precise evidence locations. [SwiftSyntax](https://github.com/swiftlang/swift-syntax), [releases](https://github.com/swiftlang/swift-syntax/releases).

| Approach | MVP decision |
| --- | --- |
| Regex / filename matching | File filtering and search only; not the Swift declaration parser |
| SwiftParser / SwiftSyntax | Primary parser and structural evidence collector |
| SourceKit / SourceKit-LSP | Later semantic enrichment for symbol resolution; adds build-setting and indexing integration |
| IndexStoreDB | Later compiler-backed symbol occurrences and relationships; depends on suitable generated index data |
| Compiler symbol graphs | Supplemental API inventory; not sufficient to recover SwiftUI action bodies or product semantics |
| Xcode build metadata | Select relevant targets/configuration and verify integration; not a source of product intent |

SourceKit-LSP integrates with build systems and supplies semantic language services. IndexStoreDB queries compiler-produced symbol information. Those capabilities are useful once simple syntax evidence proves insufficient; neither supplies the missing definition of a user-facing capability. [SourceKit-LSP](https://github.com/swiftlang/sourcekit-lsp), [IndexStoreDB](https://github.com/swiftlang/indexstore-db).

Initial mode should take explicit source roots and exclusions. A later target-aware mode can read the selected Xcode target and compiled metadata. If target membership or conditional compilation is unknown, display that uncertainty rather than implying the source is included in a shipping app. Do not silently run repository build scripts during analysis.

## 5. How reliable is capability inference?

Structural declarations are tractable; complete product intent is not inferable from arbitrary source alone. A SwiftUI button calling a clearly named service operation is strong candidate evidence. A public method without UI usage is weak. A label like “Done” might complete a task, dismiss a sheet, or finish editing.

For the demo, trace explicit UI handlers to five domain operations and compare against a manually specified ground-truth fixture. That fixture is the evaluation oracle, not a hardcoded analyzer input. For real projects, offer candidate review and a versioned capability manifest.

Do not invent numerical confidence such as 0.94. Start with evidence grades and a reason: explicit mapping, syntactic call evidence, naming suggestion, unresolved. Separate matching confidence from eligibility decisions. Publish measured precision/recall only after a labeled evaluation corpus exists.

Support abstention. Unresolved findings should remain visible in the report without silently becoming either missing intents or confirmed exposure. A zero eligible denominator should produce N/A, not 100%.

## 6. Deterministic responsibilities

- Select source roots; omit dependencies, generated outputs, tests, previews, and build directories by default, with visible configurable exclusions.
- Parse nominal declarations, extensions, inheritance syntax, parameters, attributes, UI closures, and call expressions with source locations.
- Recognize qualified names and locally resolvable protocol inheritance; report unresolved aliases, macros, external conformances, and ambiguous dispatch.
- Extract AppIntent, specialized intent protocols, AppEntity, queries, enums, AppShortcutsProvider, and relevant annotations as evidence.
- Resolve explicit reviewed capability mappings and simple unambiguous calls; naming similarities only suggest a mapping.
- Produce stable identifiers, merge duplicate evidence, calculate scores, compare baselines, and validate report schemas.
- Associate test records with the capability, intent, source/build identity, platform, configuration, timestamp, test ID, and result artifact. A test file's existence never proves a pass.

## 7. Where Astra helps

Keep the entire controlled demo deterministic. Add Astra only after candidate review reveals a real ambiguity: naming normalization, classification, likely duplicate capabilities, mapping explanations, or architecture-aware candidate patches.

Use the documented `gpt-6-astra` model through Responses with structured output for proposals. The model supports structured outputs, but schema compliance does not make a classification correct. Validate evidence references and permit `needs_review` / `abstain`. [Astra model](https://developers.openai.com/api/docs/models/gpt-6-astra), [Structured outputs](https://developers.openai.com/api/docs/guides/structured-outputs).

The CLI should work offline by default. An explicit semantic-analysis mode can show and send a bounded evidence packet: signatures, selected call sites, existing mappings, and short relevant snippets. Use the developer's own `OPENAI_API_KEY`; consumer access must not be treated as API billing. Cache by evidence, prompt, schema, and model identity. Set a cost budget and avoid automatic retries of uncertain billed requests. No backend is needed for a local CLI.

Treat repository content as untrusted data, never as model instructions. The semantic classifier should have no shell or file-write authority. Generation produces a reviewable patch plus unresolved assumptions. Do not promise zero provider retention merely because source selection is local or an API response storage setting is disabled.

## 8. False positives and product improvements

| Risk | Treatment |
| --- | --- |
| UI affordance counted as a domain capability | Require evidence of the user outcome and underlying operation |
| One action found in several screens | Group evidence under a stable capability ID |
| Same method name on different receivers | Require resolved identity or abstain |
| Comment/string contains `AppIntent` | Parse syntax; never count text matches as declarations |
| Tests, debug-only reset intents, inactive platform code | Exclude or label by target/configuration |
| Intent simply opens a search screen | Record navigation exposure separately from executing a search and returning results |
| Stub `perform()` or unused intent declaration | Report source evidence only until build and runtime validation exist |
| `isDiscoverable = false` | Record intended surface explicitly; do not count it as ordinary discoverable exposure |
| Auth, permissions, destructive writes | Eligibility is conditional on a reviewed execution policy |
| Missing macros, generated Swift, dynamic dispatch | Record analysis limitations and unresolved mappings |
| Stale passing tests | Invalidate when relevant code/build identity changes |
| Reducing denominator to improve score | Show eligibility changes and exclusions in the review diff |

Improve the graph beyond one overloaded classification field. Store independent dimensions: user-facing assessment, eligibility and reason, effect (read/write/destructive), required interaction, evidence, mappings, review state, and validation records. One capability can map to multiple intents; one intent can support several explicitly distinguished outcomes. Count capabilities once.

The controlled demo may include Delete Task as conditionally eligible because deleting one selected task is a legitimate outcome with confirmation. That does not make bulk/account deletion automatically eligible. Its requirements must remain visible even while the demo's reviewed denominator stays five.

Proposed report contract:

```text
Reviewed eligible capabilities: 5
Source-mapped exposure:         2/5 (40%)
Unreviewed candidates:          shown separately
Runtime validation:            NOT RUN (requires iOS 27)
Siri experience:                NOT CHECKED
```

After generation, do not count a candidate file in an output folder as exposure. Count Search only when the patch is accepted into the selected target and its mapping is established. Preserve separate source and build evidence.

Runtime-validated coverage uses the same eligible denominator. A pass for Search alone is **1/5 = 20%**. A **3/5 = 60%** claim requires passing Create, Complete, and Search tests against the same relevant build. Generated tests need independent expected results, including a negative search case, rather than expectations calculated with the implementation under test.

For CI, gate reviewed contracts first: missing or broken previously covered capabilities and new unreviewed candidates. Compare consistent scope and policy versions. Report additions, deletions, reclassifications, and mappings alongside the percentage. Defer noisy percentage-only gates.

## 9. Repository architecture

Use one package with three initial targets, keeping internal boundaries as directories until they need independent dependencies:

```text
IntentCoverage/
  Package.swift
  Sources/
    IntentCoverageCLI/            argument parsing, exit codes
    IntentCoverageCore/
      Discovery/                 source roots, exclusions, diagnostics
      Analysis/                  SwiftSyntax visitors, evidence
      Graph/                     models, reviewed decisions, mappings
      Coverage/                  formulas and baseline comparison
      Reporting/                 terminal and JSON
    IntentCoverageGenerator/     candidate patch plus integration plan
  Tests/
    IntentCoverageCoreTests/
    IntentCoverageGeneratorTests/
    Fixtures/                    labeled positive and negative cases
  Examples/TaskFlowDemo/
    Domain/                      shared task model and operations
    App/                         SwiftUI and persistence composition
    Intents/                     adapters to the same domain layer
    TaskFlowUITests/              physical-device functional tests
    TaskFlowIntentTests/          iOS 27 AppIntentsTesting target
  Schemas/
  docs/
```

The structure above is planned, not currently scaffolded. Add an optional semantic-provider target later; keep API clients out of parsing and scoring. Generation should consume the graph and a selected integration binding, never guess a global `TaskService.shared` in an arbitrary app.

A generation binding needs target, domain symbol, dependency construction, argument mapping, entity representation, execution policy, and test fixture contract. If those are unresolved, emit an integration explanation rather than plausible but unbound Swift. Build in an isolated copy before suggesting adoption in an existing project. Keep `.xcresult` artifacts as validation evidence; no unnecessary database or server.

## 10. Smallest proof and competitive reality

The proof remains deliberately small:

1. TaskFlow implements Create, Complete, Delete, Search, and Change Due Date through one reusable domain layer; two App Intents expose Create and Complete.
2. SwiftSyntax discovery proposes five capabilities and maps two, with file/line evidence. A reviewed fixture establishes the denominator.
3. Terminal and JSON agree on 2/5 exposure.
4. Generate Search as a candidate patch calling the existing search operation, returning useful task entities. It must not merely navigate to the search UI.
5. Accept the patch into a disposable copy of the demo target, build, and report 3/5.
6. In the compatible iPhone 12 test lane, seed a unique matching task and unrelated task. Run Search through AppIntentsTesting and assert the result identity; test an absent query too. Run Create and Complete tests before claiming 3/5 validated coverage.
7. Deliberately break Search and show a real test failure without changing the declared coverage count. Restore it and rerun. This proves why validation is a separate measure.

The current machine can support the initial domain/UI, static analysis, build, and older-OS device checks. The AppIntentsTesting part remains blocked by the 26-generation toolchain/runtime until a compatible setup is available. This research has not run any part of the demonstration.

Adjacent projects already overlap the generation and validation idea. IntentCall documents generated Apple wrappers and AppIntentsTesting scaffolds for Dart/Flutter. Axint describes Swift checks, Xcode proof, App Intents generation, and analysis of existing code. These are maintainer-documented capabilities, not independently audited performance results. [IntentCall](https://github.com/Arenukvern/intentcall), [IntentCall platform support](https://github.com/Arenukvern/intentcall/blob/main/docs/start_here/platform_support.mdx), [Axint](https://github.com/agenticempire/axint).

The defensible product hypothesis is a focused, reviewable **capability denominator and its change history** for native Swift apps, connected to tests. Do not claim uniqueness or a moat from generating tests alone. After the five-capability slice succeeds, validate usefulness on a few independently structured apps and measure incorrect suggestions, missed capabilities, and review time before expanding scope.

## First implementation step

Build only the controlled TaskFlow baseline described in [first-implementation-step.md](first-implementation-step.md). Do not start AI classification, generic generation, CI integration, or a broad compiler pipeline in that step.
