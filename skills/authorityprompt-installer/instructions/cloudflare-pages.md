# Cloudflare Pages

Git-based, full Level-1 supported.

> **Recommended pattern**: proxy `/.well-known/authorityprompt.*` to AP's canonical generator via Cloudflare Pages Functions or a Worker bound to your zone. Static copies go stale within 24h as AP regenerates; the proxy stays live forever. See [proxy-pattern.md](./proxy-pattern.md) and [cloudflare-worker.md](./cloudflare-worker.md).

If you need static files instead, continue below.

## Step A — `/.well-known/*` files (static copies)

1. In the user's repo, create `<publish-dir>/.well-known/` (commonly `public/`, `dist/`, `out/`, depending on framework).
2. Copy the 5 AP files in.

### Content-Type fix via `_headers`

Cloudflare Pages reads a `_headers` file at the publish-directory root. Append:

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

## Step B — head tags

Edit framework-appropriate layout (see `vercel.md` framework matrix).

> **SSR pitfall**: do not use `next/script` with `strategy="afterInteractive"`, or any framework "Script" helper that lazy-injects after hydration. The `<script src=…>` tag must appear in the SSR'd HTML so AP's install detector and AI crawlers see it. See [vercel.md → SSR pitfall](./vercel.md#ssr-pitfall--the-most-common-install-mistake). Use a plain `<script async>` in `<head>`.

## Step C — commit + push

```bash
git add public/.well-known _headers <head-modified-file>
git commit -m "feat: install AuthorityPrompt"
git push
```

Cloudflare Pages auto-deploys.

## Step D — verify

```bash
bash scripts/verify_install.sh <domain> <token>
```

Expect all PASS.

## Bonus — also use a Worker for non-Pages domains

If the same Cloudflare account hosts both Pages sites and Worker-routed sites, the same `cloudflare-worker.md` Worker can cover both with one deploy.
