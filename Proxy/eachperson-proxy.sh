#!/usr/bin/env bash
set -euo pipefail

# ── Check if Herd command exists ─────────────────────────────
if ! command -v herd >/dev/null 2>&1; then
    echo "✖ Herd command not found. Please install Laravel Herd before running this script." >&2
    exit 1
fi

NGINX_CONF="/Users/shivapoudel/Library/Application Support/Herd/config/valet/Nginx/eachperson.test"
BACKUP_CONF="${NGINX_CONF}.bak"

# ── Colors ───────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

info()    { echo -e "${CYAN}→${RESET} $*"; }
success() { echo -e "${GREEN}✔${RESET} $*"; }
warn()    { echo -e "${YELLOW}⚠${RESET} $*"; }
error()   { echo -e "${RED}✖${RESET} $*" >&2; exit 1; }

# ── Proxy block to inject ─────────────────────────────────────────────
PROXY_BLOCK='
    set $proxy_host $host;

    location ^~ /dashboard/api/ {
        set $proxy_host qa.eachperson.com;
        proxy_pass https://qa.eachperson.com;
        include "/Users/shivapoudel/Library/Application Support/Herd/config/valet/Drivers/Nginx/proxy-common.conf";
    }

    location ^~ /dashboard/ {
        proxy_pass http://localhost:4200;
        proxy_intercept_errors on;
        error_page 502 503 504 = /;
        include "/Users/shivapoudel/Library/Application Support/Herd/config/valet/Drivers/Nginx/proxy-common.conf";
    }'

# ── Ensure config exists or secure site ─────────────────────────────
if [[ ! -f "$NGINX_CONF" ]]; then
    info "Nginx config not found: $NGINX_CONF"
    info "Securing site using Herd..."
    herd secure eachperson.test >/dev/null 2>&1 || error "Failed to secure site via Herd."
    info "Site secured. Nginx config should now exist."
fi

# ── Skip injection if proxy block already exists ───────────────
if grep -q "set \$proxy_host" "$NGINX_CONF"; then
    warn "Proxy block already exists — skipping injection."
    exit 0
fi

# ── Backup ─────────────────────────────────────────────────────
info "Backing up config to: $BACKUP_CONF"
cp "$NGINX_CONF" "$BACKUP_CONF"

# ── Inject proxy block after `ssl_certificate_key` ─────────────
info "Injecting proxy block after 'ssl_certificate_key'..."
BLOCK_FILE=$(mktemp)
echo "$PROXY_BLOCK" > "$BLOCK_FILE"
TMP_FILE=$(mktemp)

awk -v blockfile="$BLOCK_FILE" '
  /ssl_certificate_key/ && !injected {
    print
    while ((getline line < blockfile) > 0) print line
    close(blockfile)
    injected=1
    next
  }
  { print }
' "$NGINX_CONF" > "$TMP_FILE"

rm -f "$BLOCK_FILE"
mv "$TMP_FILE" "$NGINX_CONF"
success "Proxy block injected."

# ── Restart Herd ─────────────────────────────────────────────
info "Restarting Herd nginx..."
herd restart nginx >/dev/null 2>&1
sleep 2

# ── Validate API via curl ─────────────────────────────────────
API_URL="https://eachperson.test/dashboard/api/user-authentication/login"
EMAIL="s.poudel@eachperson.com"
PASSWORD="Password@123"

info "Testing API proxy via curl..."
RESPONSE=$(curl -s -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" \
  --max-time 5 --location --write-out "HTTPSTATUS:%{http_code}")

HTTP_BODY=$(echo "$RESPONSE" | sed -e 's/HTTPSTATUS\:.*//g')
HTTP_CODE=$(echo "$RESPONSE" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

if [[ "$HTTP_CODE" == "000" ]]; then
    warn "Could not reach $API_URL — check if Herd is running."
    warn "Restoring backup..."
    cp "$BACKUP_CONF" "$NGINX_CONF"
    info "Restarting Herd nginx..."
    herd restart nginx >/dev/null 2>&1
    error "Restored original config."
elif [[ "$HTTP_CODE" == "502" || "$HTTP_CODE" == "503" ]]; then
    warn "Got $HTTP_CODE — nginx routing ok, upstream may be down."
elif [[ "$HTTP_CODE" == "200" ]]; then
    if echo "$HTTP_BODY" | grep -q '"token"'; then
        success "API login succeeded (token found in response)"
        rm -f "$BACKUP_CONF"
        success "Backup removed as test succeeded."
    else
        warn "HTTP 200 but token not found — probably redirected to frontend"
    fi
else
    warn "Got HTTP $HTTP_CODE — proxy may be working but response may not be OK."
fi

success "Done!"
