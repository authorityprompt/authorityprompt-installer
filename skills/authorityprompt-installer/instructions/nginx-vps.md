# nginx VPS (custom server, Docker, full root access)

You have SSH/root access. This is the simplest install.

## Step A — `/.well-known/*` files

```bash
# from your local machine, push the 5 AP files:
bash scripts/ssh_deploy.sh root@<vps-ip> /var/www/<domain>/public ~/Downloads/authorityprompt-<domain>/
```

Or manually:

```bash
ssh root@<vps-ip>
mkdir -p /var/www/<domain>/public/.well-known
# (back on local) scp the 5 files into that directory
```

## Step B — Content-Type config in nginx

Add to your server block (or include via separate file):

```nginx
location ^~ /.well-known/ {
    autoindex off;
    types {
        application/ld+json   jsonld;
        application/yaml      yaml;
        text/markdown         md;
        text/plain            txt;
        text/html             html;
    }
    default_type application/octet-stream;
    try_files $uri =404;

    # Optional: cache 1 hour with revalidation
    add_header Cache-Control "public, max-age=3600, must-revalidate";
}
```

Reload:

```bash
nginx -t && systemctl reload nginx
```

## Step C — head tags

If your site is a static HTML site or templated app, add the snippet from `templates/head-snippet.html` to the appropriate template/layout.

If it's a Next.js / SvelteKit / Astro / etc. app behind nginx as reverse proxy — add the head tags inside the framework's root layout. See `vercel.md` for the per-framework specifics.

## Step D — verify

```bash
bash scripts/verify_install.sh <domain> <token>
```

Expect all PASS.

## Reference setup

A common production pattern: nginx reverse-proxy in front of a Next.js standalone container, with `next.config.ts` setting per-file Content-Type for `.well-known/authorityprompt.*` (Next serves the static files internally, not nginx). All 9 layers pass on first deploy when both the nginx `location ^~ /.well-known/` block above and Next-side headers are in place.
