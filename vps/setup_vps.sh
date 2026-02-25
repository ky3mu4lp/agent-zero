#!/bin/bash
# ============================================================
#  Agent Zero VPS Bootstrap Script
#  Run ONCE on a fresh Hostinger VPS to set everything up.
#  Server: 72.62.128.150 | Domain: agent.nbe.llc
# ============================================================
set -e

REPO_URL="https://github.com/ky3mu4lp/agent-zero.git"
REPO_DIR="/opt/agent-zero"
DOMAIN="agent.nbe.llc"

echo "=============================="
echo " Agent Zero VPS Setup"
echo " Domain: $DOMAIN"
echo "=============================="

# ── Step 1: System update ──────────────────────────────────
echo "[1/7] Updating system..."
apt-get update -qq && apt-get upgrade -y -qq

# ── Step 2: Install Docker ─────────────────────────────────
echo "[2/7] Installing Docker..."
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
else
    echo "  Docker already installed ✅"
fi

# ── Step 3: Install nginx + certbot ───────────────────────
echo "[3/7] Installing nginx + certbot..."
apt-get install -y -qq nginx certbot python3-certbot-nginx git

# ── Step 4: Clone repo ─────────────────────────────────────
echo "[4/7] Cloning Agent Zero repo (backup branch)..."
if [ -d "$REPO_DIR/.git" ]; then
    echo "  Repo already exists, pulling latest..."
    cd "$REPO_DIR" && git pull origin backup
else
    git clone "$REPO_URL" -b backup "$REPO_DIR"
fi

# Create required directories
mkdir -p "$REPO_DIR/usr/workdir/google_integration"
mkdir -p "$REPO_DIR/usr/vault"
mkdir -p "$REPO_DIR/usr/skills"
mkdir -p "$REPO_DIR/usr/knowledge/main"

# ── Step 5: Configure nginx ────────────────────────────────
echo "[5/7] Configuring nginx..."
cp "$REPO_DIR/vps/nginx-agent.nbe.llc.conf" /etc/nginx/sites-available/agent.nbe.llc
ln -sf /etc/nginx/sites-available/agent.nbe.llc /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Temp HTTP-only config for certbot (overrides SSL block temporarily)
cat > /etc/nginx/sites-available/agent.nbe.llc-temp << 'EOF'
server {
    listen 80;
    server_name agent.nbe.llc;
    location / { return 200 "OK"; }
}
EOF
cp /etc/nginx/sites-available/agent.nbe.llc-temp /etc/nginx/sites-enabled/agent.nbe.llc
nginx -t && systemctl reload nginx

# Get SSL cert
echo "  Getting SSL certificate..."
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m admin@nbe.llc --redirect || \
    echo "  ⚠️ Certbot failed — ensure DNS A record points to this server first"

# Restore real nginx config
cp "$REPO_DIR/vps/nginx-agent.nbe.llc.conf" /etc/nginx/sites-enabled/agent.nbe.llc
nginx -t && systemctl reload nginx

# ── Step 6: Start Agent Zero container ────────────────────
echo "[6/7] Starting Agent Zero container..."
cd "$REPO_DIR"
docker compose -f vps/docker-compose.vps.yml pull
docker compose -f vps/docker-compose.vps.yml up -d
echo "  Container started ✅"

# ── Step 7: Set up hourly sync cron ───────────────────────
echo "[7/7] Setting up hourly GitHub sync..."
chmod +x "$REPO_DIR/vps/pull_from_github.sh"

# Add cron (offset 20 min past — Mac pushes at :00, VPS pulls at :20)
CRON_JOB="20 * * * * /bin/bash /opt/agent-zero/vps/pull_from_github.sh >> /var/log/agent-zero-sync.log 2>&1"
(crontab -l 2>/dev/null | grep -v pull_from_github ; echo "$CRON_JOB") | crontab -
echo "  Cron set: hourly at :20 past every hour ✅"

# ── Done ───────────────────────────────────────────────────
echo ""
echo "=============================="
echo " Setup complete! 🎉"
echo "=============================="
echo ""
echo " ⚠️  IMPORTANT: Copy secrets from Mac before testing:"
echo ""
echo "   Run these on your Mac:"
echo "   scp -r ~/Desktop/xrcp/Agent-0/agent-zero/usr/vault/ root@72.62.128.150:/opt/agent-zero/usr/vault/"
echo "   scp ~/Desktop/xrcp/Agent-0/agent-zero/usr/.env root@72.62.128.150:/opt/agent-zero/usr/"
echo "   scp -r ~/Desktop/xrcp/Agent-0/agent-zero/usr/workdir/google_integration/ root@72.62.128.150:/opt/agent-zero/usr/workdir/google_integration/"
echo ""
echo " Then verify:"
echo "   docker ps                          # Container running?"
echo "   curl http://localhost/             # Agent Zero responding?"
echo "   open https://agent.nbe.llc        # UI accessible?"
echo ""
echo " Container logs: docker logs A-01-VPS -f"
echo "=============================="
