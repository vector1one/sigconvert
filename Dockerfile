FROM python:3.11.4-slim-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends git curl jq nginx
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

WORKDIR /app/
COPY . /app

# disable the nginx default site so it doesn't conflict on port 8000
RUN rm -f /etc/nginx/sites-enabled/default

# download MITRE ATT&CK STIX data once before sigma version setup so each
# venv's diskcache can be seeded from this local file during build
RUN mkdir -p /app/mitre_attack && \
    curl -sLo /app/mitre_attack/enterprise-attack.json \
        "https://github.com/mitre-attack/attack-stix-data/raw/refs/heads/master/enterprise-attack/enterprise-attack.json"

# install backend sigma versions (requires internet at build time)
RUN cd backend && ./setup-sigma-versions.sh

# download all vendor JS/CSS assets so the UI works without internet at runtime
RUN mkdir -p frontend/static/vendor/css frontend/static/vendor/webfonts frontend/static/vendor/js && \
    curl -sLo frontend/static/vendor/js/tailwind.js \
        "https://cdn.tailwindcss.com" && \
    curl -sLo frontend/static/vendor/css/all.min.css \
        "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0-beta3/css/all.min.css" && \
    for f in fa-brands-400.woff2 fa-regular-400.woff2 fa-solid-900.woff2 fa-v4compatibility.woff2 \
              fa-brands-400.ttf  fa-regular-400.ttf  fa-solid-900.ttf  fa-v4compatibility.ttf; do \
        curl -sLo "frontend/static/vendor/webfonts/$f" \
            "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0-beta3/webfonts/$f"; \
    done && \
    curl -sLo frontend/static/vendor/css/tom-select.min.css \
        "https://cdnjs.cloudflare.com/ajax/libs/tom-select/2.2.2/css/tom-select.min.css" && \
    curl -sLo frontend/static/vendor/js/tom-select.complete.js \
        "https://cdnjs.cloudflare.com/ajax/libs/tom-select/2.2.2/js/tom-select.complete.js" && \
    curl -sLo frontend/static/vendor/css/prism-atom-dark.min.css \
        "https://cdnjs.cloudflare.com/ajax/libs/prism-themes/1.9.0/prism-atom-dark.min.css" && \
    curl -sLo frontend/static/vendor/js/prism.min.js \
        "https://cdnjs.cloudflare.com/ajax/libs/prism/1.28.0/prism.min.js" && \
    curl -sLo frontend/static/vendor/js/prism-yaml.min.js \
        "https://cdnjs.cloudflare.com/ajax/libs/prism/1.28.0/components/prism-yaml.min.js" && \
    curl -sLo frontend/static/vendor/js/prism-splunk-spl.min.js \
        "https://cdnjs.cloudflare.com/ajax/libs/prism/1.28.0/components/prism-splunk-spl.min.js" && \
    curl -sLo frontend/static/vendor/js/prism-bash.min.js \
        "https://cdnjs.cloudflare.com/ajax/libs/prism/1.28.0/components/prism-bash.min.js" && \
    curl -sLo frontend/static/vendor/js/prism-kusto.min.js \
        "https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-kusto.min.js" && \
    curl -sLo frontend/static/vendor/js/prism-sql.min.js \
        "https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-sql.min.js" && \
    curl -sLo frontend/static/vendor/js/codejar.js \
        "https://medv.io/codejar/codejar.js" && \
    curl -sLo frontend/static/vendor/js/linenumbers.js \
        "https://medv.io/codejar/linenumbers.js"

# generate nginx.conf + versions.json from the installed sigma version set
RUN chmod +x generate-nginx-conf.sh && ./generate-nginx-conf.sh

EXPOSE 8000
ENTRYPOINT ["./entrypoint.sh"]
