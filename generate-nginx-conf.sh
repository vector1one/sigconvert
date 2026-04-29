#!/bin/bash
# Runs at Docker build time after setup-sigma-versions.sh.
# Scans installed sigma version dirs, writes:
#   /etc/nginx/conf.d/sigconvert.conf  – per-version proxy_pass blocks
#   /app/frontend/static/versions.json – version list consumed by the JS
set -e

BACKEND_DIR="/app/backend"
FRONTEND_STATIC="/app/frontend/static"
NGINX_CONF="/etc/nginx/conf.d/sigconvert.conf"

# collect x.y.z directories sorted oldest → newest
mapfile -t VERSIONS < <(
    ls -d "$BACKEND_DIR"/*/ 2>/dev/null \
    | xargs -n1 basename \
    | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
    | sort -V
)

if [ ${#VERSIONS[@]} -eq 0 ]; then
    echo "ERROR: no sigma version directories found in $BACKEND_DIR" >&2
    exit 1
fi

LATEST="${VERSIONS[-1]}"

# versions.json – descending order, matches frontend.py behaviour
printf '%s\n' "${VERSIONS[@]}" \
    | jq -R . | jq -s 'reverse' \
    > "$FRONTEND_STATIC/versions.json"

echo "Sigma versions: ${VERSIONS[*]}  (latest → $LATEST)"

# nginx server block
{
cat <<'HEADER'
server {
    listen 8000;
    root /app/frontend;
    index index.html;

    # sigma version list – served from a static JSON file baked at build time
    location = /api/v1/sigma-versions {
        alias /app/frontend/static/versions.json;
        default_type application/json;
    }

HEADER

for VERSION in "${VERSIONS[@]}"; do
    # "1.0.5" → port 8105
    PORT="8${VERSION//.}"
    cat <<BLOCK
    location /api/v1/$VERSION/ {
        proxy_pass http://127.0.0.1:$PORT/api/v1/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

BLOCK
done

LATEST_PORT="8${LATEST//.}"
cat <<FOOTER
    location /api/v1/latest/ {
        proxy_pass http://127.0.0.1:$LATEST_PORT/api/v1/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
FOOTER
} > "$NGINX_CONF"

echo "Nginx config written → $NGINX_CONF"
