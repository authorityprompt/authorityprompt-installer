# Vercel

Vercel sites are Git-based. Both vectors install via committing files and redeploying. Full Level-1 install is supported.

## Step A — `/.well-known/*` files

1. Open the user's Git repo locally (or in Vercel's online editor).
2. Inside the project, create directory `public/.well-known/` (Next.js, Astro, SvelteKit, Remix, Nuxt, Vite-based) — adjust path if their framework uses a different static dir.
3. Copy the 5 files from `~/Downloads/authorityprompt-<domain>/` into `public/.well-known/`.

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

- **Next.js (app router)**: `app/layout.tsx` — add `<meta>`, `<link>`, `<Script>` (use `next/script` with `strategy="afterInteractive"` for the AP script).
- **Next.js (pages router)**: `pages/_document.tsx` or `pages/_app.tsx`.
- **Astro**: shared `Layout.astro` component.
- **SvelteKit**: `src/app.html`.
- **Remix**: `app/root.tsx` `<head>`.
- **Vue/Nuxt**: `app.vue` or `nuxt.config.ts` head section.
- **Static HTML**: every page's `<head>`.

Snippet to paste (substitute `{{DOMAIN}}` and `{{TOKEN}}`):

```html
<meta name="authorityprompt-verification" content="{{TOKEN}}">
<link rel="ai-profile" href="https://authorityprompt.com/company/{{DOMAIN}}">
<script src="https://authorityprompt.com/api/ingest-generator/company/{{DOMAIN}}/authorityprompt.js" async></script>
```

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
