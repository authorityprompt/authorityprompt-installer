# Always-fresh proxy pattern (recommended for Git-based hosting)

The default install pattern — copying the 5 `/.well-known/authorityprompt.*` files into your repo and shipping them as static assets — works, but creates a **stale-files problem**: AuthorityPrompt regenerates the canonical profile every ~24 hours (timestamps, version IDs, `content_hash`), and your deployed copy gets older every minute until you re-rsync.

The **proxy pattern** removes that drift entirely. Instead of static copies, your hosting reverse-proxies `/.well-known/authorityprompt.*` directly to AuthorityPrompt's canonical generator API. The user-facing URL stays on your domain (so verification, backlinks, AI-bot fetches all work), but the bytes are always live.

## Why this is better

| Behavior | Static copies | Proxy |
|---|---|---|
| File freshness | up to 24h stale (manual rsync needed) | always live (AP regenerations propagate within 1h via CDN cache) |
| Update cost | manual `rsync` + `docker compose build` per AP refresh | zero — automatic |
| Resilience to AP downtime | serves stale file (incorrect `content_hash` mismatch) | returns 502, AI bots correctly retry later |
| Local file management | 5 files in `public/.well-known/` | none |
| `Content-Type` correctness | per-file headers config required | upstream MIME passes through |

## Implementation per host

### Next.js (Vercel, Netlify, Cloudflare Pages, custom — anywhere Next runs)

In `next.config.ts` (or `.js`):

```typescript
const AP = 'https://authorityprompt.com/api/ingest-generator/company/YOUR-DOMAIN/authorityprompt';

const config = {
  async rewrites() {
    return [
      { source: '/.well-known/authorityprompt.jsonld', destination: `${AP}.jsonld` },
      { source: '/.well-known/authorityprompt.yaml',   destination: `${AP}.yaml` },
      { source: '/.well-known/authorityprompt.md',     destination: `${AP}.md` },
      { source: '/.well-known/authorityprompt.txt',    destination: `${AP}.txt` },
      { source: '/.well-known/authorityprompt.html',   destination: `${AP}.html` },
      // Option-2 install path. AP's installation detector probes this URL
      // independently and reports `js:NOT_FOUND` if absent — even when you
      // use Option 1 (remote <script src=…authorityprompt.com…>) in <head>.
      // Proxying it satisfies the detector and keeps the script byte-fresh.
      { source: '/js/authorityprompt.js',              destination: `${AP}.js` },
    ];
  },
  async headers() {
    const apFileHeaders = [
      { key: 'Access-Control-Allow-Origin',  value: '*' },
      { key: 'Access-Control-Allow-Methods', value: 'GET, HEAD, OPTIONS' },
      { key: 'Cache-Control',                value: 'public, max-age=3600, must-revalidate' },
    ];
    return [
      { source: '/.well-known/authorityprompt.jsonld', headers: apFileHeaders },
      { source: '/.well-known/authorityprompt.yaml',   headers: apFileHeaders },
      { source: '/.well-known/authorityprompt.md',     headers: apFileHeaders },
      { source: '/.well-known/authorityprompt.txt',    headers: apFileHeaders },
      { source: '/.well-known/authorityprompt.html',   headers: apFileHeaders },
      { source: '/js/authorityprompt.js',              headers: apFileHeaders },
    ];
  },
};
export default config;
```

**Important:** if you previously placed files in `public/.well-known/`, **delete them**. Static `public/` files take precedence over `rewrites` and the proxy won't trigger.

### nginx (custom VPS)

```nginx
location ^~ /.well-known/authorityprompt.jsonld {
    proxy_pass https://authorityprompt.com/api/ingest-generator/company/YOUR-DOMAIN/authorityprompt.jsonld;
    proxy_set_header Host authorityprompt.com;
    proxy_ssl_server_name on;
    proxy_hide_header Set-Cookie;
    add_header Access-Control-Allow-Origin "*" always;
    add_header Access-Control-Allow-Methods "GET, HEAD, OPTIONS" always;
    add_header Cache-Control "public, max-age=3600, must-revalidate" always;
}

# Repeat for .yaml / .md / .txt / .html — or use a regex location:
location ~ ^/\.well-known/authorityprompt\.(jsonld|yaml|md|txt|html)$ {
    proxy_pass https://authorityprompt.com/api/ingest-generator/company/YOUR-DOMAIN/authorityprompt.$1;
    proxy_set_header Host authorityprompt.com;
    proxy_ssl_server_name on;
    add_header Access-Control-Allow-Origin "*" always;
    add_header Cache-Control "public, max-age=3600, must-revalidate" always;
}

# Option-2 path for AP's installation detector — proxied to the same canonical
# generator. Even sites on Option 1 (remote <script src=…>) need this present.
location = /js/authorityprompt.js {
    proxy_pass https://authorityprompt.com/api/ingest-generator/company/YOUR-DOMAIN/authorityprompt.js;
    proxy_set_header Host authorityprompt.com;
    proxy_ssl_server_name on;
    add_header Access-Control-Allow-Origin "*" always;
    add_header Cache-Control "public, max-age=3600, must-revalidate" always;
}
```

Reload: `nginx -t && systemctl reload nginx`.

### Cloudflare Worker

If your hosting can't proxy directly (Webflow, Wix, Squarespace, Carrd, Tilda, Framer, Notion wrappers — see `cloudflare-worker.md`), the same Worker code that intercepts `/.well-known/*` requests gives you the proxy pattern for free. The Worker is the proxy.

### Apache

```apache
<IfModule mod_proxy.c>
  ProxyRequests Off
  SSLProxyEngine On

  ProxyPass        /.well-known/authorityprompt.jsonld https://authorityprompt.com/api/ingest-generator/company/YOUR-DOMAIN/authorityprompt.jsonld
  ProxyPassReverse /.well-known/authorityprompt.jsonld https://authorityprompt.com/api/ingest-generator/company/YOUR-DOMAIN/authorityprompt.jsonld
  # repeat for .yaml / .md / .txt / .html

  Header always set Access-Control-Allow-Origin "*"
  Header always set Cache-Control "public, max-age=3600, must-revalidate"
</IfModule>
```

Requires `mod_proxy`, `mod_proxy_http`, `mod_ssl`, `mod_headers` enabled.

## Verification

After deploying the proxy:

```bash
# 1. Local file should byte-match the canonical
diff <(curl -sL https://YOUR-DOMAIN/.well-known/authorityprompt.jsonld) \
     <(curl -sL https://authorityprompt.com/api/ingest-generator/company/YOUR-DOMAIN/authorityprompt.jsonld)
# (no output = identical)

# 2. CORS open
curl -skI https://YOUR-DOMAIN/.well-known/authorityprompt.jsonld | grep -i access-control
# → Access-Control-Allow-Origin: *

# 3. Full audit
bash scripts/verify_install.sh YOUR-DOMAIN YOUR-TOKEN
# → 23 passes / 0 fails
```

## Caveats

- **HEAD requests fail.** AP's canonical generator API only implements `GET` — it returns 404 on `HEAD`. The proxy faithfully forwards this. Real consumers (AI crawlers, AP's install detector, browsers fetching the script) all use GET, so this is irrelevant in practice. `verify_install.sh` (v1.0.2+) uses GET specifically to avoid false negatives.
- **`content_hash` race conditions.** AP regenerates `manifest.json` and the format files in stages. If your audit runs during a regeneration window (rare, < 1 second), the manifest's declared `content_hash` may briefly not match the SHA-256 of the live `authorityprompt.jsonld`. Re-run after a few seconds.
- **Latency.** Each proxied request now traverses your origin → AuthorityPrompt → back. Cloudflare (or whatever CDN sits in front of your domain) caches by default; we set `Cache-Control: public, max-age=3600` for explicit 1-hour edge cache. AP-bot traffic to `/.well-known/*` is rare (a few requests/day per crawler), so latency budget isn't a concern.

## When NOT to use proxy pattern

- **Closed-managed CMS** (Wix, Squarespace, Webflow without Cloudflare, etc.) — those can't run server-side proxies. Stick with Level-2 install (head tags only); AI crawlers will follow the `<link rel="ai-profile">` backlink to AuthorityPrompt's canonical URL directly.
- **Static-site-only hosts** without rewrite/proxy support (some legacy GitHub Pages setups, plain S3+CloudFront without Lambda@Edge). Use static copies + a daily cron to re-pull from AP.

For everything else — proxy pattern is the right call.
