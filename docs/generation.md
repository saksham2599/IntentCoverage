# Generation contract

V1 generates one reviewed adapter: TaskFlow's Search Tasks. It reuses `TaskRepository.shared.searchTasks(query:)` and returns `[TaskEntity]`. It is intentionally not an arbitrary-project code generator.

The example's `.intentcoverage-generation.json` identifies the adapter, bundle ID, and SHA-256 digests of the reviewed domain/entity source. If either file changes, generation stops. Review compatibility before updating those digests. A missing binding produces an actionable explanation.

The command writes a new candidate directory containing an intent, a separate AppIntentsTesting test, and review instructions. It refuses existing output directories and locations inside selected source roots. No existing app source is rewritten.

`scripts/demo.py` is an explicit acceptance workflow for a new disposable copy of the demo. It verifies 40%, generates candidates, verifies coverage is still 40%, copies Search into that copy's Intents directory, then verifies 60%. It also removes the accepted intent temporarily to check that baseline regression detection exits with code 2, and restores it.

The generated integration test requires a separate iOS 27 UI test target. It launches TaskFlow with a UUID-scoped test store, creates two tasks, completes one, and checks matching and absent searches through AppIntentsTesting. It has not been compiled or run with Xcode 27 in this environment. Keep that statement until compatible SDK/device evidence exists.

To configure that future target after generating and accepting the test source:

```sh
python3 scripts/create-xcode-project.py --root /absolute/path/to/demo-copy --with-app-intents-testing --team YOUR_TEAM_ID
```

Run its `TaskFlowIntentTests` scheme only on the physical iPhone 12 running iOS 27 or newer. Keep the normal app's minimum deployment target at iOS 17.
