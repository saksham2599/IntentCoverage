# Implementation evidence — September 12, 2026

These files are captured outputs from the controlled TaskFlow demonstration, not fabricated example reports.

- `before.json`: five eligible capabilities, Create and Complete exposed (40%).
- `candidate-only.json`: generating candidate files leaves exposure at 40%.
- `after.json`: explicitly accepting Search into the disposable app copy gives 60%.
- `renamed.json`: renaming Search retains 60%, but the baseline gate rejects the identity change.
- `regression-check.txt` and `rename-regression-check.txt`: actual regression output; each command returned exit code 2.
- `swift-tests.txt`: 11 Swift Testing tests passed in two suites.
- `doctor.txt`: local toolchain and framework availability check.
- `iphone12-result.txt`: successful physical UI retry, one workflow test with zero failures.
- `taskflow-iphone12-dark.png`: screenshot from that successful test, visually inspected.

The accepted app compiled successfully with Xcode 26.6 for generic physical iOS. The full disposable run is under `.intentcoverage/demo-20260912T113222270969Z`; its accepted-build.log records BUILD SUCCEEDED. That working copy and full build logs are ignored by Git. Reproduce with `swift build --jobs 2` followed by `python3 scripts/demo.py --build` in a fresh checkout.

Source paths inside reports are relative to the original disposable app. Source locations and digests refer to that run. Terminal evidence has trailing spaces removed for repository hygiene.

See ../../docs/verification.md for physical-device results and the unverified AppIntentsTesting lane. Source coverage is not a system-runtime or Siri pass.
