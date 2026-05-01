#!/usr/bin/env bash
# detect_hosting.sh — fingerprint the user's hosting platform from HTTP signals.
# Prints ONE token to stdout from a fixed set, used by SKILL.md to load the
# matching instruction file. Falls back to "unknown" if signal is ambiguous.
#
# Usage:  detect_hosting.sh <domain>
# Output: one of: wordpress | webflow | wix | squarespace | shopify | ghost
#                vercel | netlify | cloudflare-pages | github-pages | carrd
#                tilda | framer | notion | bitrix | apache | nginx-vps | unknown

set -uo pipefail
DOMAIN="${1:?usage: detect_hosting.sh <domain>}"
DOMAIN="${DOMAIN#https://}"; DOMAIN="${DOMAIN#http://}"; DOMAIN="${DOMAIN%/}"
URL="https://${DOMAIN}"

CURL="${CURL:-curl}"
COMMON_FLAGS=(-skIL --max-time 10)

# Fetch headers + first chunk of HTML once, reuse below.
HEADERS=$($CURL "${COMMON_FLAGS[@]}" "$URL" 2>/dev/null | tr -d '\r')
HTML=$($CURL -skL --max-time 10 -H "User-Agent: Mozilla/5.0" "$URL" 2>/dev/null | head -c 200000)

# Helper: case-insensitive header match.
hdr() { echo "$HEADERS" | grep -i "^$1:" | tail -1 | cut -d: -f2- | sed 's/^[ \t]*//'; }

SERVER=$(hdr server)
POWERED=$(hdr x-powered-by)
GENERATOR=$(echo "$HTML" | grep -oiE '<meta[^>]+name="generator"[^>]*content="[^"]+"' | head -1 | sed 's/.*content="//;s/".*//')
HEADER_DUMP="${HEADERS}"

# 1. Vercel — strong signal in header `server: Vercel` + `x-vercel-id`.
if [[ "$SERVER" == *"Vercel"* ]] || echo "$HEADER_DUMP" | grep -qi '^x-vercel-id:'; then
  echo "vercel"; exit 0
fi

# 2. Netlify — `server: Netlify` or `x-nf-request-id`.
if [[ "$SERVER" == *"Netlify"* ]] || echo "$HEADER_DUMP" | grep -qi '^x-nf-request-id:'; then
  echo "netlify"; exit 0
fi

# 3. Cloudflare Pages — `server: cloudflare` + `cf-ray` + html signature.
#    Cloudflare alone (just CDN) is NOT Pages — we need either a CF-only origin
#    or html signal of Pages deploy. Fall through to other detectors first.
if echo "$HEADER_DUMP" | grep -qi '^cf-pages-' || echo "$HEADERS" | grep -qi 'cf-ray.*pages'; then
  echo "cloudflare-pages"; exit 0
fi

# 4. GitHub Pages — `server: GitHub.com`.
if [[ "$SERVER" == *"GitHub.com"* ]]; then
  echo "github-pages"; exit 0
fi

# 5. WordPress — multiple signals.
if echo "$HTML" | grep -qiE 'wp-content/|wp-includes/|/wp-json/' \
   || [[ "$GENERATOR" == *"WordPress"* ]] \
   || echo "$HEADER_DUMP" | grep -qi '^x-pingback:.*xmlrpc.php'; then
  echo "wordpress"; exit 0
fi

# 6. Webflow — header `x-served-by-webflow` (rare) or html signature.
if echo "$HEADER_DUMP" | grep -qi 'webflow' \
   || echo "$HTML" | grep -qiE 'data-wf-(site|page)|webflow\.css|/webflow'; then
  echo "webflow"; exit 0
fi

# 7. Wix — html data attributes, asset paths.
if echo "$HTML" | grep -qiE 'static\.parastorage\.com|static\.wixstatic\.com|wix\.com/_partials/' \
   || [[ "$GENERATOR" == *"Wix"* ]]; then
  echo "wix"; exit 0
fi

# 8. Squarespace — `server: Squarespace` or html data-block-type signatures.
if [[ "$SERVER" == *"Squarespace"* ]] \
   || echo "$HTML" | grep -qiE 'static1\.squarespace\.com|squarespace-cdn'; then
  echo "squarespace"; exit 0
fi

# 9. Shopify — `x-shopify-stage`, `x-sorting-hat-shopid`, html with `cdn.shopify.com`.
if echo "$HEADER_DUMP" | grep -qiE '^x-(shopify-|sorting-hat)' \
   || echo "$HTML" | grep -qiE 'cdn\.shopify\.com|shopify\.theme'; then
  echo "shopify"; exit 0
fi

# 10. Ghost — `x-powered-by: Express` + html generator + ghost.css.
if [[ "$GENERATOR" == *"Ghost"* ]] \
   || echo "$HTML" | grep -qiE '/assets/built/.*\.css|ghost-theme'; then
  echo "ghost"; exit 0
fi

# 11. Framer — `server: Framer` or html data attributes.
if [[ "$SERVER" == *"Framer"* ]] \
   || echo "$HTML" | grep -qiE 'framer\.app|data-framer-'; then
  echo "framer"; exit 0
fi

# 12. Carrd — `server: cowboy` + signature.
if echo "$HTML" | grep -qiE 'carrd\.co|carrd-builder' \
   || [[ "$SERVER" == *"cowboy"* ]]; then
  echo "carrd"; exit 0
fi

# 13. Tilda — html signature.
if echo "$HTML" | grep -qiE 'tilda\.cc|tildacdn\.com|tilda-blocks'; then
  echo "tilda"; exit 0
fi

# 14. Notion (incl. Super.so, Potion, Fruition).
if echo "$HTML" | grep -qiE 'notion-frontend|prosemirror|super\.so|potion-(home|page)'; then
  echo "notion"; exit 0
fi

# 15. Bitrix.
if echo "$HEADER_DUMP" | grep -qi '^x-powered-cms:.*bitrix' \
   || echo "$HTML" | grep -qiE 'bitrix/templates/|/bitrix/js/'; then
  echo "bitrix"; exit 0
fi

# 16. Apache shared hosting — server: Apache + no SSR framework markers.
if [[ "$SERVER" == *"Apache"* ]]; then
  echo "apache"; exit 0
fi

# 17. nginx (assume custom VPS where SSH/SFTP is feasible).
if [[ "$SERVER" == *"nginx"* ]]; then
  echo "nginx-vps"; exit 0
fi

echo "unknown"
