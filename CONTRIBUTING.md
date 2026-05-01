# Contributing to AuthorityPrompt Installer

Thanks for the interest. This plugin's value is the breadth of hosting platforms it covers and the precision of each platform's instructions. The two highest-leverage ways to contribute are:

1. **A new platform's `instructions/<platform>.md`** when you've installed AP on a host we don't yet document.
2. **A bug fix in `verify_install.sh` or `detect_hosting.sh`** when the audit gives a wrong PASS or wrong FAIL.

## Repository layout

```
.claude-plugin/             ← marketplace + plugin manifests
skills/authorityprompt-installer/
├── SKILL.md                ← main entry, decision tree
├── scripts/                ← bash: detection, audit, optional deploy
├── instructions/           ← per-platform install guides (one .md per host)
└── templates/              ← head-snippet.html, htaccess.conf
```

A new platform is one PR: add `instructions/<your-platform>.md`, extend the matching pattern in `scripts/detect_hosting.sh`, run `bash scripts/verify_install.sh <a-test-domain> <token>` to confirm the audit logic still applies.

## Adding a new platform

1. **Detect.** Add a fingerprint to `scripts/detect_hosting.sh` — typically a header (`Server`, `X-Powered-By`), a `<meta generator>` value, or a static asset path unique to that hosting. Place new branches *before* the generic Apache/nginx fallbacks.

2. **Document.** Create `instructions/<platform>.md` following the structure used by existing files:
   - Step A — `/.well-known/*` files (or "not supported on this hosting" with a clear reason)
   - Step B — head tags (every platform allows this in some form; document the exact admin-UI path)
   - Step C — verify with `bash scripts/verify_install.sh <domain> <token>`
   - Note any plan-tier requirements, gotchas, edge cases

3. **Test.** Install on a real site of that hosting, run the audit, paste the output into the PR description.

4. **Reference.** Add the platform to the "Supported platforms" table in `README.md`.

## Bug fixes in the audit / detection scripts

The audit must hold an invariant: a fully-installed reference site should produce **0 fails** in `verify_install.sh`. If you find a layer that flakes (passes intermittently, fails on byte-exact data, etc.), open an issue first with:

- The full `verify_install.sh` output (with `2>&1 | sed 's/\x1b\[[0-9;]*m//g'` to strip color)
- The raw `manifest.json` and any failing format file
- Your OS + bash version (`bash --version`)

Most flakes are byte-handling or platform-binary issues (BSD vs GNU `date`, missing `python3-yaml`, locale). The `scripts/verify_install.sh` aims to use only POSIX-portable constructs — keep PRs in that spirit.

## Pull request flow

1. Fork, branch off `main`.
2. Commits should be small and self-explanatory; conventional commits welcome (`feat: …`, `fix: …`, `docs: …`).
3. Run the full audit against any reference site you have access to and include the **last 15 lines of output** in the PR description.
4. Update `README.md` if you added or changed anything user-visible.

## Issue triage

- **`detect_hosting.sh` returns `unknown` on a real platform** → bug, please open with HTTP headers + first 1KB of HTML from the site (no PII).
- **`verify_install.sh` reports a wrong FAIL on a verified install** → bug, paste full output.
- **A platform fundamentally cannot serve `/.well-known/*` or head tags** → not a bug — document it as a known limitation in the matching `instructions/<platform>.md`.
- **AuthorityPrompt-side endpoint changes** (e.g. they add a new format) → upstream issue, we adapt the audit script when behavior stabilizes.

## License

By contributing you agree your contributions are licensed under MIT (the same as the project).
