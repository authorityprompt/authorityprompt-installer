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
    const m = url.pathname.match(/^\/\.well-known\/authorityprompt\.(jsonld|yaml|md|txt|html)$/);

    if (m) {
      const ext = m[1];
      const remote = `https://authorityprompt.com/company/${url.hostname}/authorityprompt.${ext}`;
      const upstream = await fetch(remote, {
        headers: { 'User-Agent': 'authorityprompt-proxy/1.0' },
      });
      // Pass through with original status + Content-Type, strip cookies.
      return new Response(upstream.body, {
        status: upstream.status,
        headers: {
          'Content-Type': upstream.headers.get('Content-Type') ?? 'application/octet-stream',
          'Cache-Control': 'public, max-age=3600, must-revalidate',
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
2. Route: `*<domain>/.well-known/authorityprompt.*` (replace `<domain>` with the user's hostname; the leading `*` is wildcard for subdomains).
3. Zone: select the user's domain.
4. **Add route**.

## Step D — head tags

The Worker handles only `/.well-known/*`. Head tags still need to go via the user's CMS — see the platform-specific instruction file (e.g. `wix.md`, `squarespace.md`).

## Step E — verify

```bash
bash scripts/verify_install.sh <domain> <token>
```

Expect L1 PASS (Worker proxy serves the 5 files with correct Content-Type from AuthorityPrompt directly), L2-L9 PASS.

## Cost

Cloudflare Workers free tier: 100,000 requests/day. For most sites, AP `/.well-known/*` traffic is < 100 requests/day from AI crawlers. Well within free tier.

## Caveats

- Cloudflare must be in **proxied** mode for the user's domain (orange cloud, not grey).
- If the user later removes Cloudflare or switches to Cloudflare DNS-only, the install breaks.
- Worker subdomain routing won't work if the apex is on a different DNS provider — verify with `dig <domain> NS`.
