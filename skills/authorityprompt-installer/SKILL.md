---
name: authorityprompt-installer
description: Use this skill when the user wants to install the AuthorityPrompt AI-visibility stack on their website without a sysadmin. Triggers on phrases like "install authorityprompt", "set up AP files", "deploy authorityprompt to my site", "make my site AI-readable", or after the user downloads the AuthorityPrompt ZIP from authorityprompt.com. The skill detects the user's hosting platform via HTTP fingerprinting, walks through platform-specific manual or scripted steps, verifies each step with curl probes, and runs a final 14-layer canonical-AI-profile audit (38 checks, full AP-side parity). Pre-conditions you should ask the user for if not provided — (1) the public domain of the site, (2) the local path to the downloaded `authorityprompt-<domain>` folder containing the 5 static files and authorityprompt.js, (3) the verification token (visible in the AP dashboard or in their downloaded README). Skill is non-destructive — read-only audits unless the user explicitly approves a deploy step.
allowed-tools: Read Write Edit Bash WebFetch
---

# AuthorityPrompt Installer

You are guiding a non-technical website owner to install the **AuthorityPrompt** stack on their site so that AI search engines (ChatGPT search, Perplexity, Claude, Gemini) can read their canonical company profile.

## What "installed" means — the success criteria

After this skill runs to completion, every one of the following must be true on the user's site:

1. **Six** files served on the user's domain with correct `Content-Type`:
   - `https://{domain}/.well-known/authorityprompt.{jsonld,yaml,md,txt,html}` (5 files)
   - `https://{domain}/js/authorityprompt.js` (AP's "Option 2" path — even if you use Option 1 in `<head>`, AP's installation detector independently probes this path and reports `js:NOT_FOUND` if absent. Easy fix: proxy via the same pattern as `/.well-known/*`)
2. One script tag in `<head>` of every page (Option 1 — recommended):
   `<script src="https://authorityprompt.com/api/ingest-generator/company/{domain}/authorityprompt.js" async></script>`
3. One verification meta tag in `<head>`: `<meta name="authorityprompt-verification" content="{token}">`
4. One backlink in `<head>`: `<link rel="ai-profile" href="https://authorityprompt.com/company/{domain}">`
5. The audit script in `scripts/verify_install.sh` exits with `EXIT_SUCCESS`. The full audit covers 14 layers including AP-side parity (mirrors AP's own validation: `bot_tracker_ready`, `client_files`, `format_api_*`, `manifest_alias`, `manifest_json`, `manifest_layers`, `sitemap_presence`, `ssr_meta`, `ssr_page`).

## Required inputs — ask the user up front

Before doing anything else, gather these. Ask in plain language, one item at a time, only if missing.

| Variable | Source | Example |
|---|---|---|
| `DOMAIN` | The user's public hostname | `example.com` |
| `AP_FILES_DIR` | Local path to the `authorityprompt-<domain>` folder they downloaded from authorityprompt.com | `~/Downloads/authorityprompt-example/` |
| `VERIFICATION_TOKEN` | Token shown in their AP dashboard or printed in the downloaded README | `274771` |

Confirm the bundle is intact: the directory must contain `authorityprompt.jsonld`, `authorityprompt.yaml`, `authorityprompt.md`, `authorityprompt.txt`, `authorityprompt.html`, and `authorityprompt.js` (all six required — the `.js` is needed because AP's installation detector probes `/js/authorityprompt.js` even when the user follows Option 1 with a remote `<script src=…authorityprompt.com…>` in `<head>`). The `README.md` is informational. If any of the six files is missing, stop and tell the user to re-download from `https://authorityprompt.com/dashboard`.

## Phase 1 — Detect hosting platform

Run the detection script:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/authorityprompt-installer/scripts/detect_hosting.sh "$DOMAIN"
```

The script returns one of: `wordpress`, `webflow`, `wix`, `squarespace`, `shopify`, `ghost`, `vercel`, `netlify`, `cloudflare-pages`, `github-pages`, `carrd`, `tilda`, `framer`, `notion`, `bitrix`, `apache`, `nginx-vps`, `unknown`.

Then load the matching instruction file from `instructions/<platform>.md` (or `instructions/generic.md` if `unknown`). Read it fully before talking to the user.

## Phase 2 — Walk the user through the installation

Use a `TodoWrite` checklist with these standard items, adapted per platform:

1. Upload 5 static files to `/.well-known/`
2. Add the `<script>` tag to every page's `<head>`
3. Add the `<meta authorityprompt-verification>` tag
4. Add the `<link rel="ai-profile">` tag
5. Run verification

Mark each item `in_progress` BEFORE the user starts the corresponding manual step. After they confirm completion of a step, run the relevant partial check from `scripts/verify_install.sh` (it accepts a `--phase` flag) and mark `completed` only on PASS. On FAIL, show the exact `curl` output and ask the user to recheck.

**Critical rule:** never mark a step `completed` unless its verification probe passes against the live site.

### When the platform cannot serve `/.well-known/*` files (Wix, Squarespace, Carrd, Notion, etc.)

Stop, explain to the user that this hosting can't serve `/.well-known/*` files, and offer the **fallback path**: install only the head tags (script + verification meta + backlink). The canonical profile still works — AI crawlers will fetch it from `authorityprompt.com/company/{domain}` directly, since the backlink tells them where to look. Tell them this is a Level-2 install instead of Level-1, and document this as a known limitation. Skip steps 1 and proceed with 2-5.

### When the platform supports SSH/SFTP/Git deploy (custom VPS, Vercel, Netlify, GitHub Pages, self-hosted WordPress with FTP)

Offer to run `scripts/ssh_deploy.sh` to push files automatically — but only if the user explicitly grants permission and provides credentials. Never assume; never store credentials.

## Phase 3 — Final audit

Run the full audit:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/authorityprompt-installer/scripts/verify_install.sh "$DOMAIN" "$VERIFICATION_TOKEN"
```

Print the result table to the user with per-layer PASS/FAIL. If the script exits 0 — congratulate the user, give them the dashboard URL `https://authorityprompt.com/company/{domain}`, and tell them their AI-readable profile is live. If it exits non-zero — show the FAILED layers and give specific remediation pointers.

## Output style

- Concise. One line per status update. No filler.
- When showing the user a code snippet to paste, wrap it in a clear block with the **exact label of where to paste it** (e.g. "Settings → Custom Code → Head").
- After every verification step, print the curl output so the user sees what's actually happening.
- At the end, print a one-screen summary: PASS/FAIL count, the live profile URL, and 3 next-step suggestions (e.g. "Submit to Google Search Console", "Wait 4-8 weeks for AI crawlers to ingest", "Run a canary test to confirm AI ingestion").

## Files inside this skill

- `scripts/detect_hosting.sh` — HTTP-fingerprint detection of the user's hosting platform.
- `scripts/verify_install.sh` — 14-layer canonical-AI-profile audit, 38 distinct checks (also exposes `--phase {files,head,profile}`). Auto-detects Level-2 installs (closed CMS) and exits with `Level-2 PASS` instead of a generic FAIL when only L1 fails.
- `scripts/ssh_deploy.sh` — optional SFTP/SSH file uploader for users with shell access.
- `instructions/<platform>.md` — per-platform step-by-step. Always load the matching one before guiding.
- `templates/head-snippet.html` — the three head tags to paste.
- `templates/htaccess.conf` — Apache rewrite rules for shared hosting that won't serve `/.well-known/*` by default.

## What this skill is not

- Not a replacement for the AuthorityPrompt dashboard. The user must register at `authorityprompt.com` and download files from there first.
- Not a deploy tool — it does not push files unless the user explicitly authorizes `ssh_deploy.sh`.
- Not platform-specific automation — for closed CMS like Wix/Squarespace, the user clicks through their admin UI; the skill provides exact instructions and verifies the result.
