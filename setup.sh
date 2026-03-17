#!/usr/bin/env bash
# =============================================================================
# setup.sh — Initialize sub2api-docker deployment environment
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()     { error "$*"; exit 1; }

# -----------------------------------------------------------------------------
# 1. Dependency checks
# -----------------------------------------------------------------------------
info "Checking dependencies..."

command -v openssl >/dev/null 2>&1 || die "openssl not found. Please install it first."

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    die "Neither 'docker compose' nor 'docker-compose' found. Please install Docker first."
fi

info "Using compose command: $COMPOSE_CMD"

# -----------------------------------------------------------------------------
# 2. Generate .env from .env.example
# -----------------------------------------------------------------------------
if [[ -f .env ]]; then
    warn ".env already exists — skipping generation. Delete it to regenerate."
else
    info "Generating .env from .env.example..."

    [[ -f .env.example ]] || die ".env.example not found."

    POSTGRES_PASSWORD=$(openssl rand -hex 32)
    JWT_SECRET=$(openssl rand -hex 32)
    TOTP_ENCRYPTION_KEY=$(openssl rand -hex 32)

    sed \
        -e "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${POSTGRES_PASSWORD}|" \
        -e "s|^JWT_SECRET=.*|JWT_SECRET=${JWT_SECRET}|" \
        -e "s|^TOTP_ENCRYPTION_KEY=.*|TOTP_ENCRYPTION_KEY=${TOTP_ENCRYPTION_KEY}|" \
        .env.example > .env

    info ".env created with generated secrets."
fi

# -----------------------------------------------------------------------------
# 3. Create required directories
# -----------------------------------------------------------------------------
info "Creating data directories..."

for dir in data postgres_data redis_data caddy_data caddy_config; do
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        info "  Created: $dir/"
    else
        info "  Exists:  $dir/"
    fi
done

# Caddy needs to write logs inside caddy_data
mkdir -p caddy_data/logs

# -----------------------------------------------------------------------------
# 4. Done — print next steps
# -----------------------------------------------------------------------------
echo ""
echo "============================================================"
echo -e "${GREEN}Setup complete!${NC}"
echo "============================================================"
echo ""
echo "Next steps:"
echo ""
echo "  1. Edit .env and set your domain:"
echo "       DOMAIN=your.domain.com"
echo ""
echo "  2. Make sure port 80 and 443 are open on your firewall,"
echo "     and the domain's DNS A record points to this server."
echo ""
echo "  3. Start the services:"
echo "       $COMPOSE_CMD up -d"
echo ""
echo "  4. Watch Caddy obtain the TLS certificate:"
echo "       $COMPOSE_CMD logs -f caddy"
echo ""
echo "  5. Check the application health:"
echo "       $COMPOSE_CMD logs -f sub2api"
echo "       curl https://\$(grep ^DOMAIN .env | cut -d= -f2)/health"
echo ""
echo "Generated secrets are stored in .env — keep this file safe."
echo ""
