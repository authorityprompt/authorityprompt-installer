# Bitrix (Bitrix24 / 1C-Bitrix)

Bitrix supports both vectors via FTP/SFTP file upload + admin panel HEAD injection.

## Step A — `/.well-known/*` files

1. Connect via FTP/SFTP (admin panel → Settings → Tools → SiteUpdate or external client).
2. Navigate to web root — typically `/home/bitrix/www/` or your installation's DOCUMENT_ROOT.
3. Create `.well-known/` directory if missing (server-side `mkdir`, since some FTP clients hide dotdirs).
4. Upload all 5 profile files (`authorityprompt.{jsonld,yaml,md,txt,html}`).
5. Apache shared hosting — also upload `templates/htaccess.conf` renamed to `.htaccess`.
6. **Also required** — upload `authorityprompt.js` from the bundle to `<web-root>/js/authorityprompt.js` (create the `/js/` directory if missing). AP's installation detector probes this Option-2 path independently and reports `js:NOT_FOUND` if absent.

## Step B — head tags

Bitrix has multiple ways:

### B.1 — Footer template (recommended, simplest)

Admin panel → **Settings** → **System Settings** → **Site Settings** → select your site → **Site Templates** → edit the active template.

Find the `<head>` section in `header.php`. Add the snippet just before `</head>`:

```html
<meta name="authorityprompt-verification" content="{{TOKEN}}">
<link rel="ai-profile" href="https://authorityprompt.com/company/{{DOMAIN}}">
<script src="https://authorityprompt.com/api/ingest-generator/company/{{DOMAIN}}/authorityprompt.js" async></script>
```

Save.

### B.2 — `init.php` event handler

Add to `/bitrix/php_interface/init.php`:

```php
AddEventHandler("main", "OnEpilog", function() {
    if (!defined("ADMIN_SECTION")) {
        echo '<meta name="authorityprompt-verification" content="YOUR_TOKEN">';
        // Note: OnEpilog fires after </head> — for proper <head> injection,
        // edit the template (B.1) or use OnPageStart with output buffering.
    }
});
```

B.1 is preferred — fewer moving parts.

## Step C — verify

```bash
bash scripts/verify_install.sh <domain> <token>
```

Expect all PASS if you have file system access.

## Bitrix in cloud (Bitrix24.ru hosted)

Hosted Bitrix24 sites do NOT allow custom code or file uploads to web root. **Install is impossible** without moving to self-hosted Bitrix or putting Cloudflare in front.
