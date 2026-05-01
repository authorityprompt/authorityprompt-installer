# Carrd

Carrd is a simple one-page site builder. Closed managed CMS — no `/.well-known/*` support.

**Install path: Level-2 head tags only**, requires the **Carrd Pro** plan ($19/year+) since custom HTML is a Pro feature.

## Step A — head tags (Pro plan only)

1. Carrd Editor → **+ Add Element** → **Embed**.
2. **Type**: **Code**.
3. **Style**: **Hidden**.
4. **Code**: paste `templates/head-snippet.html` with placeholders replaced.
5. **Method**: select **Head**.
6. Save.
7. **Publish**.

## Step B — verify

```bash
bash scripts/verify_install.sh <domain> <token> --phase head
bash scripts/verify_install.sh <domain> <token>
```

Expected: L1 FAIL (Carrd cannot serve custom files), L2-L9 PASS.

## Free tier

If the user is on Carrd Free, custom HTML embeds are not available. Install is impossible without the Pro upgrade. Tell them upfront.

## If user really needs Level-1

Put Cloudflare in front of their Carrd domain and follow `cloudflare-worker.md`. Cloudflare can serve `/.well-known/*` even though Carrd cannot.
