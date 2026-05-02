# Apache (shared hosting / cPanel / DirectAdmin / Plesk)

Catch-all for Apache-served sites that aren't WordPress or another CMS — bare HTML, PHP apps, static sites uploaded via FTP, etc.

## Step A — `/.well-known/*` files

1. Connect via FTP/SFTP or File Manager (cPanel/DirectAdmin/Plesk).
2. Navigate to web root — `public_html/`, `www/`, `httpdocs/`, or whatever your control panel labels as document root.
3. Create `.well-known/` directory (enable "Show hidden files" if you don't see it).
4. Upload all 5 profile files (`authorityprompt.{jsonld,yaml,md,txt,html}`).
5. Upload `templates/htaccess.conf` from this skill, renamed to `.htaccess`, into `.well-known/`. This sets the correct Content-Type for `.jsonld` / `.yaml` / `.md`.
6. **Also required** — create `<web-root>/js/` and upload `authorityprompt.js` to `<web-root>/js/authorityprompt.js`. AP's detector probes this Option-2 path independently of how the script tag is loaded in `<head>`, and reports `js:NOT_FOUND` when missing.

Or use the SSH script if shell access is available:

```bash
bash scripts/ssh_deploy.sh <user@host> /home/<user>/public_html ~/Downloads/authorityprompt-<domain>/
```

## Step B — head tags

For static HTML sites: add the snippet from `templates/head-snippet.html` to `<head>` of every `.html` file. If there are many pages, use `sed` or a build script:

```bash
# adds the snippet just before </head> in every .html file in the directory
for f in *.html; do
  sed -i.bak '/<\/head>/i \
<meta name="authorityprompt-verification" content="YOUR_TOKEN">\
<link rel="ai-profile" href="https://authorityprompt.com/company/YOUR_DOMAIN">\
<script src="https://authorityprompt.com/api/ingest-generator/company/YOUR_DOMAIN/authorityprompt.js" async></script>' "$f"
done
```

For PHP apps: find the layout/template/header include and add the snippet there.

## Step C — verify

```bash
bash scripts/verify_install.sh <domain> <token>
```

Expect all PASS once .htaccess is in place.

## Common pitfalls

- **Hidden directory visibility**: Many control panels hide files starting with `.`. In cPanel File Manager: Settings → "Show Hidden Files (dotfiles)".
- **Permissions**: `.well-known/` should be `755`, files `644`. cPanel auto-sets these correctly on upload.
- **`AllowOverride None`**: Some shared hosts disable `.htaccess`. If verification shows wrong Content-Types, ask hosting support to enable `AllowOverride FileInfo` for the document root, or move to a host that supports it.
