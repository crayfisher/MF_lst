#!/usr/bin/env bash
# Redeploy the RGWchart (MODFLOW listing file viewer) Docker container.
# Pulls the latest code, builds a fresh image, recreates the container, verifies.
# Safe for a first deploy too (the `docker rm -f` no-ops if absent).
#
# Usage:  cd ~/apps/RGWchart && ./redeploy.sh
set -euo pipefail

IMAGE="rgw_chart_app"
CONTAINER="rgw_chart"
HOST_PORT="3838"
CTR_PORT="3838"
APP_PATH="/srv/shiny-server/app.R"

cd "$(dirname "$0")"

echo "==> git pull"
git pull --ff-only || echo "   (not a fast-forward / no remote change — using local code)"

echo "==> docker build -t ${IMAGE} ."
docker build -t "${IMAGE}" .

echo "==> recreate container ${CONTAINER}"
docker rm -f "${CONTAINER}" 2>/dev/null || true
docker run -d --restart unless-stopped --name "${CONTAINER}" \
  -p "127.0.0.1:${HOST_PORT}:${CTR_PORT}" "${IMAGE}"

echo "==> verify"
docker ps --filter "name=${CONTAINER}"
if [ "$(docker exec "${CONTAINER}" grep -c app-beta-badge "${APP_PATH}" || true)" -ge 1 ]; then
  echo "   new code present in container: OK"
else
  echo "   WARNING: expected marker not found in ${APP_PATH} — check the build."
fi

echo "Done -> http://127.0.0.1:${HOST_PORT} on the server (behind Caddy/Cloudflare for the public URL; hard-refresh the browser if it looks old)"
