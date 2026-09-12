# Contributing

IntentCoverage is an early, deliberately scoped Swift developer tool. Before a large change, open an issue explaining the capability, an actual Swift example, and how correctness can be evaluated independently of the scanner.

## Local checks

Use macOS with Xcode 26.6 / Swift 6.3.3 (the tested baseline), Python 3.10+, and Git. SwiftSyntax is pinned in Package.resolved. The first build requires internet access to fetch it.

```sh
swift test --jobs 2
python3 scripts/check-repository.py
python3 scripts/demo.py --binary .build/debug/intentcoverage --build
git diff --check
```

The demo performs source analysis, candidate generation, explicit acceptance into a temporary copy, regression checks, and an unsigned generic physical-iOS build. CI runs these Mac-side checks. It never creates or runs an iOS simulator. Physical UI tests require an attached iPhone and your own signing configuration; this project's recorded device evidence is from an iPhone 12.

For device work, change `bundleIdentifier` in the example's `.intentcoverage-generation.json` to an identifier you control, regenerate with `python3 scripts/create-xcode-project.py --team YOUR_TEAM_ID`, then choose your physical iPhone in Xcode. Do not commit your team ID, provisioning assets, test-store data, or personal bundle configuration. Regenerate with no `--team` and restore the generic binding before submitting changes. Changes to the binding must also be reflected when generating new integration-test candidates.

## Review expectations

- Keep source exposure, runtime validation, and Siri experience distinct.
- Add focused fixtures for parser changes, particularly false positives and ambiguous declarations. Do not teach the scanner its expected answers through configuration.
- Keep generated code outside scanned source roots until explicit acceptance.
- Preserve existing user data and avoid network calls during analysis.
- Record actual checks and limitations in the pull request. No passing claims from unrun or simulated framework tests.
- The iOS 27 AppIntentsTesting lane remains unverified. Do not remove that limitation without real SDK and physical runtime evidence.

Submit small pull requests against `main`. Include the problem, resulting behavior, verification performed, and any compatibility impact. Contributions are provided under the repository's MIT license; third-party material retains its own license.

CI selects Xcode 26.6 on GitHub's `macos-26` runner, following the [official runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md). Runner images evolve; update the pinned Xcode path deliberately and recheck the toolchain when upgrading.
