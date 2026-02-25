#!/bin/bash
# ============================================================
#  Agent Zero VPS Pull & Sync Script
#  Runs hourly on VPS — pulls latest from GitHub backup branch
#  and restarts the container only if files changed.
# ============================================================
set -e

REPO_DIR="/opt/agent-zero"
COMPOSE_FILE="$REPO_DIR/vps/docker-compose.vps.yml"
LOG_FILE="/var/log/agent-zero-sync.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "--- Sync started ---"
cd "$REPO_DIR"

# Fetch latest from origin
git fetch origin backup 2>&1 | tee -a "$LOG_FILE"

# Check if there are new commits
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/backup)

if [ "$LOCAL" = "$REMOTE" ]; then
    log "Already up to date. No restart needed."
    exit 0
fi

log "Changes detected: $LOCAL → $REMOTE"
git pull origin backup 2>&1 | tee -a "$LOG_FILE"

# Restart the container to pick up new files
log "Restarting Agent Zero container..."
docker compose -f "$COMPOSE_FILE" restart agent-zero 2>&1 | tee -a "$LOG_FILE"

log "Sync complete ✅"
