# Tilda

Tilda supports Custom HTML via "T123 — HTML / JS / CSS code" block in their Zero Block editor + page-level head injection. No native `/.well-known/*` support.

## Step A — head tags

1. Tilda dashboard → select the project → **Settings** → **More** → **HTML code for HEAD section** (sometimes labeled "Custom HEAD code").
2. Paste from `templates/head-snippet.html` with placeholders replaced.
3. **Save**.
4. **Publish all pages** (Project Settings → Publish All).

The injection applies to every page once published.

**Plan requirement:** Tilda Personal plan or higher. Free trial allows custom HEAD on first project only.

## Step B — verify

```bash
bash scripts/verify_install.sh <domain> <token> --phase head
```

## Step C — final audit

```bash
bash scripts/verify_install.sh <domain> <token>
```

Expected: L1 FAIL, L2-L9 PASS.

## Level-1 upgrade

Tilda → Cloudflare → user's domain → use `cloudflare-worker.md` to proxy `/.well-known/*`. Standard workaround.
