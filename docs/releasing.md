# Release readiness

The repository is prepared for an open-source **preview**, with explicit limits. MIT licensing does not mean every planned feature is finished. The supported generation adapter is TaskFlow Search; arbitrary-project generation and AppIntentsTesting execution remain unverified.

## Before a source release

1. Run the commands in CONTRIBUTING.md and inspect the GitHub CI result for the exact commit.
2. Review the README, supported toolchain, changelog and verification claims. Preserve the iOS 27 framework limitation until it is independently verified.
3. Check tracked files and the history being published for credentials, personal paths, signing settings and private logs. `scripts/check-repository.py` is a limited pattern and portability check, not a comprehensive secret scanner.
4. Include LICENSE, THIRD_PARTY_NOTICES.md and LICENSES/ in source and binary distributions.
5. Verify private vulnerability reporting is available before advertising it as enabled. SECURITY.md provides a fallback if the GitHub form is unavailable.
6. Tag only a reviewed commit and describe actual supported behavior in the release notes. There is no binary release automation yet.

## Repository visibility

The initial GitHub repository is private by the owner's request. A future public launch is a separate decision. Publish only `main` and reviewed release tags. The local `local-prototype` branch retains the pre-publication history, including personal development configuration, and must not be pushed or merged into the publishable branch. Do not use `git push --all` or `git push --mirror` from that local checkout.

No Apple signing keys, provisioning profiles, personal test stores or device automation credentials belong in this repository or CI.
