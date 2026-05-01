# Notion (incl. Super.so / Potion / Fruition)

Plain Notion-published pages do NOT allow custom HTML or paths. The user has 3 options:

## Option 1 — Super.so (recommended for Notion-as-website users)

Super.so is a paid wrapper that turns Notion pages into real websites with custom domains and head injection.

1. Super.so dashboard → Site → **Settings** → **Custom code** → **Custom HEAD**.
2. Paste from `templates/head-snippet.html` with placeholders replaced.
3. Save → publish.

**Plan requirement:** Custom HEAD is on Super.so paid plans only.

`/.well-known/*` not supported on Super.so without Cloudflare in front.

## Option 2 — Potion (Notion-as-website wrapper)

Same pattern: Potion → Site Settings → **Custom Code** → **Head**. Paste snippet.

## Option 3 — Notion Pages directly

Notion's native publishing (notion.site/...) does NOT support custom code or paths. If the user is publishing this way, **AuthorityPrompt cannot be installed** — the canonical profile lives only on AuthorityPrompt's side, but the user has no way to put a `<meta verification>` tag.

Tell the user: either move to a Notion wrapper (Super.so, Potion, Fruition) or use a custom domain pointed at a real CMS.

## Step B — verify (Super.so / Potion only)

```bash
bash scripts/verify_install.sh <domain> <token> --phase head
bash scripts/verify_install.sh <domain> <token>
```

Expected: L1 FAIL, L2-L9 PASS.

## Level-1 upgrade

Cloudflare in front of the Notion-wrapped domain → see `cloudflare-worker.md`.
