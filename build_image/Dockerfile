# syntax=docker/dockerfile:1

# Minimal 3x-ui image.
#
# Official image (MHSanaei/3x-ui) is a full appliance: fail2ban, bash, curl,
# openssl, x-ui.sh, acme cron, and extra IR/RU geo databases. Frontend and
# translations are already embedded in the Go binary, so those runtime copies
# are unused. This image keeps only what the panel needs to run.

ARG ALPINE_VERSION=3.22
ARG GO_VERSION=1.26
ARG NODE_VERSION=22
ARG XUI_REPO=https://github.com/MHSanaei/3x-ui.git
ARG XUI_VERSION=v3.6.0
ARG ACME_VERSION=3.1.4

# -----------------------------------------------------------------------------
# Source: BuildKit clones the tag directly, no git/apk in this stage.
# -----------------------------------------------------------------------------
FROM scratch AS src
ARG XUI_REPO
ARG XUI_VERSION
ARG ACME_VERSION
ADD ${XUI_REPO}#${XUI_VERSION} /src
ADD https://github.com/acmesh-official/acme.sh.git#${ACME_VERSION} /opt/acme.sh

# -----------------------------------------------------------------------------
# Frontend (Vite). Runs on the build host, not under QEMU.
# -----------------------------------------------------------------------------
FROM --platform=$BUILDPLATFORM node:${NODE_VERSION}-alpine AS frontend
COPY --link --from=src /src /src
WORKDIR /src/frontend
RUN --mount=type=cache,target=/root/.npm \
    --mount=type=cache,target=/src/frontend/node_modules \
    <<EOF
set -eux
npm ci
npm run build
EOF

# -----------------------------------------------------------------------------
# Go panel. Target-platform because CGO/sqlite must match the runtime musl.
# -----------------------------------------------------------------------------
FROM golang:${GO_VERSION}-alpine AS builder
ARG TARGETARCH
RUN --mount=type=cache,target=/var/cache/apk \
    <<EOF
set -eux
apk add build-base gcc
EOF
COPY --link --from=src /src /src
COPY --link --from=frontend /src/internal/web/dist /src/internal/web/dist
WORKDIR /src
ENV CGO_ENABLED=1 \
    CGO_CFLAGS="-D_LARGEFILE64_SOURCE"
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,id=go-build-${TARGETARCH},target=/root/.cache/go-build \
    <<EOF
set -eux
mkdir -p /out
go build -trimpath -ldflags "-s -w" -o /out/x-ui main.go
EOF

# -----------------------------------------------------------------------------
# Runtime
# -----------------------------------------------------------------------------
FROM alpine:${ALPINE_VERSION}

LABEL org.opencontainers.image.authors="https://github.com/enwaiax" \
      org.opencontainers.image.description="Minimal 3x-ui panel image" \
      org.opencontainers.image.source="https://github.com/enwaiax/x-ui"

ENV TZ=Asia/Shanghai \
    XUI_IN_DOCKER=true \
    XUI_MAIN_FOLDER=/app \
    XUI_ENABLE_FAIL2BAN=false

RUN --mount=type=cache,target=/var/cache/apk \
    <<EOF
set -eux
apk add ca-certificates tzdata curl openssl socat
cp /usr/share/zoneinfo/${TZ} /etc/localtime
echo "${TZ}" > /etc/timezone
EOF

WORKDIR /app

COPY --link --from=src /opt/acme.sh /opt/acme.sh
COPY --chmod=755 --link --from=builder /out/x-ui /app/x-ui
COPY --chmod=755 --link docker-entrypoint.sh /usr/bin/docker-entrypoint.sh
COPY --chmod=755 --link x-ui /usr/bin/x-ui
COPY --link --from=teddysun/xray /usr/bin/xray /tmp/xray
COPY --link --from=teddysun/xray /usr/share/xray/ /app/bin/

# 3x-ui looks up bin/xray-linux-${GOARCH}, except GOARCH=arm -> arm32.
ARG TARGETARCH
RUN --network=none <<EOF
set -eux
case "${TARGETARCH}" in
  amd64) fname=amd64 ;;
  arm64) fname=arm64 ;;
  arm) fname=arm32 ;;
  386) fname=386 ;;
  s390x) fname=s390x ;;
  *) echo "unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;;
esac
mv /tmp/xray "/app/bin/xray-linux-${fname}"
chmod +x "/app/bin/xray-linux-${fname}"
EOF

VOLUME ["/etc/x-ui", "/root/.acme.sh", "/root/cert"]
EXPOSE 2053

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD wget -q -T 3 -O /dev/null http://127.0.0.1:2053/ || exit 1

ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["/app/x-ui"]
