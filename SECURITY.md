# Security

Only the current `main` branch receives fixes during this pre-release stage. IntentCoverage reads local Swift source and writes reports and candidate files; it should not upload source or credentials.

Report security problems privately using [GitHub private vulnerability reporting](https://github.com/saksham2599/IntentCoverage/security/advisories/new). If that form is unavailable, open a minimal issue asking for a private reporting channel without disclosing the vulnerability. Never include credentials, private source, signing assets, device identifiers, or exploit details in a public issue.

Useful reports identify the affected commit, a minimal sanitized reproduction, impact, and expected behavior. No response-time guarantee or bounty is currently offered.

Generated code requires review. Source coverage is a heuristic for a controlled subset of Swift and is not a security certification or proof that an intent is safe to expose.
