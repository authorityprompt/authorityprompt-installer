# Webflow

Webflow doesn't natively serve files at custom paths like `/.well-known/*`. The standard install is Level-2 (head tags only) — the canonical AI profile lives on AuthorityPrompt, and the backlink takes care of discovery.

If the user really needs Level-1 (5 profile files + `/js/authorityprompt.js` served from their domain), the only path is to put the site behind a Cloudflare Worker — see `cloudflare-worker.md`. Otherwise this is the install:

## Step A — add the 3 head tags (Site-wide)

1. Webflow Designer → click **Project Settings** (gear icon, top-left).
2. **Custom Code** tab.
3. **Head Code** field.
4. Paste from `templates/head-snippet.html` with placeholders replaced.
5. **Save Changes** at the top right.
6. **Publish** the site (top-right "Publish" button → publish to your custom domain).

The head code applies to every page on the site after publish.

## Step B — verify

```bash
bash scripts/verify_install.sh <domain> <token> --phase head
```

Expect 3/3 PASS for the head check. The `--phase files` check will FAIL on Webflow — that's expected.

## Step C — final audit

```bash
bash scripts/verify_install.sh <domain> <token>
```

Expected: L1 (.well-known files) FAIL, L2-L9 PASS. Explain to the user that Webflow's hosting model doesn't allow custom paths under `/.well-known/`. AuthorityPrompt's official backlink approach (`<link rel="ai-profile">`) is recognized by AI crawlers and is the supported install path on Webflow.

## Optional Level-1 upgrade — Cloudflare Worker

If the user has Cloudflare in front of their Webflow site, deploy a Worker that:
- Intercepts `/.well-known/authorityprompt.*` requests
- Proxies them to `https://authorityprompt.com/company/<domain>/authorityprompt.*`

See `cloudflare-worker.md` for the Worker code.
