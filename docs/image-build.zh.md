# 镜像构建说明

[English](image-build.md) | [中文](image-build.zh.md)

本仓库把 [MHSanaei/3x-ui](https://github.com/MHSanaei/3x-ui) 打成更小的 Docker 镜像。官方镜像是一体机：fail2ban、`x-ui.sh`、地区 geo，以及运行时再拷一遍已经 embed 进二进制的文件。我们只留面板跑起来要用的东西，外加容器内申请证书用的 `acme.sh`。

以 `build_image/Dockerfile` 为准。需要 BuildKit（`# syntax=docker/dockerfile:1`）。

## 为什么要瘦

有用的不是 `docker images` 上那个最小数字，而是攻击面更小、部件更少，以及构建时间不要耗在没人拉的架构的 QEMU 上。

| 效果 | 实际得到什么 |
| --- | --- |
| 攻击面 | 没有 Python、fail2ban、宿主机 iptables。不需要 `NET_ADMIN`。 |
| 运维风险 | 官方入口会写 fail2ban jail，`network_mode: host` 时可能把宿主机锁死。我们不干这个。 |
| 重建成本 | cache mount + `COPY --link` 让 npm / Go / apk 保持热缓存。VPS 用 `amd64` + `arm64` 就够。 |
| 镜像体积 | 本地 `v3.6.0` 在加入 acme 前未压缩大约 220MB，大头是面板二进制、Xray 和 geo。官方还叠了 fail2ban、额外 geo、`mtg` 和 `x-ui.sh`。 |

得不到的：Xray 不会因此变快；若需要 fail2ban 级 IP 封禁或 MTProto（`mtg-multi`），官方镜像仍然更合适。

## 运行时留下什么

运行必需：

- `/app/x-ui`（Vite UI 和 i18n 已 `go:embed`，最终镜像不要再拷 `dist/` 或 `translation/`）
- `bin/xray-linux-${GOARCH}`（`arm` → `arm32`）以及 `geoip.dat` / `geosite.dat`
- `ca-certificates`、`tzdata`

容器内证书：

- `acme.sh` 3.1.4 放在 `/opt/acme.sh`（只读、不被卷挡住）
- `curl`、`openssl`、`socat`（standalone HTTP-01）
- 入口脚本在 `/root/.acme.sh` 为空时 seed，然后启动 `crond`

Xray 和 geo 用 `COPY --from=teddysun/xray` 拿，避免 CI 打 GitHub API 限额，也和以前的镜像一致。

## 故意不打进去的

| 官方有 / 用不上 | 原因 |
| --- | --- |
| fail2ban + `NET_ADMIN` | 面板自己会踢多余设备。防火墙级封禁要改宿主机 iptables，体积大，还可能锁 SSH。需要这个用官方镜像。 |
| `x-ui.sh`（约 3000 行） | systemd / apk / 交互菜单。我们只放约 10 行的 `/usr/bin/x-ui`，转到 `/app/x-ui`，`restart` 对 PID 1 发 `SIGHUP`。 |
| 伊朗 / 俄罗斯 geo | 和 `geoip.dat` / `geosite.dat` 重复。某地区真需要再加。 |
| `mtg-multi` | 只服务 MTProto。 |
| 运行时再拷 `internal/web/translation` | 已经 embed。官方还在拷。 |
| `386`、`s390x`、`arm/v6` | Docker VPS 上几乎没量。CI 应只打 `amd64` + `arm64`。Dockerfile 的 `case` 还留着旧名字，等 CI 收干净再删。 |

## 阶段划分

```
src (scratch)     ADD git tag：3x-ui 和 acme.sh
    │
    ├─ frontend   node:$BUILDPLATFORM，Vite → internal/web/dist
    │
    └─ builder    目标平台上的 golang（CGO / sqlite / musl）
                        │
                        ▼
                   alpine 运行时
```

`FROM scratch` + `ADD https://github.com/org/repo.git#tag`，源码阶段不用装 `git` / `apk`。前端用 `--platform=$BUILDPLATFORM`，Vite 不走 QEMU。Go 阶段留在目标平台，因为 `CGO_ENABLED=1` 必须和运行时 musl 一致。

## 用到的 Dockerfile 语法

先打开 BuildKit frontend：

```dockerfile
# syntax=docker/dockerfile:1
```

### 从 Git `ADD`

```dockerfile
FROM scratch AS src
ADD ${XUI_REPO}#${XUI_VERSION} /src
ADD https://github.com/acmesh-official/acme.sh.git#${ACME_VERSION} /opt/acme.sh
```

BuildKit 按 tag clone，默认丢掉 `.git`。可选钉死：`ADD --checksum=<commit-sha> ...`。我们没加，改 `XUI_VERSION` / `ACME_VERSION` 只动一个 ARG。

### `RUN <<EOF`

用 heredoc，不再写 `&& \`。正文当 shell 脚本跑；`${TZ}`、`${TARGETARCH}` 仍是构建期环境变量 / ARG。

### `COPY --link` 和 `COPY --chmod`

`--link` 做出独立层。前面的 `RUN` 变了，后面的 COPY 不一定作废。`--chmod=755` 在拷贝时就设好权限。

不要把 `dist/` 的 bind 叠在只读的 `/src` bind 上：BuildKit 没法在只读文件系统上 `mkdir` 挂载点。`dist` 用 `COPY --link`。

### `RUN --mount=type=cache`

| 挂载点 | 用途 |
| --- | --- |
| `/root/.npm` | npm 包缓存 |
| `/src/frontend/node_modules` | `node_modules` 不进镜像层 |
| `/go/pkg/mod` | Go module |
| `id=go-build-${TARGETARCH}` | 编译缓存，按架构分开 |
| `/var/cache/apk` | apk 索引和包；要用这个 mount 就不要写 `apk add --no-cache` |

这些缓存在多次构建之间保留，不会打进推出去的镜像。

### `RUN --network=none`

只用于重命名 Xray。这一步不该访问网络。

### `FROM --platform=$BUILDPLATFORM`

只给前端用。Go / CGO 仍在 `$TARGETPLATFORM`。

## 入口脚本要点

`/root/.acme.sh` 是卷。空目录挂上去会挡住镜像里同路径的文件，所以脚本放在 `/opt/acme.sh`，首次启动再安装进卷里。`--install` 必须在 `/opt/acme.sh` 目录下执行，否则 `cp acme.sh` 会失败。

每次都启动 `crond`：容器一重建，root 的 crontab 就没了。`--reloadcmd "x-ui restart"` 对 PID 1 发 `SIGHUP`（`exec` 之后 PID 1 就是面板）。

## 本地构建

```bash
cd build_image
docker build --build-arg XUI_VERSION=v3.6.0 -t x-ui:local .
```

用 `XUI_VERSION` / `ACME_VERSION` 覆盖面板或 acme 的 tag。
