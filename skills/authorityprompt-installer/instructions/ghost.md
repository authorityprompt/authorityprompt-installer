# Ghost

Ghost (self-hosted or Ghost(Pro)) supports head tags via Code Injection. `/.well-known/*` files are possible only on self-hosted with file system access.

## Step A — head tags

1. Ghost Admin → **Settings** → **Code Injection**.
2. In the **Site Header** field, paste from `templates/head-snippet.html` with placeholders replaced.
3. **Save**.

Live immediately.

## Step B — `/.well-known/*` files

### Ghost(Pro) — managed hosting

Not possible. Stay on Level-2 install.

### Self-hosted Ghost (Docker, VPS)

The Ghost Node app does NOT serve files from a public directory by default. You need an upstream nginx (or Caddy) in front. Use the SSH script:

```bash
# Find your Ghost installation's content/files location, then upload via SSH:
bash scripts/ssh_deploy.sh <user@host> /var/www/ghost/content/public ~/Downloads/authorityprompt-<domain>/
```

Add to your nginx config:

```nginx
location ^~ /.well-known/ {
    alias /var/www/ghost/content/public/.well-known/;
    types {
        application/ld+json   jsonld;
        application/yaml      yaml;
        text/markdown         md;
        text/plain            txt;
        text/html             html;
    }
    autoindex off;
    try_files $uri =404;
}
```

Reload nginx: `systemctl reload nginx`.

## Step C — verify

```bash
bash scripts/verify_install.sh <domain> <token>
```

Self-hosted: expect all PASS. Ghost(Pro): expect L1 FAIL, rest PASS.
