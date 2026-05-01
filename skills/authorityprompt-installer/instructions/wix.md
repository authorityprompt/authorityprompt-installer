# Wix

Wix is a closed managed CMS. Custom paths (including `/.well-known/*`) are not supported. **Level-2 install only** (head tags via Wix Custom Code).

## Step A — head tags

1. Wix Editor → top menu **Settings** (or in the dashboard sidebar).
2. **Advanced** → **Custom Code** (in newer Wix UI: **Marketing & SEO** → **Custom Code**).
3. Click **+ Add Custom Code**.
4. Paste from `templates/head-snippet.html` with placeholders replaced.
5. **Name**: "AuthorityPrompt"
6. **Add Code to Pages**: select **All pages** → **Load code on each new page**.
7. **Place Code in**: select **Head**.
8. Click **Apply**.
9. **Publish** the site (top-right "Publish" button).

Wix processes Custom Code asynchronously after publish — give it 30-60 seconds before verifying.

## Step B — verify

```bash
bash scripts/verify_install.sh <domain> <token> --phase head
```

Wix sometimes emits Custom Code into the body rather than head depending on plan tier. If the `<meta>` and `<link>` aren't visible in HEAD, re-check the "Place Code in" setting was set to **Head**, not **Body — End**.

## Step C — final audit

```bash
bash scripts/verify_install.sh <domain> <token>
```

Expected: L1 FAIL, L2-L9 PASS. Wix users cannot serve `/.well-known/*` files; this is a known platform limitation. The canonical profile on AuthorityPrompt is the source of truth, the backlink takes crawlers there.

## Wix-specific gotcha

Wix Free plan does NOT include Custom Code — the user needs at least the **Combo** plan or higher. If they're on Free, the install is impossible without an upgrade. Tell them this directly so they don't spend an hour clicking around.
