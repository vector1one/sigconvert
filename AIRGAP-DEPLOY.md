# Airgapped Deployment Guide

This guide covers building sigconverter on an internet-connected machine,
transferring the image to an airgapped environment, and keeping it up to date
when new pySigma versions are released.

---

## Requirements

| Machine | Requirements |
|---|---|
| Build (online) | Docker, git |
| Target (airgapped) | Docker |

No other dependencies are needed on the target machine. Everything — Python,
nginx, sigma backends, frontend assets — is baked into the image at build time.

---

## 1. Build the image (online machine)

```bash
git clone https://github.com/vector1one/sigconvert.git
cd sigconvert
git checkout offline-nginx

docker build -t sigconverter:latest .
```

The build will:
- Install the 10 most recent `sigma-cli` versions and all pySigma plugins
- Download all frontend assets (Tailwind, PrismJS, Font Awesome, etc.)
- Generate an nginx config with a proxy route per sigma version
- Produce a single self-contained image (~2–4 GB depending on plugin count)

Tag with a date or version so you can track what is deployed where:

```bash
docker build -t sigconverter:$(date +%Y%m%d) .
```

---

## 2. Save the image to a file

```bash
# uncompressed (faster to save, larger file)
docker save sigconverter:latest -o sigconverter.tar

# compressed (slower to save, roughly 40-60% smaller)
docker save sigconverter:latest | gzip > sigconverter.tar.gz
```

---

## 3. Transfer to the airgapped machine

Use whatever transfer method your environment permits — USB drive, DVD,
one-way data diode, SCP over a jump host, etc.

```bash
# example: copy to a USB drive mounted at /media/usb
cp sigconverter.tar.gz /media/usb/

# example: SCP to a bastion then onward to the target
scp sigconverter.tar.gz user@bastion:/tmp/
```

---

## 4. Load and run on the airgapped machine

```bash
# load from uncompressed tar
docker load -i sigconverter.tar

# load from gzip-compressed tar
docker load -i sigconverter.tar.gz
```

Confirm the image is present:

```bash
docker images sigconverter
```

Run the container:

```bash
docker run -d \
  --name sigconverter \
  --restart unless-stopped \
  -p 8000:8000 \
  sigconverter:latest
```

Open a browser to `http://<host-ip>:8000`. No outbound network calls are made
at runtime.

---

## 5. Updating to new pySigma versions

New pySigma backends and plugins are released frequently. Because everything is
baked into the image at build time, an update is a full rebuild and
re-deployment — there is no in-place package update inside a running container.

### When to update

- A new `sigma-cli` release is available on PyPI
- A pySigma backend or pipeline plugin has been updated
- A new conversion target you need has been added

### How to update

On the **online build machine**:

```bash
cd sigconvert
git pull                          # pick up any project changes
git checkout offline-nginx

docker build --no-cache -t sigconverter:$(date +%Y%m%d) .
```

`--no-cache` forces `setup-sigma-versions.sh` to re-query PyPI for the current
10 latest `sigma-cli` releases and reinstall all plugins fresh.

Save, transfer, and load as in steps 2–4.

On the **airgapped machine**, stop the old container and start the new one:

```bash
docker stop sigconverter
docker rm sigconverter

docker run -d \
  --name sigconverter \
  --restart unless-stopped \
  -p 8000:8000 \
  sigconverter:20250429        # use your new date tag
```

Optionally remove the old image to reclaim disk space:

```bash
docker rmi sigconverter:20250101   # replace with the old tag
```

### Pinning specific sigma-cli versions

By default `setup-sigma-versions.sh` installs the 10 most recent releases.
If you need a specific set of versions, edit the script before building:

```bash
# backend/setup-sigma-versions.sh  – replace the curl/jq line with a fixed list
SIGMA_VERSIONS="0.9.6 1.0.5 1.1.3"
```

This makes the build fully deterministic and reproducible regardless of what
has been published to PyPI since.

---

## Quick-reference cheat sheet

```bash
# --- ONLINE BUILD MACHINE ---

# build
docker build -t sigconverter:$(date +%Y%m%d) .

# save + compress
docker save sigconverter:$(date +%Y%m%d) | gzip > sigconverter-$(date +%Y%m%d).tar.gz

# --- AIRGAPPED TARGET MACHINE ---

# load
docker load -i sigconverter-20250429.tar.gz

# run
docker run -d --name sigconverter --restart unless-stopped -p 8000:8000 sigconverter:20250429

# update: stop old, start new
docker stop sigconverter && docker rm sigconverter
docker run -d --name sigconverter --restart unless-stopped -p 8000:8000 sigconverter:<new-date>
```
