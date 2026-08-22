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

[English](README.md) | [中文文档](./docs/README_zh.md)

Minimal Docker image for [MHSanaei/3x-ui](https://github.com/MHSanaei/3x-ui).

| Tag | Upstream | Status |
| --- | --- | --- |
| `3x-ui`, `latest`, `v3.6.0` | [MHSanaei/3x-ui](https://github.com/MHSanaei/3x-ui) | Built |
| `alpha`, `alpha-zh` | [FranzKafkaYu/x-ui](https://github.com/FranzKafkaYu/x-ui) | Deprecated, no longer built |
| `beta` | [X-UI-Unofficial](https://github.com/X-UI-Unofficial) | Deprecated, no longer built |
| old `latest` (vaxilu) | [vaxilu/x-ui](https://github.com/vaxilu/x-ui) | Deprecated; `latest` now tracks 3x-ui |

Supported architectures: `amd64`, `arm64`, `arm/v7`, `s390x`.

This image is smaller than the official `ghcr.io/mhsanaei/3x-ui` image. It omits fail2ban, `x-ui.sh`, and extra IR/RU geo files. `acme.sh` is bundled; persist `/root/.acme.sh` and `/root/cert` so renewals survive recreation.

How the image is built, which BuildKit syntax we use, and what we left out: [docs/image-build.md](docs/image-build.md) ([中文](docs/image-build.zh.md)).

### How to use it

Install Docker:

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

The panel listens on `2053` by default. First-run credentials are `admin` / `admin`; change them after login.

```bash
docker exec x-ui x-ui setting -show true
```

#### docker compose

```bash
mkdir x-ui && cd x-ui
wget https://raw.githubusercontent.com/enwaiax/x-ui/main/docker-compose.yml
docker compose up -d
```

#### Issue a certificate inside the container

`network_mode: host` is required so standalone HTTP-01 can bind port 80.

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

`acme.sh` is a symlink created on first start at `/root/.acme.sh/acme.sh`. If the command is not on `PATH`, use that path.

#### How to enable SSL with nginx on the host

Assumptions:

- Panel port is `2053`
- Domain `xui.example.com` already has an A record
- Debian 12+ or Ubuntu 22+
- Email `xxxx@example.com`

1. Install nginx and certbot

```bash
sudo apt update
sudo apt install nginx python3-certbot-nginx
```

2. Create `/etc/nginx/conf.d/xui.conf`

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

3. Check, issue a cert, and reload

```bash
sudo nginx -t
sudo certbot --nginx --agree-tos --no-eff-email --email xxxxx@example.com
sudo nginx -s reload
sudo certbot renew --dry-run
```

More details: [certbot](https://certbot.eff.org/)

## Sponsor

[![Powered by DartNode](https://dartnode.com/branding/DN-Open-Source-sm.png)](https://dartnode.com "Powered by DartNode - Free VPS for Open Source")
