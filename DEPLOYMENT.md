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
git clone <repo-url> ~/apps/RGWchart        # RGWchart
git clone <repo-url> ~/apps/RGWheads_oct-quad   # RGWheads (separate repo)
```

---

## 4. Deploy & redeploy — exact commands (both apps)

The two apps are **separate repos / images / containers**:

| App      | Repo dir (server)            | Image           | Container   | Host→ctr port | App file in image            |
|----------|------------------------------|-----------------|-------------|---------------|------------------------------|
| RGWchart | `~/apps/RGWchart`            | `rgw_chart_app` | `rgw_chart` | `3838→3838`   | `/srv/shiny-server/app.R`    |
| RGWheads | `~/apps/RGWheads_oct-quad`   | `rgw_heads_app` | `rgw_heads` | `3839→3838`   | `/app/app.R`                 |

> If your existing containers use other names (e.g. an old `rgwchart_container`),
> either substitute them below or adopt these — the redeploy removes the old
> container anyway. Login is disabled on both apps, so **no password env var is
> needed** (`RGWCHART_PASSWORD` / `APP_PASSWORD` are obsolete).

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
docker run -d --restart unless-stopped --name rgw_chart -p 3838:3838 rgw_chart_app
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
docker run -d --restart unless-stopped --name rgw_heads -p 3839:3838 rgw_heads_app
docker logs -f rgw_heads
```

### C. Redeploy either app after a code change
Same three steps; the `docker rm -f` is the part that's easy to forget:
```bash
# --- RGWchart ---
cd ~/apps/RGWchart && git pull
docker build -t rgw_chart_app .
docker rm -f rgw_chart
docker run -d --restart unless-stopped --name rgw_chart -p 3838:3838 rgw_chart_app

# --- RGWheads ---
cd ~/apps/RGWheads_oct-quad && git pull
docker build -t rgw_heads_app .
docker rm -f rgw_heads
docker run -d --restart unless-stopped --name rgw_heads -p 3839:3838 rgw_heads_app

docker image prune -f                     # optional: reclaim dangling old images
```

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
Only needed if you expose the host ports directly. If a reverse proxy (Caddy) +
Cloudflare front the apps (recommended), open `443` and keep the app ports local.
```bash
sudo ufw allow 3838/tcp        # RGWchart
sudo ufw allow 3839/tcp        # RGWheads
sudo ufw status
```

---

## 6. Accessing the apps
* RGWchart: `http://<server-ip>:3838`
* RGWheads: `http://<server-ip>:3839`

Login is disabled (public access). Behind a proxy the clean URLs are
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
