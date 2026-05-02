# Generic / unknown hosting

Hosting platform couldn't be auto-detected. Walk through the universal questions to figure out what's possible.

## Decision tree

Ask the user:

### Q1 — Do you have file upload access? (FTP / SFTP / SSH / cPanel File Manager / Git push)

- **Yes** → you can do Level-1 install (5 files in /.well-known/ + authorityprompt.js in /js/). Proceed to Q2.
- **No** → Level-2 install only (head tags). Skip to Q3.

### Q2 — Where is the web root?

Common locations:
- `/var/www/html/`
- `/var/www/<domain>/public/`
- `/home/<user>/public_html/` (cPanel)
- `/usr/share/nginx/html/`
- `<repo-root>/public/` or `<repo-root>/dist/` for SSG/SPA

Once located, follow `nginx-vps.md` or `apache.md` depending on the server.

### Q3 — Can you add custom HTML to `<head>` of every page?

Most CMS dashboards have one of these labels — check Settings:
- "Custom Code" / "Code Injection"
- "Custom HTML in <head>"
- "Header script"
- "Custom HEAD code"
- "Script Manager"
- "Site-wide custom code"

- **Yes** → paste `templates/head-snippet.html` (with placeholders replaced) into the **Header / Head** field.
- **No** (rare — happens on locked free-tier site builders) → install is impossible without upgrading the hosting plan or moving the site.

### Q4 — Do you have Cloudflare in front of your site?

- **Yes** → can use `cloudflare-worker.md` to add Level-1 even if base hosting can't serve `/.well-known/*`.
- **No** → stay at Level-2.

### Q5 — Is the site Git-deployed (Vercel / Netlify / Cloudflare Pages / GitHub Pages / etc.)?

- **Yes** → see the matching framework guide. All Git-based hosts support full Level-1.
- **No** → continue with manual flow.

## After the user answers

Based on responses, branch into:
- Has SSH + Apache → `apache.md`
- Has SSH + nginx → `nginx-vps.md`
- Has Git deploy → `vercel.md` / `netlify.md` / `cloudflare-pages.md` / `github-pages.md`
- Has CMS dashboard with Custom HEAD → Level-2 only, paste snippet, run head verification
- Has Cloudflare proxy → `cloudflare-worker.md`
- None of above → install impossible, recommend hosting change

## Final audit always

Whatever path:

```bash
bash scripts/verify_install.sh <domain> <token>
```

If only Level-2 succeeded, that's still a valid working install — the canonical profile lives on AuthorityPrompt's domain and the backlink is what AI crawlers follow.
