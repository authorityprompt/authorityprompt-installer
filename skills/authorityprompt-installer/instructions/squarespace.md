# Squarespace

Closed CMS — no `/.well-known/*` support. **Level-2 install** (head tags via Code Injection).

## Step A — head tags

1. Squarespace dashboard → **Settings** → **Advanced** → **Code Injection**.
2. In the **Header** field, paste from `templates/head-snippet.html` with placeholders replaced.
3. **Save**.

The change is live immediately — Squarespace doesn't require a publish step.

**Plan requirement:** Code Injection is only available on **Business**, **Commerce Basic**, **Commerce Advanced**, and the legacy **Personal** plan. Squarespace's "Personal (new)" plan introduced in 2022 does NOT include Code Injection. If the user is on the new Personal plan, install is impossible without an upgrade.

## Step B — verify

```bash
bash scripts/verify_install.sh <domain> <token> --phase head
```

Squarespace sometimes adds whitespace or wraps custom code in additional tags — that's fine, the regex in `verify_install.sh` is tolerant.

## Step C — final audit

```bash
bash scripts/verify_install.sh <domain> <token>
```

Expected: L1 FAIL, L2-L9 PASS.

## Per-page override

Code Injection > **Header** applies to every page automatically. The user does NOT need to add it per-page. If they accidentally add it to per-page Code Injection (Settings → Advanced → Page-Level Code Injection), they'll get duplicate tags. Tell them to use the global Header field only.
