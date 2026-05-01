# Shopify

Shopify supports both vectors: head tags via theme.liquid edit, and `.well-known/*` files via Files (with a workaround).

## Step A — head tags (Level-2 baseline)

1. Shopify Admin → **Online Store** → **Themes**.
2. Find the active theme → **Actions** dropdown → **Edit code**.
3. In the file tree, open `layout/theme.liquid`.
4. Find the `<head>` tag (near the top of the file).
5. Just before `</head>`, paste from `templates/head-snippet.html` with placeholders replaced.
6. **Save**.

The change is live immediately on the storefront.

## Step B — `/.well-known/*` files (Level-1 upgrade, optional)

Shopify's `/.well-known/` requires a workaround because Shopify's CDN normalizes paths. The cleanest solution is a Shopify App Proxy or a wildcard redirect rule. Most users skip this step.

### If user wants Level-1, the path is:

1. **Online Store** → **Pages** → **Add page**.
2. Title: `authorityprompt-jsonld` (Shopify will generate URL `/pages/authorityprompt-jsonld`)
3. In the page Content editor, switch to HTML view (`<>`)
4. Paste the contents of `authorityprompt.jsonld`.
5. Repeat for the other 4 files.
6. Use **App Proxy** or a **Cloudflare Worker** in front to rewrite `/.well-known/authorityprompt.jsonld` → `/pages/authorityprompt-jsonld`.

This is fragile and adds load. **Recommendation:** stick with Level-2 — head tags only — unless the user has a strong reason for Level-1.

## Step C — verify

```bash
bash scripts/verify_install.sh <domain> <token> --phase head
bash scripts/verify_install.sh <domain> <token>
```

Level-2 expectation: L1 FAIL, L2-L9 PASS.

## Multi-theme caveat

If the merchant has multiple themes (production + draft), the head tags must be added to **the published theme**. If they later switch published themes, the install resets — instruct them to remember and re-run this step on theme swap, or to add it to ALL their themes upfront.
