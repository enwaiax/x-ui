# x-ui docker image

<!-- PROJECT SHIELDS -->

[![Docker Pulls][docker-pulls-shield]][docker-pulls-url]
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]

[docker-pulls-shield]: https://img.shields.io/docker/pulls/enwaiax/x-ui.svg?style=flat-square
[docker-pulls-url]: https://hub.docker.com/r/enwaiax/x-ui
[contributors-shield]: https://img.shields.io/github/contributors/enwaiax/x-ui.svg?style=flat-square
[contributors-url]: https://github.com/enwaiax/x-ui/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/enwaiax/x-ui.svg?style=flat-square
[forks-url]: https://github.com/enwaiax/x-ui/network/members
[stars-shield]: https://img.shields.io/github/stars/enwaiax/x-ui.svg?style=flat-square
[stars-url]: https://github.com/enwaiax/x-ui/stargazers
[issues-shield]: https://img.shields.io/github/issues/enwaiax/x-ui.svg?style=flat-square
[issues-url]: https://github.com/enwaiax/x-ui/issues
[license-shield]: https://img.shields.io/github/license/enwaiax/x-ui.svg?style=flat-square
[license-url]: https://github.com/enwaiax/x-ui/blob/main/LICENSE

[English](../README.md) | [中文文档](./README_zh.md)

[MHSanaei/3x-ui](https://github.com/MHSanaei/3x-ui) 的精简 Docker 镜像。

| Tag | 上游 | 状态 |
| --- | --- | --- |
| `3x-ui`、`latest`、`v3.6.0` | [MHSanaei/3x-ui](https://github.com/MHSanaei/3x-ui) | 持续构建 |
| `alpha`、`alpha-zh` | [FranzKafkaYu/x-ui](https://github.com/FranzKafkaYu/x-ui) | 已废弃，不再构建 |
| `beta` | [X-UI-Unofficial](https://github.com/X-UI-Unofficial) | 已废弃，不再构建 |
| 旧 `latest`（vaxilu） | [vaxilu/x-ui](https://github.com/vaxilu/x-ui) | 已废弃；现在的 `latest` 指向 3x-ui |

支持架构：`amd64`、`arm64`、`arm/v7`、`s390x`。

镜像比官方 `ghcr.io/mhsanaei/3x-ui` 更小：不含 fail2ban、`x-ui.sh` 和额外的伊朗/俄罗斯 geo 数据。已内置 `acme.sh`，请把 `/root/.acme.sh` 和 `/root/cert` 做成卷，续期才能在重建容器后还在。

构建怎么瘦、用了哪些 BuildKit 语法、故意没打进去的东西，见 [image-build.zh.md](image-build.zh.md)。

### 如何使用

安装 Docker：

```bash
curl -sSL https://get.docker.com/ | sh
```

#### docker run

```bash
mkdir x-ui && cd x-ui
docker run -itd --network=host \
    -e XRAY_VMESS_AEAD_FORCED=false \
    -v $PWD/db/:/etc/x-ui/ \
    -v $PWD/cert/:/root/cert/ \
    -v $PWD/acme/:/root/.acme.sh/ \
    --name x-ui --restart=unless-stopped \
    enwaiax/x-ui:3x-ui
```

面板默认端口是 `2053`。首次启动账号密码是 `admin` / `admin`，登录后请立刻改掉。

```bash
docker exec x-ui x-ui setting -show true
```

#### docker compose

```bash
mkdir x-ui && cd x-ui
wget https://raw.githubusercontent.com/enwaiax/x-ui/main/docker-compose.yml
docker compose up -d
```

#### 在容器内申请证书

需要 `network_mode: host`，standalone HTTP-01 才能占用 80 端口。

```bash
docker exec -it x-ui acme.sh --issue -d xui.example.com --standalone --httpport 80
docker exec -it x-ui acme.sh --installcert -d xui.example.com \
    --fullchain-file /root/cert/xui.example.com/fullchain.pem \
    --key-file /root/cert/xui.example.com/privkey.pem \
    --reloadcmd "x-ui restart"
docker exec x-ui x-ui cert \
    -webCert /root/cert/xui.example.com/fullchain.pem \
    -webCertKey /root/cert/xui.example.com/privkey.pem
```

首次启动后 `acme.sh` 在 `/root/.acme.sh/acme.sh`。不在 `PATH` 里就用这个路径。

#### 用宿主机 nginx 反代 SSL

假设：

- 面板端口是 `2053`
- 域名 `xui.example.com` 已做好 A 记录
- Debian 12+ 或 Ubuntu 22+
- 邮箱是 `xxxx@example.com`

1. 安装 nginx 和 certbot

```bash
sudo apt update
sudo apt install nginx python3-certbot-nginx
```

2. 新建 `/etc/nginx/conf.d/xui.conf`

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name xui.example.com;

    location / {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:2053;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
    }

    location /xray {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Host $http_host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Y-Real-IP $realip_remote_addr;
    }
}
```

3. 检查配置、申请证书并重载

```bash
sudo nginx -t
sudo certbot --nginx --agree-tos --no-eff-email --email xxxxx@example.com
sudo nginx -s reload
sudo certbot renew --dry-run
```

更多细节见 [certbot](https://certbot.eff.org/)
