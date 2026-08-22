# Image build notes

[English](image-build.md) | [中文](image-build.zh.md)

This repo packages [MHSanaei/3x-ui](https://github.com/MHSanaei/3x-ui) as a
smaller Docker image. The official image is an appliance (fail2ban, `x-ui.sh`,
regional geo files, runtime copies of files that are already embedded). We keep
what the panel needs to run, plus `acme.sh` for in-container certificates.

Source of truth: `build_image/Dockerfile`. Requires BuildKit
(`# syntax=docker/dockerfile:1`).

## Why shrink it

The useful part is not “smallest number on `docker images`”. It is a smaller
attack surface, fewer moving parts, and a build that does not spend most of its
time on QEMU for architectures nobody pulls.

| Effect | What we actually get |
| --- | --- |
| Attack surface | No Python, no fail2ban, no host iptables. `NET_ADMIN` is not required. |
| Operational risk | Official entrypoint writes fail2ban jails and can lock the host when using `network_mode: host`. We do not. |
| Rebuild cost | Cache mounts + `COPY --link` keep npm/Go/apk warm. Two arches (`amd64` / `arm64`) is enough for VPS use. |
| Image size | Local `v3.6.0` build was ~220MB uncompressed before acme; most of that is the panel binary, Xray, and geo files. Official adds fail2ban, extra geo, `mtg`, and `x-ui.sh`. |

What we do **not** get: a magic speedup of Xray, or a substitute for the official
image if you need fail2ban IP bans or MTProto (`mtg-multi`).

## What stays in the runtime image

Must run:

- `/app/x-ui` (Vite UI and i18n are `go:embed`’d; do not copy `dist/` or
  `translation/` into the final image)
- `bin/xray-linux-${GOARCH}` (`arm` → `arm32`) plus `geoip.dat` / `geosite.dat`
- `ca-certificates`, `tzdata`

Certificates (in-container):

- `acme.sh` 3.1.4 at `/opt/acme.sh` (immutable)
- `curl`, `openssl`, `socat` (standalone HTTP-01)
- entrypoint seeds `/root/.acme.sh` when that volume is empty, then starts `crond`

Xray and geo come from `teddysun/xray` via `COPY --from`. That avoids GitHub
rate limits in CI and matches our older images.

## What we leave out

| Official / unused | Why |
| --- | --- |
| fail2ban + `NET_ADMIN` | Panel already drops extra devices. Firewall bans need host iptables, extra size, and can lock SSH. Use the official image if you need that. |
| `x-ui.sh` (~3k lines) | systemd / apk / interactive menu. We ship a 10-line `/usr/bin/x-ui` that forwards to `/app/x-ui` and maps `restart` to `SIGHUP` on PID 1. |
| IR / RU geo copies | Duplicate of `geoip.dat` / `geosite.dat`. Add them later if a region needs them. |
| `mtg-multi` | Only for MTProto. |
| Runtime copy of `internal/web/translation` | Already embedded. Official still copies it. |
| `386`, `s390x`, `arm/v6` | Almost no Docker VPS traffic. CI should stay on `amd64` + `arm64`. The Dockerfile `case` still lists old names until CI is trimmed. |

## Stage layout

```
src (scratch)     ADD git tags for 3x-ui and acme.sh
    │
    ├─ frontend   node:$BUILDPLATFORM, Vite → internal/web/dist
    │
    └─ builder    golang on TARGETPLATFORM (CGO/sqlite/musl)
                        │
                        ▼
                   alpine runtime
```

`FROM scratch` + `ADD https://github.com/org/repo.git#tag` means the source
stage has no `git`/`apk`. Frontend uses `--platform=$BUILDPLATFORM` so Vite
does not run under QEMU. The Go stage stays on the target platform because
`CGO_ENABLED=1` must match runtime musl.

## Dockerfile syntax we use

Enable the BuildKit frontend first:

```dockerfile
# syntax=docker/dockerfile:1
```

### `ADD` from Git

```dockerfile
FROM scratch AS src
ADD ${XUI_REPO}#${XUI_VERSION} /src
ADD https://github.com/acmesh-official/acme.sh.git#${ACME_VERSION} /opt/acme.sh
```

BuildKit clones the tag. Default drops `.git`. Optional pin:
`ADD --checksum=<commit-sha> ...` — we skip it so bumping `XUI_VERSION` /
`ACME_VERSION` is one ARG.

### `RUN <<EOF`

Heredoc instead of `&& \`. The body runs as a shell script; `${TZ}` and
`${TARGETARCH}` are still build-time env/ARG.

### `COPY --link` and `COPY --chmod`

`--link` makes a standalone layer. Changing an earlier `RUN` does not always
invalidate later copies. `--chmod=755` sets mode at copy time.

Do not nest a bind mount of `dist/` on top of a read-only bind of `/src`:
BuildKit cannot `mkdir` the overlay target (`read-only file system`). Copy
`dist` with `COPY --link` instead.

### `RUN --mount=type=cache`

| Mount | Purpose |
| --- | --- |
| `/root/.npm` | npm tarball cache |
| `/src/frontend/node_modules` | keeps `node_modules` out of the image layer |
| `/go/pkg/mod` | Go modules |
| `id=go-build-${TARGETARCH}` | compile cache, one per arch |
| `/var/cache/apk` | apk index/packages; do not use `apk add --no-cache` if you want this mount |

Caches survive across builds and do not land in the pushed image.

### `RUN --network=none`

Used only when renaming Xray. That step must not talk to the network.

### `FROM --platform=$BUILDPLATFORM`

Frontend only. Go/CGO stays on `$TARGETPLATFORM`.

## Entrypoint details

`/root/.acme.sh` is a volume. An empty mount hides files baked under that path,
so the script lives at `/opt/acme.sh` and is installed into the volume on first
start (`--install` must run with cwd `/opt/acme.sh`, or `cp acme.sh` fails).

`crond` is started every time: container recreate drops root crontab.
`--reloadcmd "x-ui restart"` sends `SIGHUP` to PID 1 (the panel after `exec`).

## Local build

```bash
cd build_image
docker build --build-arg XUI_VERSION=v3.6.0 -t x-ui:local .
```

Override panel or acme tag with `XUI_VERSION` / `ACME_VERSION`.
