#!/usr/bin/env bash
# ssh_deploy.sh — optional automated upload for users with SSH/SFTP access.
# Only runs when the user explicitly authorizes it. Never stores credentials.
#
# Usage:
#   ssh_deploy.sh <user@host> <remote-public-dir> <local-ap-files-dir>
#
# Example:
#   ssh_deploy.sh root@5.78.80.26 /var/www/example.com/public ~/Downloads/authorityprompt-example/
#
# What it does:
#   1. Creates `<remote-public-dir>/.well-known/` if missing
#   2. SCPs the 5 .well-known/* files
#   3. Sets correct permissions (644 file, 755 dir)
#   4. Optionally writes a per-platform Content-Type fix (Apache .htaccess)
#
# What it does NOT do:
#   - Edit any HTML files (head tags are the user's responsibility — paste-job)
#   - Touch any other directory than `.well-known/`
#   - Take any destructive action without confirmation

set -euo pipefail

REMOTE="${1:?usage: ssh_deploy.sh <user@host> <remote-public-dir> <local-ap-files-dir>}"
REMOTE_DIR="${2:?missing remote-public-dir}"
LOCAL_DIR="${3:?missing local-ap-files-dir}"
LOCAL_DIR="${LOCAL_DIR%/}"

REQUIRED=(
  "authorityprompt.jsonld"
  "authorityprompt.yaml"
  "authorityprompt.md"
  "authorityprompt.txt"
  "authorityprompt.html"
)

echo "▸ Validating local files at $LOCAL_DIR"
for f in "${REQUIRED[@]}"; do
  if [[ ! -f "${LOCAL_DIR}/${f}" ]]; then
    echo "✗ Missing: ${LOCAL_DIR}/${f}"
    echo "  Re-download the AuthorityPrompt bundle from your dashboard."
    exit 1
  fi
done
echo "  ✓ all 5 files present"

echo
echo "▸ Connecting to $REMOTE"
echo "  remote target: ${REMOTE_DIR}/.well-known/"
echo "  Confirm by typing the word 'deploy' below; anything else aborts."
read -r CONFIRM
[[ "$CONFIRM" == "deploy" ]] || { echo "✗ aborted"; exit 1; }

echo "▸ Creating remote .well-known/ directory and uploading files"
ssh "$REMOTE" "mkdir -p ${REMOTE_DIR}/.well-known && chmod 755 ${REMOTE_DIR}/.well-known"

for f in "${REQUIRED[@]}"; do
  echo "  ↑ ${f}"
  scp -q "${LOCAL_DIR}/${f}" "${REMOTE}:${REMOTE_DIR}/.well-known/${f}"
  ssh "$REMOTE" "chmod 644 ${REMOTE_DIR}/.well-known/${f}"
done

# Apache fix — Apache misidentifies .jsonld/.yaml/.md content types by default.
# Write a small .htaccess in .well-known/ to set them correctly. nginx/Caddy
# users handle this via their main server config; we don't touch those.
echo
echo "▸ Detecting target server"
SERVER_HEADER=$(curl -skI "https://$(echo $REMOTE | cut -d@ -f2 | cut -d: -f1)/" 2>/dev/null | grep -i '^server:' | head -1)
if echo "$SERVER_HEADER" | grep -qi 'apache'; then
  echo "  Apache detected — writing .htaccess for correct Content-Types"
  cat <<'HTACCESS' > /tmp/ap_htaccess.tmp
<IfModule mod_mime.c>
  AddType application/ld+json   .jsonld
  AddType application/yaml      .yaml
  AddType text/markdown         .md
  AddType text/plain            .txt
  AddType text/html             .html
</IfModule>
HTACCESS
  scp -q /tmp/ap_htaccess.tmp "${REMOTE}:${REMOTE_DIR}/.well-known/.htaccess"
  ssh "$REMOTE" "chmod 644 ${REMOTE_DIR}/.well-known/.htaccess"
  rm -f /tmp/ap_htaccess.tmp
  echo "  ✓ .htaccess written"
else
  echo "  Non-Apache (likely nginx/Caddy) — Content-Type rules belong in main server config"
  echo "  See instructions/nginx-vps.md for the snippet to paste"
fi

echo
echo "▸ Verification"
DOMAIN=$(echo "$REMOTE" | cut -d@ -f2 | cut -d: -f1)
# If REMOTE includes a port, strip; if user gave hostname like example.com:
DOMAIN_CLEAN=$(echo "$DOMAIN" | sed 's/:.*//')
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
bash "${SCRIPT_DIR}/verify_install.sh" "$DOMAIN_CLEAN" "" --phase files

echo
echo "✓ File deploy complete. Now finish the head-tag part manually:"
echo "  See ${SCRIPT_DIR}/../templates/head-snippet.html"
