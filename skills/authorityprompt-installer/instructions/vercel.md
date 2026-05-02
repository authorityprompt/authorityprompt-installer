# Vercel

Vercel sites are Git-based. Both vectors install via committing files and redeploying. Full Level-1 install is supported.

> **Recommended pattern**: instead of copying static files, **proxy `/.well-known/authorityprompt.*` directly to AuthorityPrompt's canonical generator** via Next.js `rewrites`. This eliminates stale-files drift (AP regenerates the profile every ~24h; static copies go stale otherwise) and removes the need for redeploy on every AP refresh. See [proxy-pattern.md](./proxy-pattern.md) for the full Next.js config — it's typically the right call for any Vercel deploy.

If you need static files anyway (e.g. air-gapped audit, regulatory snapshot), continue with Step A below.

## Step A — `/.well-known/*` files (static copies)

1. Open the user's Git repo locally (or in Vercel's online editor).
2. Inside the project, create directory `public/.well-known/` (Next.js, Astro, SvelteKit, Remix, Nuxt, Vite-based) — adjust path if their framework uses a different static dir.
3. Copy the 5 profile files (`authorityprompt.{jsonld,yaml,md,txt,html}`) from `~/Downloads/authorityprompt-<domain>/` into `public/.well-known/`.
4. **Also required** — copy `authorityprompt.js` from the same bundle to `public/js/authorityprompt.js` (create the `public/js/` subdirectory if missing). AuthorityPrompt's installation detector probes this Option-2 path independently and reports `js:NOT_FOUND` if absent — even when you use Option 1 (remote `<script src=…authorityprompt.com…>`).

### Content-Type fix (Vercel-specific)

Vercel's static file handler infers MIME by extension and gets `.jsonld` / `.yaml` / `.md` wrong. Add or extend `vercel.json` at the repo root:

```json
{
  "headers": [
    {
      "source": "/.well-known/authorityprompt.jsonld",
      "headers": [{ "key": "Content-Type", "value": "application/ld+json; charset=utf-8" }]
    },
    {
      "source": "/.well-known/authorityprompt.yaml",
      "headers": [{ "key": "Content-Type", "value": "application/yaml; charset=utf-8" }]
    },
    {
      "source": "/.well-known/authorityprompt.md",
      "headers": [{ "key": "Content-Type", "value": "text/markdown; charset=utf-8" }]
    },
    {
      "source": "/.well-known/authorityprompt.txt",
      "headers": [{ "key": "Content-Type", "value": "text/plain; charset=utf-8" }]
    },
    {
      "source": "/.well-known/authorityprompt.html",
      "headers": [{ "key": "Content-Type", "value": "text/html; charset=utf-8" }]
    }
  ]
}
```

If the project is Next.js, the same rules can go in `next.config.js`'s `headers()` instead — equivalent effect.

## Step B — head tags

Add to the root layout / template:

- **Next.js (app router)**: `app/layout.tsx` — add `<meta>`, `<link>`, and the AP `<script>` directly inside the `<head>` JSX element. **Do NOT use `next/script` with `strategy="afterInteractive"`** — that strategy injects the script into the DOM only after client-side React hydration, so the `<script src=…>` tag is *missing from the SSR'd HTML*. AuthorityPrompt's install detector and most AI crawlers read raw HTML without executing JS, so they will not see the script and will report "not installed" even though browsers load it fine. Use a plain `<script async>` element instead.
- **Next.js (pages router)**: `pages/_document.tsx` `<Head>` (renders into SSR HTML; safe).
- **Astro**: shared `Layout.astro` component, inside the `<head>` block.
- **SvelteKit**: `src/app.html` (SSR'd template, safe).
- **Remix**: `app/root.tsx` `<head>`.
- **Vue/Nuxt**: `app.vue` or `nuxt.config.ts` head section, using `script: [{ src: '…', async: true }]`.
- **Static HTML**: every page's `<head>`.

Snippet to paste (substitute `{{DOMAIN}}` and `{{TOKEN}}`):

```html
<meta name="authorityprompt-verification" content="{{TOKEN}}">
<link rel="ai-profile" href="https://authorityprompt.com/company/{{DOMAIN}}">
<script src="https://authorityprompt.com/api/ingest-generator/company/{{DOMAIN}}/authorityprompt.js" async></script>
```

### SSR pitfall — the most common install mistake

Across React / Vue / Svelte SSR frameworks, the typical mistake is using a framework-provided "Script" component with the default lazy-load strategy. Examples that produce a *broken* install (script URL in hydration data, no real `<script>` tag in SSR HTML):

```tsx
// ❌ Next.js — appears in DOM only after hydration
import Script from 'next/script';
<Script src="…/authorityprompt.js" strategy="afterInteractive" />
```

The fix is always the same: render a plain `<script>` element in the SSR'd `<head>`. The `verify_install.sh` audit catches this — if you see "AP URL found but NOT as a real `<script>` tag", this is the bug.

## Step C — commit + redeploy

```bash
git add public/.well-known vercel.json <head-modified-file>
git commit -m "feat: install AuthorityPrompt AI-readable profile"
git push
```

Vercel auto-deploys on push. Wait for the deploy to finish (~30-90s).

## Step D — verify

```bash
bash scripts/verify_install.sh <domain> <token>
```

Expect all PASS. Reference implementation pattern: `next.config.ts` `headers()` rules per file, `app/layout.tsx` head tags, AP files in `public/.well-known/`.
