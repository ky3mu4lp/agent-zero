# VPS Deployment Files

This folder contains everything needed to deploy Agent Zero on the Hostinger VPS.

## Files

| File                       | Purpose                                                |
| -------------------------- | ------------------------------------------------------ |
| `setup_vps.sh`             | **Run once** on VPS — installs everything from scratch |
| `docker-compose.vps.yml`   | Docker container config for VPS                        |
| `pull_from_github.sh`      | Hourly sync: GitHub backup branch → VPS                |
| `nginx-agent.nbe.llc.conf` | nginx reverse proxy for agent.nbe.llc                  |

---

## Deployment Steps

### Step 1 — DNS (do this first, takes ~5 min to propagate)

In Hostinger DNS panel, add:

```
A record:  agent  →  72.62.128.150
```

### Step 2 — Run bootstrap on VPS

```bash
ssh root@72.62.128.150
curl -fsSL https://raw.githubusercontent.com/ky3mu4lp/agent-zero/backup/vps/setup_vps.sh | bash
```

Or copy script manually:

```bash
scp vps/setup_vps.sh root@72.62.128.150:/tmp/
ssh root@72.62.128.150 'bash /tmp/setup_vps.sh'
```

### Step 3 — Copy secrets from Mac (run on Mac)

```bash
scp -r ~/Desktop/xrcp/Agent-0/agent-zero/usr/vault/ \
    root@72.62.128.150:/opt/agent-zero/usr/vault/

scp ~/Desktop/xrcp/Agent-0/agent-zero/usr/.env \
    root@72.62.128.150:/opt/agent-zero/usr/

scp -r ~/Desktop/xrcp/Agent-0/agent-zero/usr/workdir/google_integration/ \
    root@72.62.128.150:/opt/agent-zero/usr/workdir/google_integration/
```

### Step 4 — Verify

```bash
# On VPS:
docker ps                     # A-01-VPS running?
curl http://localhost/        # Agent Zero responds?

# From browser:
# https://agent.nbe.llc
# Login: admin / 8273225462Gabylp@
```

---

## Sync Flow (automatic after setup)

```
Mac change
  → GitHub push (hourly at :00)
    → VPS pull (hourly at :20)
      → Container restart (if changes detected)
```

---

## Useful Commands on VPS

```bash
# Container status
docker ps

# Live logs
docker logs A-01-VPS -f

# Manual sync
bash /opt/agent-zero/vps/pull_from_github.sh

# Sync log
tail -f /var/log/agent-zero-sync.log

# Restart container
docker compose -f /opt/agent-zero/vps/docker-compose.vps.yml restart
```
