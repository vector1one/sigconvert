# sigconverter.io

[![Website](https://img.shields.io/badge/Website-sigconverter.io-blue)](https://sigconverter.io)

A user-friendly converter for Sigma rules, designed to stay in sync with the pySigma project's backends. Inspired by [uncoder.io](https://uncoder.io).

## Key Features

- Easy-to-use interface for Sigma rule conversion
- Supports multiple backends through pySigma
- Continuously updated to stay in sync with pySigma
- Fully self-contained Docker image — works in airgapped / offline environments

---

## Getting Started

### Without Docker

Requirements: `python`, `curl`, `jq`, [`uv`](https://docs.astral.sh/uv/getting-started/installation/)

```bash
cd backend && ./setup-sigma-versions.sh && cd ..
./entrypoint.sh
```

### With Docker

```bash
docker build -t sigconverter:latest .
docker run -d --name sigconverter --restart unless-stopped -p 8000:8000 sigconverter:latest
```

### With Docker Compose

```bash
docker compose up -d
```

Visit [http://localhost:8000](http://localhost:8000).

---

## Airgapped / Offline Deployment

The `offline-nginx` branch produces a fully self-contained image. All Python
dependencies, pySigma backends, plugins, and frontend assets (Tailwind,
PrismJS, Font Awesome, etc.) are baked in at build time. No outbound network
calls are made at runtime.

### Requirements

| Machine | Requirements |
|---|---|
| Build (online) | Docker, git |
| Target (airgapped) | Docker |

---

### Step 1 — Build the image (online machine)

```bash
git clone https://github.com/vector1one/sigconvert.git
cd sigconvert
git checkout offline-nginx

docker build -t sigconverter:$(date +%Y%m%d) .
```

The build will:
- Install the 10 most recent `sigma-cli` releases and all pySigma plugins
- Download all frontend assets
- Generate an nginx config with a proxy route per sigma version

Tag with a date so you can track what is deployed in each environment.

---

### Step 2 — Save the image to a file

```bash
# uncompressed — faster to save, larger file
docker save sigconverter:latest -o sigconverter.tar

# compressed — roughly 40–60% smaller, takes longer
docker save sigconverter:latest | gzip > sigconverter.tar.gz
```

---

### Step 3 — Transfer to the airgapped machine

Use whatever transfer method your environment permits — USB drive, DVD,
one-way data diode, SCP over a jump host, etc.

```bash
# example: copy to a USB drive
cp sigconverter.tar.gz /media/usb/

# example: SCP to a bastion
scp sigconverter.tar.gz user@bastion:/tmp/
```

---

### Step 4 — Load and run on the airgapped machine

```bash
# load
docker load -i sigconverter.tar.gz

# run
docker run -d \
  --name sigconverter \
  --restart unless-stopped \
  -p 8000:8000 \
  sigconverter:20250429
```

Or with Docker Compose — edit `docker-compose.yaml` to replace the `build`
line with the pre-loaded image name, then:

```yaml
services:
  sigconverter:
    image: sigconverter:20250429   # no build: key needed after docker load
    ports:
      - "8000:8000"
    restart: unless-stopped
```

```bash
docker compose up -d
```

---

### Step 5 — Updating to new pySigma versions

New pySigma backends and plugins are released frequently. An update is a full
rebuild — there is no in-place package update inside a running container.

**On the online build machine:**

```bash
cd sigconvert
git pull
git checkout offline-nginx

# --no-cache forces a fresh query to PyPI for the latest sigma-cli releases
docker build --no-cache -t sigconverter:$(date +%Y%m%d) .
```

Save and transfer as in steps 2–3.

**On the airgapped machine:**

```bash
docker stop sigconverter && docker rm sigconverter

docker run -d \
  --name sigconverter \
  --restart unless-stopped \
  -p 8000:8000 \
  sigconverter:20250429        # new date tag

# optional: remove the old image to reclaim disk space
docker rmi sigconverter:20250101
```

### Pinning specific sigma-cli versions

By default `setup-sigma-versions.sh` installs the 10 most recent releases.
To pin a fixed set for fully reproducible builds, edit the script before
building:

```bash
# backend/setup-sigma-versions.sh — replace the curl/jq line with a fixed list
SIGMA_VERSIONS="0.9.6 1.0.5 1.1.3"
```

---

### Quick-reference cheat sheet

```bash
# ONLINE BUILD MACHINE
docker build -t sigconverter:$(date +%Y%m%d) .
docker save sigconverter:$(date +%Y%m%d) | gzip > sigconverter-$(date +%Y%m%d).tar.gz

# AIRGAPPED TARGET MACHINE
docker load -i sigconverter-20250429.tar.gz
docker run -d --name sigconverter --restart unless-stopped -p 8000:8000 sigconverter:20250429

# UPDATE: swap to new image
docker stop sigconverter && docker rm sigconverter
docker run -d --name sigconverter --restart unless-stopped -p 8000:8000 sigconverter:<new-date>
```

---

## Support

For bugs or feature requests, please use the [GitHub issue tracker](https://github.com/magicsword-io/sigconverter.io/issues).

## Contributing

1. Fork the repository
2. Create a new branch for your changes
3. Commit your changes to your branch
4. Push your changes to your fork
5. Open a Pull Request against the upstream repository

## Contributors

- [Jose Enrique Hernandez](https://twitter.com/_josehelps)
- [Nasreddine Bencherchali](https://twitter.com/nas_bench)
- [Kostas](https://twitter.com/Kostastsale)
- [Michael Haag](https://twitter.com/M_haggis)
- [Julian Ortel](https://twitter.com/m3nixx)

## Credits

Based on [sigmaio by M3NIX](https://github.com/M3NIX/sigmaio). Special thanks to [M3NIX](https://twitter.com/m3nixx).
