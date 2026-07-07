# RGWchart — Deployment Guide (+ RGWheads)

How to build, run, and redeploy the `RGWchart` (MODFLOW water-budget viewer)
with Docker. **§4 is the exact deploy/redeploy command reference for both
`RGWchart` and `RGWheads`** — the two apps are separate repos, images, and
containers, so each repo's guide documents both.

---

## 1. Prerequisites
On the target server:
* **Docker**
* **Git**
* A firewall (e.g. **UFW**) — see §5.

---

## 2. Architecture (RGWchart)
`RGWchart` is built on **`rocker/shiny-verse`** + **shiny-server**, with a conda
`flopy_env` (Python/flopy via reticulate) added for listing-file parsing. The
Dockerfile copies `app.R` + `scripts/` into `/srv/shiny-server/` and rewrites the
reticulate Python path to `/opt/flopy_env/bin/python`. The app listens on `3838`.

> RGWheads uses a different base (`mambaorg/micromamba`); see that repo's
> `DEPLOYMENT.md` for its architecture/demo details. The deploy commands for
> both apps are in §4 below.

---

## 3. First-time server setup
```bash
git clone git@github.com:crayfisher/MF_lst.git   ~/apps/RGWchart          # RGWchart
git clone git@github.com:crayfisher/MF_heads.git ~/apps/RGWheads_oct-quad # RGWheads
```

> Repos were renamed 2026-06-30: RGWchart = `crayfisher/MF_lst`,
> RGWheads = `crayfisher/MF_heads`. The local server directory names are just a
> convention — keep your existing `~/apps/...` paths if already cloned (only the
> remote URL changed; `git remote set-url origin <new>` if needed).

---

## 4. Deploy & redeploy — exact commands (both apps)

The two apps are **separate repos / images / containers**:

| App      | Repo dir (server)            | Image           | Container   | Host→ctr port          | App file in image            |
|----------|------------------------------|-----------------|-------------|------------------------|------------------------------|
| RGWchart | `~/apps/RGWchart`            | `rgw_chart_app` | `rgw_chart` | `127.0.0.1:3838→3838`  | `/srv/shiny-server/app.R`    |
| RGWheads | `~/apps/RGWheads_oct-quad`   | `rgw_heads_app` | `rgw_heads` | `127.0.0.1:3839→3838`  | `/app/app.R`                 |

> If your existing containers use other names (e.g. an old `rgwchart_container`),
> either substitute them below or adopt these — the redeploy removes the old
> container anyway. Login is disabled on both apps, so there is no in-app auth —
> **binding both host ports to `127.0.0.1`** (never `0.0.0.0`) is what keeps them
> from being reachable directly; only Caddy on the same host can reach them
> (`RGWCHART_PASSWORD` / `APP_PASSWORD` are obsolete either way).

### The one rule that bites everyone
`docker build` makes a **new image**, but a **running container keeps running the
old image** until you remove and recreate it. So a rebuild alone changes nothing
on the live site — you must `docker rm -f <name>` then `docker run …` again. Code
is copied in at build time; there is no live mount.

### A. RGWchart — first deploy
```bash
cd ~/apps/RGWchart
git pull
docker build -t rgw_chart_app .          # NOTE the image name: rgw_chart_app
docker run -d --restart unless-stopped --name rgw_chart -p 127.0.0.1:3838:3838 rgw_chart_app
docker logs -f rgw_chart                  # Ctrl-C once shiny-server is up / no errors
```

### B. RGWheads — first deploy
```bash
cd ~/apps/RGWheads_oct-quad
git pull
# demo/ is gitignored — copy it in BEFORE building (build context, not git,
# carries it). One-time / only when the demo changes. Run from your LOCAL repo:
#   rsync -avz demo/ user@server:~/apps/RGWheads_oct-quad/demo/
docker build -t rgw_heads_app .
docker run -d --restart unless-stopped --name rgw_heads -p 127.0.0.1:3839:3838 rgw_heads_app
docker logs -f rgw_heads
```

### C. Redeploy either app after a code change
Same three steps; the `docker rm -f` is the part that's easy to forget:
```bash
# --- RGWchart ---
cd ~/apps/RGWchart && git pull
docker build -t rgw_chart_app .
docker rm -f rgw_chart
docker run -d --restart unless-stopped --name rgw_chart -p 127.0.0.1:3838:3838 rgw_chart_app

# --- RGWheads ---
cd ~/apps/RGWheads_oct-quad && git pull
docker build -t rgw_heads_app .
docker rm -f rgw_heads
docker run -d --restart unless-stopped --name rgw_heads -p 127.0.0.1:3839:3838 rgw_heads_app

docker image prune -f                     # optional: reclaim dangling old images
```

### C2. One-command redeploy (`redeploy.sh`)
Each repo ships a `redeploy.sh` that runs steps A–C (git pull → build →
`docker rm -f` → run → verify) for that app, so you don't have to remember the
flags or the `rm -f`:
```bash
cd ~/apps/RGWchart        && ./redeploy.sh   # RGWchart
cd ~/apps/RGWheads_oct-quad && ./redeploy.sh # RGWheads (ensure demo/ is present)
```
It's safe for a first deploy too (`docker rm -f` no-ops if the container is absent).

### D. Verify the new code is actually live (when it "still looks old")
```bash
# 1) Is the running container newer than your rebuild?
docker ps                                 # check the CONTAINER's CREATED column
docker images | grep rgw                  # check the IMAGE's CREATED column
#    Container older than the image -> you skipped `docker rm -f` + run (step C).

# 2) Is the new code inside the running container? (look for a known-new string)
docker exec rgw_chart grep -c app-back-btn /srv/shiny-server/app.R   # expect >= 1
docker exec rgw_heads grep -c app-back-btn /app/app.R                # expect >= 1
#    0 -> the build missed your changes: confirm `git pull` ran in the dir you
#         built from (`git log --oneline -1`), and you rebuilt that image.

# 3) Correct in the container but old in the browser -> it's a cache:
#    - hard refresh (Ctrl/Cmd+Shift+R) or an incognito window (Shiny caches JS/CSS)
#    - if the subdomain is proxied by Cloudflare, purge cache (or enable
#      Development Mode briefly)
```

---

## 5. Firewall (UFW)
Not needed for the app ports themselves — both containers are published to
`127.0.0.1` only (§4), so `3838`/`3839` are never exposed on the host's public
interface regardless of firewall rules. Open only what a reverse proxy (Caddy) +
Cloudflare actually need:
```bash
sudo ufw allow 443/tcp
sudo ufw allow 80/tcp          # for ACME HTTP-01 / redirect to 443
sudo ufw status
```
If you ever *do* need to expose `3838`/`3839` directly (e.g. debugging without
Caddy), drop the `127.0.0.1:` prefix from the `-p` flag for that one run **and**
open the matching UFW rule — remember to revert both afterwards.

---

## 6. Accessing the apps
Both containers are bound to `127.0.0.1`, so `http://<server-ip>:3838` /
`:3839` are **not** reachable from outside the server — only Caddy, running on
the same host, can reach them via `localhost:3838`/`localhost:3839`. Login is
disabled (public access), so this is the only thing standing between the app
and the open internet — the public URLs are the proxied hostnames:
`https://lst.crayfisher.com` (chart) and `https://heads.crayfisher.com` (heads) —
see the RGWheads `DEPLOYMENT.md` §6 for the Caddy + Cloudflare setup.

---

## 7. Container admin & troubleshooting
```bash
docker ps                       # status
docker logs rgw_chart           # logs (use rgw_heads for the other app)
docker stop rgw_chart           # stop
docker start rgw_chart          # start
```
To pick up code changes, use the **redeploy** in §4C (stop/start alone does NOT
load new code — the old image is still inside the container).
