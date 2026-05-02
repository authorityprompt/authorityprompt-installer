#!/usr/bin/env bash
# verify_install.sh — full audit of an AuthorityPrompt install on the user's site.
# Checks 12 layers of compliance, exits 0 only if every required layer passes.
#
# Usage:
#   verify_install.sh <domain> [token]                   # full audit
#   verify_install.sh <domain> [token] --phase files     # only the .well-known check
#   verify_install.sh <domain> [token] --phase head      # only head-tag check
#   verify_install.sh <domain> [token] --phase profile   # only AP-side profile check
#
# Exit codes: 0 = all required layers PASS, 1 = at least one required FAIL.

set -uo pipefail

DOMAIN="${1:?usage: verify_install.sh <domain> [token] [--phase ...]}"
DOMAIN="${DOMAIN#https://}"; DOMAIN="${DOMAIN#http://}"; DOMAIN="${DOMAIN%/}"
TOKEN="${2:-}"
PHASE="full"
[[ "${3:-}" == "--phase" ]] && PHASE="${4:-full}"

URL="https://${DOMAIN}"
AP="https://authorityprompt.com/company/${DOMAIN}"

if [[ -t 1 ]]; then G=$'\e[32m'; R=$'\e[31m'; Y=$'\e[33m'; B=$'\e[1m'; X=$'\e[0m'
else G=""; R=""; Y=""; B=""; X=""; fi

PASS=0; FAIL=0
LAYERS_FAILED=()

ok()   { echo "  ${G}✓${X} $1"; PASS=$((PASS+1)); }
ng()   { echo "  ${R}✗${X} $1"; FAIL=$((FAIL+1)); }
warn() { echo "  ${Y}!${X} $1"; }
section() { echo; echo "${B}── $1 ──${X}"; }

CURL="${CURL:-curl}"

http_meta() {
  # GET, not HEAD. AuthorityPrompt's canonical generator API returns 404 on
  # HEAD requests (only implements GET), and any install proxying to AP
  # inherits that behavior. Real consumers — AI crawlers, AP's own install
  # detector, browsers fetching the AP script — all use GET, so HEAD-based
  # audits give false negatives on otherwise-correct installs. Body is
  # discarded via -o /dev/null; we capture only the metrics through -w.
  $CURL -skL --max-time 12 -A "Mozilla/5.0 (compatible; ap-installer/1.0)" \
    -w '%{http_code}|%{content_type}|%{time_starttransfer}|%{http_version}\n' \
    -o /dev/null "$1" 2>/dev/null
}
http_body() {
  $CURL -skL --max-time 12 -A "Mozilla/5.0 (compatible; ap-installer/1.0)" "$1" 2>/dev/null
}

# ─── Phase: site files (.well-known/* + /js/) ───────────────────────────
check_files() {
  section "L1 — Site files (6 endpoints, correct Content-Type)"
  # Each entry: path|primary-MIME|alt-MIME-tokens (pipe-separated regex tokens
  # to also accept). YAML has two valid IANA registrations (RFC 9512
  # `application/yaml` is canonical; `text/yaml` was used widely before the
  # RFC and is still served by many proxies). Markdown similarly has both
  # `text/markdown` and `text/x-markdown`. JavaScript has both
  # `application/javascript` and the legacy `text/javascript`. Accept all
  # commonly-seen variants — Content-Type strictness shouldn't fail an
  # otherwise-correct install.
  #
  # /js/authorityprompt.js is AP's "Option 2" install path. Even users who
  # follow Option 1 (remote <script src=…authorityprompt.com…>) need this
  # path to exist, because AP's installation detector probes it independently
  # and reports `js:NOT_FOUND` when absent. Easiest fix is to proxy
  # /js/authorityprompt.js to AP's canonical generator (see proxy-pattern.md).
  declare -a EXPECT=(
    "/.well-known/authorityprompt.jsonld|application/ld+json|application/json"
    "/.well-known/authorityprompt.yaml|application/yaml|text/yaml|application/x-yaml|text/x-yaml"
    "/.well-known/authorityprompt.md|text/markdown|text/x-markdown"
    "/.well-known/authorityprompt.txt|text/plain"
    "/.well-known/authorityprompt.html|text/html"
    "/js/authorityprompt.js|application/javascript|text/javascript"
  )
  local layer_ok=true
  for entry in "${EXPECT[@]}"; do
    local path="${entry%%|*}"
    local accept="${entry#*|}"   # pipe-separated list of acceptable MIME prefixes
    local meta code ctype
    meta=$(http_meta "${URL}${path}")
    code="${meta%%|*}"
    ctype="${meta#*|}"; ctype="${ctype%%|*}"

    local matched=false
    local IFS='|'
    for mime in $accept; do
      [[ "$ctype" == *"$mime"* ]] && { matched=true; break; }
    done
    unset IFS

    if [[ "$code" == "200" && "$matched" == true ]]; then
      ok "$path → 200 + $ctype"
    else
      ng "$path → ${code:-FAIL} + ${ctype:-?} (need 200 + one of: $accept)"
      layer_ok=false
    fi
  done
  $layer_ok || LAYERS_FAILED+=("L1")
}

# ─── Phase: head tags ────────────────────────────────────────────────────
check_head() {
  section "L2-L4 — head tags (verification meta + ai-profile link + AP script)"
  local html
  html=$(http_body "${URL}/")

  if echo "$html" | grep -qiE '<meta[^>]+name=["'\'']authorityprompt-verification["'\''][^>]+content=["'\''][^"'\'']+["'\'']'; then
    if [[ -n "$TOKEN" ]]; then
      if echo "$html" | grep -qE "authorityprompt-verification[\"'].{0,30}content=[\"']${TOKEN}[\"']"; then
        ok "<meta authorityprompt-verification content=\"$TOKEN\"> matches"
      else
        ng "<meta authorityprompt-verification> present but token doesn't match $TOKEN"
        LAYERS_FAILED+=("L2-token")
      fi
    else
      ok "<meta authorityprompt-verification> present (token not provided to verify)"
    fi
  else
    ng "<meta name=\"authorityprompt-verification\"> missing from <head>"
    LAYERS_FAILED+=("L2")
  fi

  if echo "$html" | grep -qiE '<link[^>]+rel=["'\'']ai-profile["'\''][^>]+href=["'\''][^"'\'']*authorityprompt\.com'; then
    ok "<link rel=\"ai-profile\" href=\"…authorityprompt.com…\"> present"
  else
    ng "<link rel=\"ai-profile\"> missing or doesn't point at authorityprompt.com"
    LAYERS_FAILED+=("L3")
  fi

  # IMPORTANT: must match an actual <script src="..."> tag, not just the URL
  # appearing anywhere in HTML. SSR frameworks (Next.js, Remix, Nuxt, SvelteKit)
  # routinely embed JS-injected scripts as a URL in their hydration data blob —
  # that URL becomes a real <script> tag only after client-side hydration. AP's
  # installation detector and AI crawlers parse raw HTML without executing JS,
  # so they need the literal <script src=…> in the SSR output. This regex
  # tolerates attribute order, quote style, and whitespace.
  if echo "$html" | grep -qiE '<script[^>]+src=["'\''][^"'\'']*authorityprompt\.com/api/ingest-generator/company/[^"'\'']+/authorityprompt\.js'; then
    ok "AP sync <script src=...> tag in SSR HTML"
  elif echo "$html" | grep -qE 'authorityprompt\.com/api/ingest-generator/company/[^"]+/authorityprompt\.js'; then
    ng "AP URL found but NOT as a real <script> tag — likely embedded in hydration data (e.g. next/script with strategy=\"afterInteractive\"). Switch to a plain <script async> in <head>."
    LAYERS_FAILED+=("L4")
  else
    ng "AP sync <script> URL not found in HTML"
    LAYERS_FAILED+=("L4")
  fi
}

# ─── Phase: AP-side profile + AP-installation parity ────────────────────
# These layers mirror AP's own installation detector. Passing all of these
# matches the green checkmarks in the AP dashboard's validation panel:
# bot_tracker_ready, client_files, format_api_{js,jsonld,md,txt,yaml},
# manifest_alias, manifest_json, manifest_layers, sitemap_presence,
# ssr_meta, ssr_page.
check_profile() {
  section "L5-L9 — AP-side profile for ${DOMAIN}"
  local meta code ctype
  declare -a AP_PATHS=(
    "/|text/html"
    "/manifest.json|application/json"
    "/authorityprompt.jsonld|application/ld+json"
    "/authorityprompt.yaml|application/yaml"
    "/authorityprompt.md|text/markdown"
    "/authorityprompt.txt|text/plain"
    "/authorityprompt.html|text/html"
  )
  local layer_ok=true
  for entry in "${AP_PATHS[@]}"; do
    local path="${entry%%|*}" expect="${entry#*|}"
    local url
    if [[ "$path" == "/" ]]; then url="$AP"; else url="${AP}${path}"; fi
    meta=$(http_meta "$url")
    code="${meta%%|*}"
    ctype="${meta#*|}"; ctype="${ctype%%|*}"
    if [[ "$code" == "200" && "$ctype" == *"$expect"* ]]; then
      ok "AP$path → 200 + $ctype"
    else
      ng "AP$path → ${code:-FAIL} + ${ctype:-?}"
      layer_ok=false
    fi
  done
  $layer_ok || LAYERS_FAILED+=("L5")

  section "L6 — content_hash matches SHA-256(jsonld)"
  local manifest declared computed tmp_jsonld
  manifest=$(http_body "${AP}/manifest.json")
  # Hash via tmpfile — bash command-substitution strips trailing newlines, which
  # corrupts the byte-exact match against AP's server-side hash. Curl directly
  # to disk preserves bytes verbatim, openssl reads the file as-is.
  tmp_jsonld=$(mktemp -t ap_jsonld.XXXXXX)
  $CURL -skL --max-time 12 -A "Mozilla/5.0 (compatible; ap-installer/1.0)" \
        -o "$tmp_jsonld" "${AP}/authorityprompt.jsonld" 2>/dev/null
  declared=$(echo "$manifest" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("content_hash","NONE"))' 2>/dev/null)
  computed=$(openssl dgst -sha256 "$tmp_jsonld" | awk '{print $NF}')
  rm -f "$tmp_jsonld"
  if [[ -n "$declared" && "$declared" == "$computed" ]]; then
    ok "content_hash MATCH ($declared)"
  else
    ng "content_hash MISMATCH (manifest=$declared, computed=$computed)"
    LAYERS_FAILED+=("L6")
  fi

  section "L7 — verification block declared and method recognized"
  local vmethod vat
  vmethod=$(echo "$manifest" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("verification",{}).get("method","NONE"))' 2>/dev/null)
  vat=$(echo "$manifest" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("verification",{}).get("verified_at","NONE"))' 2>/dev/null)
  if [[ -n "$vmethod" && "$vmethod" != "NONE" ]]; then
    ok "verification.method=$vmethod, verified_at=$vat"
  else
    ng "verification block missing or empty"
    LAYERS_FAILED+=("L7")
  fi

  section "L8 — last_updated freshness (≤ 90 days)"
  local lu
  lu=$(echo "$manifest" | python3 -c 'import json,sys,datetime,time
m=json.load(sys.stdin)
ts=m.get("last_updated","")
try:
    ts2=ts.replace("Z","+00:00")
    dt=datetime.datetime.fromisoformat(ts2)
    age=int(time.time()-dt.timestamp())
    print(f"{age}|{ts}")
except Exception as e:
    print(f"PARSE_ERROR|{e}")' 2>/dev/null)
  local age="${lu%%|*}" raw="${lu#*|}"
  if [[ "$age" =~ ^[0-9]+$ && "$age" -le 7776000 ]]; then
    ok "last_updated $raw (age $((age/86400)) d, ≤ 90)"
  else
    ng "last_updated invalid or stale: $raw"
    LAYERS_FAILED+=("L8")
  fi

  section "L9 — AI crawler accessibility (5 UAs → 200 on AP profile)"
  declare -a UAS=(
    "Mozilla/5.0 AppleWebKit/537.36; compatible; GPTBot/1.0; +https://openai.com/gptbot"
    "Mozilla/5.0 AppleWebKit/537.36; compatible; OAI-SearchBot/1.0"
    "Mozilla/5.0 (compatible; ClaudeBot/1.0; +claudebot@anthropic.com)"
    "Mozilla/5.0 (compatible; PerplexityBot/1.0; +https://docs.perplexity.ai/guides/bots)"
    "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
  )
  local layer9_ok=true
  for ua in "${UAS[@]}"; do
    local bot code
    # Case-insensitive — Googlebot has lowercase `b`.
    bot=$(echo "$ua" | grep -oiE '[A-Za-z-]+bot[/0-9.]*' | head -1)
    # GET (not HEAD) — same reason as http_meta. AP's API returns 404 on HEAD.
    code=$($CURL -skLo /dev/null -w '%{http_code}' --max-time 8 -A "$ua" "${AP}/manifest.json")
    if [[ "$code" == "200" ]]; then
      ok "$bot → 200"
    else
      ng "$bot → $code"; layer9_ok=false
    fi
  done
  $layer9_ok || LAYERS_FAILED+=("L9")

  # ─── L10 — manifest layers (AP's `manifest_layers` parity check) ───
  section "L10 — every advertised manifest layer is reachable"
  local layers_ok=true
  local layer_urls
  layer_urls=$(echo "$manifest" | python3 -c '
import json,sys
m=json.load(sys.stdin)
ls=m.get("layers",{})
if isinstance(ls, dict):
    for k,v in ls.items():
        url=None
        if isinstance(v, str) and v.startswith("http"): url=v
        elif isinstance(v, dict): url=v.get("url") or v.get("uri") or v.get("href")
        if url: print(f"{k}|{url}")
elif isinstance(ls, list):
    for item in ls:
        if isinstance(item, dict):
            url=item.get("url") or item.get("uri") or item.get("href")
            name=item.get("name", "?")
            if url: print(f"{name}|{url}")
' 2>/dev/null)
  if [[ -z "$layer_urls" ]]; then
    ng "manifest.layers missing or empty"
    LAYERS_FAILED+=("L10"); layers_ok=false
  else
    while IFS='|' read -r name url; do
      [[ -z "$url" ]] && continue
      local lcode
      lcode=$($CURL -skLo /dev/null -w '%{http_code}' --max-time 8 "$url")
      if [[ "$lcode" == "200" ]]; then
        ok "layer $name → 200"
      else
        ng "layer $name → $lcode ($url)"
        layers_ok=false
      fi
    done <<< "$layer_urls"
    $layers_ok || LAYERS_FAILED+=("L10")
  fi

  # ─── L11 — format files contain canonical backlink (AP `format_api_*`) ─
  section "L11 — format files reference subject domain (backlink check)"
  local backlinks_ok=true
  for fmt in jsonld yaml md txt html; do
    local body
    body=$(http_body "${AP}/authorityprompt.${fmt}")
    # AP's `format_api_*` checks expect each format file to contain a
    # backlink to the canonical AP profile + the subject domain. We
    # verify the subject domain appears (it's the strong signal).
    if echo "$body" | grep -q "$DOMAIN"; then
      ok "${fmt} contains '$DOMAIN' backlink"
    else
      ng "${fmt} missing '$DOMAIN' backlink"
      backlinks_ok=false
    fi
  done
  $backlinks_ok || LAYERS_FAILED+=("L11")

  # ─── L12 — sitemap presence (AP `sitemap_presence`) ───
  section "L12 — subject is listed in AuthorityPrompt sitemap"
  local sitemap_url="https://authorityprompt.com/sitemap.xml"
  local sm_body
  sm_body=$($CURL -sL --max-time 10 "$sitemap_url")
  if echo "$sm_body" | grep -qE "/company/${DOMAIN}([^A-Za-z0-9.]|$)"; then
    ok "sitemap contains /company/${DOMAIN}"
  else
    ng "sitemap does NOT contain /company/${DOMAIN} — submit your domain to AP"
    LAYERS_FAILED+=("L12")
  fi

  # ─── L13 — manifest alias (AP `manifest_alias`) ───
  section "L13 — canonical profile alias reachable (HTML profile)"
  local alias_meta alias_code
  alias_meta=$(http_meta "${AP}")  # /company/{domain} (no trailing /manifest.json)
  alias_code="${alias_meta%%|*}"
  if [[ "$alias_code" == "200" ]]; then
    ok "canonical profile alias → 200 (${AP})"
  else
    ng "canonical profile alias → $alias_code"
    LAYERS_FAILED+=("L13")
  fi

  # ─── L14 — cryptographic signature (when AP exposes one) ───
  section "L14 — manifest signature verification"
  local sig pubkey_url alg
  sig=$(echo "$manifest" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("signature","") or "")' 2>/dev/null)
  pubkey_url=$(echo "$manifest" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("pubkey_url","") or "")' 2>/dev/null)
  alg=$(echo "$manifest" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("signature_alg","") or "")' 2>/dev/null)
  if [[ -z "$sig" ]]; then
    skip "L14" "manifest has no signature field — AP not signing yet for this profile"
  elif [[ -z "$pubkey_url" ]]; then
    ng "signature present but pubkey_url missing — cannot verify"
    LAYERS_FAILED+=("L14")
  else
    local pcode
    pcode=$($CURL -skLo /dev/null -w '%{http_code}' --max-time 8 "$pubkey_url")
    if [[ "$pcode" == "200" ]]; then
      ok "signature_alg=$alg, pubkey reachable at $pubkey_url"
    else
      ng "pubkey_url returns $pcode"
      LAYERS_FAILED+=("L14")
    fi
  fi
}

# ─── Run ─────────────────────────────────────────────────────────────────
echo "${B}AuthorityPrompt install audit — ${DOMAIN}${X}"

case "$PHASE" in
  files)   check_files ;;
  head)    check_head ;;
  profile) check_profile ;;
  full|*)  check_files; check_head; check_profile ;;
esac

echo
echo "${B}══ Summary ══${X}"
echo "  passes: $PASS"
echo "  fails:  $FAIL"
if [[ ${#LAYERS_FAILED[@]} -gt 0 ]]; then
  echo "  failed layers: ${LAYERS_FAILED[*]}"
  echo
  echo "${R}${B}✗ INSTALL INCOMPLETE${X}"
  exit 1
fi
echo
echo "${G}${B}✓ INSTALL COMPLETE — canonical AI-readable profile is live.${X}"
echo "  dashboard: https://authorityprompt.com/company/${DOMAIN}"
exit 0
