# WordPress

Two install vectors depending on whether the user has FTP/SFTP access.

## Path 1 — full Level-1 install (with FTP/SFTP/cPanel access)

The 5 `/.well-known/` files go in the web root. The head tags go via a plugin or `functions.php`.

### Step A — upload the 5 .well-known files

1. Open File Manager (cPanel) or connect via FTP/SFTP.
2. Navigate to the public web root — usually `public_html/` for cPanel, `/home/<user>/public_html/`, or `/var/www/html/` for self-hosted.
3. Create a directory `.well-known/` if it doesn't exist (the leading dot is important — some File Managers hide it; enable "Show hidden files").
4. Upload all 5 files from the user's local `authorityprompt-<domain>/` folder:
   - `authorityprompt.jsonld`
   - `authorityprompt.yaml`
   - `authorityprompt.md`
   - `authorityprompt.txt`
   - `authorityprompt.html`
5. **Apache only** — also upload `templates/htaccess.conf` from this skill, renamed to `.htaccess`, into the same `.well-known/` directory. This fixes Content-Type for `.jsonld` / `.yaml` / `.md`.

Verify: `bash scripts/verify_install.sh <domain> <token> --phase files`. All 5 must return 200 + correct Content-Type.

### Step B — add the 3 head tags

Three options, pick one:

**B.1 — "Insert Headers and Footers" plugin (zero-code, recommended)**

1. Plugins → Add New → search "WPCode" or "Insert Headers and Footers" by WPBeginner.
2. Install + Activate.
3. Settings → Insert Headers and Footers → "Scripts in Header" field.
4. Paste the contents of `templates/head-snippet.html` (with `{{DOMAIN}}` and `{{TOKEN}}` replaced).
5. Save.

**B.2 — Theme `functions.php`**

Add to active theme's `functions.php`:

```php
add_action('wp_head', function () {
    echo '<meta name="authorityprompt-verification" content="YOUR_TOKEN">' . "\n";
    echo '<link rel="ai-profile" href="https://authorityprompt.com/company/YOUR_DOMAIN">' . "\n";
    echo '<script src="https://authorityprompt.com/api/ingest-generator/company/YOUR_DOMAIN/authorityprompt.js" async></script>' . "\n";
}, 1);
```

**B.3 — Theme header.php** (only if you cannot use B.1 or B.2)

Edit `wp-content/themes/<active-theme>/header.php`. Find `<head>` and add the snippet just before `</head>`.

### Step C — verify

Run the full audit: `bash scripts/verify_install.sh <domain> <token>`. Expect all 8+ layers PASS.

## Path 2 — managed WordPress (WordPress.com, no FTP)

`/.well-known/*` is impossible here. Use Level-2 install (head tags only).

1. Block the 5-file upload step entirely.
2. Use plugin path B.1 above for head tags.
3. Run `verify_install.sh --phase head` only — expect 3/3 PASS.
4. Final audit will show L1 FAIL but L2-L9 PASS — explain to the user that AI crawlers will discover their profile via the `ai-profile` backlink to `authorityprompt.com/company/<domain>`, where all 7 endpoints are served by AuthorityPrompt directly. The local files are a duplicate convenience layer that closed-managed hosting can't provide.
