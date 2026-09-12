# First implementation step — a trustworthy TaskFlow baseline

> Historical Phase 0 plan. The baseline and controlled CLI slice are now implemented; see [verification.md](verification.md) for current evidence. File organization below records the original proposal.

## Objective

Create one small SwiftUI iPhone app with five independently specified task capabilities and exactly two production App Intents. This is the next implementation step; the files listed below do not exist yet.

## Why

The analyzer needs a real app with known behavior to measure. A percentage printed from a hand-authored manifest would not demonstrate discovery. A reusable domain layer also gives generated intents a real operation to call later.

## Implementation

Create `Examples/TaskFlowDemo/TaskFlowDemo.xcodeproj` with an iOS 17+ application target and physical-device test target. Keep the optional iOS 27 intent integration test target separate so the baseline continues to build with Xcode 26.6.

Planned source files:

| File | Responsibility |
| --- | --- |
| `Domain/TaskRecord.swift` | Stable UUID, title, completion flag, optional due date |
| `Domain/TaskRepository.swift` | Async reusable create, complete, delete, search, and reschedule operations |
| `App/TaskFlowApp.swift` | Composition and persistent store selection |
| `App/TaskListView.swift` | Five visible user actions connected to those operations |
| `Intents/TaskEntity.swift` | Stable entity identity and query resolution |
| `Intents/CreateTaskIntent.swift` | Call repository create; return created task entity |
| `Intents/CompleteTaskIntent.swift` | Resolve selected task and call repository complete |
| `Intents/TaskFlowShortcuts.swift` | Curated shortcut presentation for those two intents |
| `TaskFlowUITests/TaskFlowBaselineTests.swift` | Five behaviors using isolated test data on iPhone 12 |

Use one actor-isolated repository with injected storage URL, shared by UI and intent adapters. A simple atomically saved Codable file is enough for this app; do not add cloud synchronization or a backend. Define how the intent obtains the repository in the app process. Keep extensions out of this slice to avoid introducing multi-process storage coordination.

Freeze the behavior contract before writing implementation:

- Create rejects a whitespace-only title and creates a persistent ID for valid input.
- Complete sets a selected task to complete; repeating it remains safe.
- Delete removes one selected task after UI confirmation; a missing ID yields a defined error.
- Search returns matching task records with stable ordering; define case-insensitive matching and empty-query behavior explicitly.
- Change Due Date sets or clears the selected task's date while preserving other fields.

Define a separate evaluation fixture listing those five outcomes and the expected two initial intent mappings. The future scanner must derive evidence from app source, then compare its output with this fixture in tests; it must not read the answer fixture as discovery input.

## Expected result

A usable TaskFlow app on the physical iPhone 12, five working UI actions, and two inspectable App Intents invoking the same domain operations. **The expected eventual source coverage is 2/5; no automated coverage claim exists at this step.**

## Verify

Build the baseline for the physical iPhone 12 using its freshly discovered identifier. Reserve the shared device lock before install/launch/testing. Exercise all five flows with a dedicated test store, including persistence after relaunch. Verify Create and Complete in Shortcuts; record Siri interaction separately if performed.

Do not call a direct `perform()` unit test an AppIntentsTesting result. On the current iOS 26.6.1 phone, record that framework lane as unavailable. No simulator, phone update, or Xcode replacement is required to complete the baseline step.

Keep screenshots, build identity, and actual test results with the example. The next step begins only once this behavior and reusable architecture are established: deterministic discovery of existing intent declarations.
