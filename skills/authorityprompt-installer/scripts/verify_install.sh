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
  $CURL -skIL --max-time 12 -A "Mozilla/5.0 (compatible; ap-installer/1.0)" \
    -w '%{http_code}|%{content_type}|%{time_starttransfer}|%{http_version}\n' \
    -o /dev/null "$1" 2>/dev/null | tail -1
}
http_body() {
  $CURL -skL --max-time 12 -A "Mozilla/5.0 (compatible; ap-installer/1.0)" "$1" 2>/dev/null
}

# ─── Phase: site files (.well-known/*) ───────────────────────────────────
check_files() {
  section "L1 — Site .well-known files (5 endpoints, correct Content-Type)"
  declare -a EXPECT=(
    "/.well-known/authorityprompt.jsonld|application/ld+json"
    "/.well-known/authorityprompt.yaml|application/yaml"
    "/.well-known/authorityprompt.md|text/markdown"
    "/.well-known/authorityprompt.txt|text/plain"
    "/.well-known/authorityprompt.html|text/html"
  )
  local layer_ok=true
  for entry in "${EXPECT[@]}"; do
    local path="${entry%%|*}" expect="${entry#*|}"
    local meta code ctype
    meta=$(http_meta "${URL}${path}")
    code="${meta%%|*}"
    ctype="${meta#*|}"; ctype="${ctype%%|*}"
    if [[ "$code" == "200" && "$ctype" == *"$expect"* ]]; then
      ok "$path → 200 + $ctype"
    else
      ng "$path → ${code:-FAIL} + ${ctype:-?} (need 200 + $expect)"
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

# ─── Phase: AP-side profile ──────────────────────────────────────────────
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
    code=$($CURL -skILo /dev/null -w '%{http_code}' --max-time 8 -A "$ua" "${AP}/manifest.json")
    if [[ "$code" == "200" ]]; then
      ok "$bot → 200"
    else
      ng "$bot → $code"; layer9_ok=false
    fi
  done
  $layer9_ok || LAYERS_FAILED+=("L9")
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
