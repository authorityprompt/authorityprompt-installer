# Netlify

Same pattern as Vercel — Git-based, full Level-1 supported.

> **Recommended pattern**: proxy `/.well-known/authorityprompt.*` to AP's canonical generator instead of shipping static copies. Netlify supports this via `_redirects` or `netlify.toml` `[[redirects]]` with `status = 200` (rewrite-not-redirect). See [proxy-pattern.md](./proxy-pattern.md) for the full config — eliminates stale-files drift.

If you need static files instead, continue below.

## Step A — `/.well-known/*` files (static copies)

1. In the repo, create `<publish-dir>/.well-known/` (commonly `public/`, `dist/`, or whatever's set as Build → Publish directory in Netlify).
2. Copy all 5 AP files into it.

### Content-Type fix via `_headers` file

Netlify uses a plain-text `_headers` file at the publish directory root. Append:

```
/.well-known/authorityprompt.jsonld
  Content-Type: application/ld+json; charset=utf-8

/.well-known/authorityprompt.yaml
  Content-Type: application/yaml; charset=utf-8

/.well-known/authorityprompt.md
  Content-Type: text/markdown; charset=utf-8

/.well-known/authorityprompt.txt
  Content-Type: text/plain; charset=utf-8

/.well-known/authorityprompt.html
  Content-Type: text/html; charset=utf-8
```

Or equivalently in `netlify.toml` at repo root:

```toml
[[headers]]
  for = "/.well-known/authorityprompt.jsonld"
  [headers.values]
    Content-Type = "application/ld+json; charset=utf-8"

[[headers]]
  for = "/.well-known/authorityprompt.yaml"
  [headers.values]
    Content-Type = "application/yaml; charset=utf-8"

# (etc for the other 3)
```

## Step B — head tags

Same as Vercel — add to root layout/template of whatever framework. For static HTML sites, add to every page's `<head>`.

> **SSR pitfall**: do not use `next/script` with `strategy="afterInteractive"`, or any framework "Script" helper that injects client-side after hydration. The `<script src=…>` tag must appear in the SSR'd HTML, not just in hydration data. See [vercel.md → SSR pitfall](./vercel.md#ssr-pitfall--the-most-common-install-mistake) for full explanation. Use a plain `<script async>` in `<head>`.

## Step C — commit + push

```bash
git add public/.well-known _headers
git commit -m "feat: install AuthorityPrompt"
git push
```

Netlify auto-deploys.

## Step D — verify

```bash
bash scripts/verify_install.sh <domain> <token>
```
