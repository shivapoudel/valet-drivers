#!/usr/bin/env bash
set -euo pipefail

# ── Colors ─────────────────────────────────────────────────────
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

info()    { printf "${CYAN}→${RESET} %s\n" "$*"; }
success() { printf "${GREEN}✔${RESET} %s\n" "$*"; }
warn()    { printf "${YELLOW}⚠${RESET} %s\n" "$*"; }
error()   { printf "${RED}✖${RESET} %s\n" "$*" >&2; exit 1; }

# ── Configuration ──────────────────────────────────────────────
PROXY_HOST="stag.eachperson.com"
SITE_DOMAIN="eachperson.test"
API_URL="https://$SITE_DOMAIN/dashboard/api/user-authentication/login"
EMAIL="s.poudel@eachperson.com"
PASSWORD="Password@123"

# ── Check Herd installation ────────────────────────────────────
if ! command -v herd >/dev/null 2>&1; then
    error "Herd command not found. Install Laravel Herd first."
fi

# ── Detect platform and set Herd base path ────────────────────
if [[ "$OSTYPE" == "darwin"* ]]; then
    HERD_BASE="$HOME/Library/Application Support/Herd"
elif [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* || "$OSTYPE" == "win32"* ]]; then
    HERD_BASE="$HOME/.config/herd"
elif [[ "$OSTYPE" == "linux-gnu"* ]] && grep -qi microsoft /proc/version 2>/dev/null; then
    HERD_BASE="$HOME/.config/herd"
else
    error "Unsupported platform: $OSTYPE"
fi

info "Platform: $OSTYPE"
info "Herd base: $HERD_BASE"

# ── Nginx config paths ────────────────────────────────────────
NGINX_CONF="$HERD_BASE/config/valet/Nginx/$SITE_DOMAIN"
BACKUP_CONF="${NGINX_CONF}.bak"
PROXY_COMMON="$HERD_BASE/config/valet/Drivers/Nginx/proxy-common.conf"

# ── Ensure site Nginx config exists ───────────────────────────
if [[ ! -f "$NGINX_CONF" ]]; then
    info "Nginx config missing: $NGINX_CONF"
    info "Securing site using Herd..."
    herd secure "$SITE_DOMAIN" >/dev/null 2>&1 || error "Failed to secure site via Herd."
    [[ -f "$NGINX_CONF" ]] || error "Nginx config was not created by Herd"
    info "Site secured. Nginx config should now exist."
fi

# ── Exit early if proxy block already exists ──────────────────
if grep -q "set \$proxy_host \$host;" "$NGINX_CONF"; then
    warn "Proxy block already exists — skipping injection."
    exit 0
fi

# ── Backup Nginx config ───────────────────────────────────────
if [[ ! -f "$BACKUP_CONF" ]]; then
    info "Backing up config to: $BACKUP_CONF"
    cp "$NGINX_CONF" "$BACKUP_CONF"
fi

# ── Inject proxy block into Nginx config ──────────────────────
info "Injecting proxy block..."

PROXY_BLOCK='
    set $proxy_host $host;

    # Runtime DNS resolution
    resolver 8.8.8.8 8.8.4.4 valid=3600s;
    resolver_timeout 5s;

    location ^~ /dashboard/api/ {
        set $proxy_host '"$PROXY_HOST"';
        proxy_ssl_server_name on;
        proxy_ssl_name $proxy_host;
        proxy_pass https://$proxy_host;
        include "'"$PROXY_COMMON"'";
    }

    location ^~ /dashboard/ {
        proxy_pass http://localhost:4200;
        proxy_intercept_errors on;
        error_page 502 503 504 = /;
        include "'"$PROXY_COMMON"'";
    }'

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

# ── Restart Herd services ─────────────────────────────────
info "Restarting Herd services..."
herd restart >/dev/null 2>&1
sleep 2

# ── Validate API via curl ─────────────────────────────────
info "Testing API proxy via curl..."
TMP_RESPONSE=$(mktemp)
trap 'rm -f "$TMP_RESPONSE"' EXIT

set +e
HTTP_CODE=$(curl -sS -o "$TMP_RESPONSE" \
  -w "%{http_code}" \
  -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" \
  --max-time 10 \
  --connect-timeout 5 \
  --location)
CURL_EXIT=$?
set -e

HTTP_CODE=${HTTP_CODE:-000}

if [[ "$HTTP_CODE" == "000" || $CURL_EXIT -ne 0 ]]; then
    warn "Could not reach $API_URL (curl exit: $CURL_EXIT)"
    warn "Restoring backup..."

    if [[ -f "$BACKUP_CONF" ]]; then
        cp "$BACKUP_CONF" "$NGINX_CONF"
        info "Restarting Herd services..."
        herd restart >/dev/null 2>&1
        error "Restored original config."
    else
        error "Backup not found — cannot restore original config."
    fi
elif [[ "$HTTP_CODE" == "502" || "$HTTP_CODE" == "503" ]]; then
    warn "Got $HTTP_CODE — nginx routing ok, upstream may be down."
    success "Proxy configuration applied successfully."
elif [[ "$HTTP_CODE" == "200" ]]; then
    if grep -q '"token"' "$TMP_RESPONSE"; then
        success "API login succeeded (token found)"
        rm -f "$BACKUP_CONF"
        success "Backup removed as login succeeded."
    else
        warn "HTTP 200 but token not found — possible frontend fallback/redirect"
        success "Proxy configuration applied successfully."
    fi
else
    warn "Got HTTP $HTTP_CODE — proxy may be working but response may not be OK."
    success "Proxy configuration applied successfully."
fi

success "Done!"
