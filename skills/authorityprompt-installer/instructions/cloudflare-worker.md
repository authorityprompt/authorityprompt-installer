# Cloudflare Worker (universal `/.well-known/*` proxy)

If the user's site is behind Cloudflare (orange cloud) but the underlying hosting cannot serve `/.well-known/*` (Wix, Squarespace, Carrd, Notion, Webflow without code), a Cloudflare Worker can intercept those requests and proxy them to AuthorityPrompt's hosted versions. This effectively gives them Level-1 install on any closed CMS.

## Step A — verify Cloudflare is in front

```bash
curl -sI https://<domain>/ | grep -i 'server: cloudflare'
```

If empty, Cloudflare is not in front — skip this guide.

## Step B — create the Worker

1. Cloudflare dashboard → **Workers & Pages** → **Create**.
2. **Create Worker** → name it `authorityprompt-proxy`.
3. **Quick edit** → replace the default code with:

```javascript
/**
 * Proxies /.well-known/authorityprompt.* requests to the canonical
 * AuthorityPrompt-hosted profile, leaving everything else untouched.
 * Deploy this Worker in front of any site whose hosting can't serve
 * custom paths under /.well-known/.
 */
export default {
  async fetch(request) {
    const url = new URL(request.url);

    // Case 1 — /.well-known/authorityprompt.{jsonld|yaml|md|txt|html}
    const m = url.pathname.match(/^\/\.well-known\/authorityprompt\.(jsonld|yaml|md|txt|html)$/);
    if (m) {
      const ext = m[1];
      const remote = `https://authorityprompt.com/api/ingest-generator/company/${url.hostname}/authorityprompt.${ext}`;
      const upstream = await fetch(remote, {
        headers: { 'User-Agent': 'authorityprompt-proxy/1.0' },
      });
      return new Response(upstream.body, {
        status: upstream.status,
        headers: {
          'Content-Type': upstream.headers.get('Content-Type') ?? 'application/octet-stream',
          'Cache-Control': 'public, max-age=3600, must-revalidate',
          'Access-Control-Allow-Origin': '*',
        },
      });
    }

    // Case 2 — /js/authorityprompt.js (Option-2 install path that AP's
    // detector probes independently of the script tag in <head>).
    if (url.pathname === '/js/authorityprompt.js') {
      const remote = `https://authorityprompt.com/api/ingest-generator/company/${url.hostname}/authorityprompt.js`;
      const upstream = await fetch(remote, {
        headers: { 'User-Agent': 'authorityprompt-proxy/1.0' },
      });
      return new Response(upstream.body, {
        status: upstream.status,
        headers: {
          'Content-Type': upstream.headers.get('Content-Type') ?? 'application/javascript; charset=utf-8',
          'Cache-Control': 'public, max-age=3600, must-revalidate',
          'Access-Control-Allow-Origin': '*',
        },
      });
    }

    // Pass through all other requests to origin.
    return fetch(request);
  },
};
```

4. **Save and deploy**.

## Step C — bind the Worker to the site

1. Worker → **Settings** → **Triggers** → **Add route**.
2. **Add two routes** (both required):
   - `*<domain>/.well-known/authorityprompt.*` — covers the 5 profile files
   - `*<domain>/js/authorityprompt.js` — covers AP's Option-2 detector path
3. Zone: select the user's domain.
4. **Add route** (twice).

## Step D — head tags

The Worker handles only `/.well-known/*` and `/js/authorityprompt.js`. Head tags still need to go via the user's CMS — see the platform-specific instruction file (e.g. `wix.md`, `squarespace.md`).

## Step E — verify

```bash
bash scripts/verify_install.sh <domain> <token>
```

Expect L1 PASS — Worker proxy serves all **6 endpoints** with correct Content-Type (5 in `/.well-known/` + `/js/authorityprompt.js`). L2-L14 PASS.

## Cost

Cloudflare Workers free tier: 100,000 requests/day. For most sites, AP `/.well-known/*` traffic is < 100 requests/day from AI crawlers. Well within free tier.

## Caveats

- Cloudflare must be in **proxied** mode for the user's domain (orange cloud, not grey).
- If the user later removes Cloudflare or switches to Cloudflare DNS-only, the install breaks.
- Worker subdomain routing won't work if the apex is on a different DNS provider — verify with `dig <domain> NS`.
