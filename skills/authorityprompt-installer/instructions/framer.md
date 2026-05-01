# Framer

Framer (the website builder, framer.com) — closed CMS, no `/.well-known/*`. **Level-2 install** via Custom Code panel.

## Step A — head tags

1. Framer dashboard → open the site project.
2. **Site Settings** (gear icon) → **General** tab → scroll to **Custom Code**.
3. Field: **Start of `<head>` tag**.
4. Paste from `templates/head-snippet.html` with placeholders replaced.
5. **Save**.
6. **Publish** (top-right "Publish" button).

## Step B — verify

```bash
bash scripts/verify_install.sh <domain> <token> --phase head
bash scripts/verify_install.sh <domain> <token>
```

Expected: L1 FAIL, L2-L9 PASS.

## Plan requirement

Custom Code is only available on **Pro** and **Enterprise** Framer plans. Free and Mini plans do NOT support custom HTML in head. If user is on those, install is impossible without an upgrade.

## Level-1 upgrade

Framer → Cloudflare proxy → see `cloudflare-worker.md`.
