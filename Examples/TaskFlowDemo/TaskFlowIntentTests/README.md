# AppIntentsTesting lane

The baseline builds with Xcode 26.6. It deliberately does not compile this directory into the app or normal UI test target.

Generate Search using the CLI or `scripts/demo.py`. The candidate includes `TaskFlowIntentTests.swift`, a separate UI integration test for iOS 27. Add that source here in your accepted demo copy, then run `scripts/create-xcode-project.py --root /path/to/copy --with-app-intents-testing --team YOUR_TEAM_ID` with Xcode 27 selected.

Run `TaskFlowIntentTests` on the physical iPhone 12 with iOS 27 or newer. No AppIntentsTesting pass has been recorded on the current iOS 26.6.1 phone.
