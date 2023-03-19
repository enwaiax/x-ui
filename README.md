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
[contributors-shield]: https://img.shields.io/github/contributors/chasing66/x-ui.svg?style=flat-square
[contributors-url]: https://github.com/Chasing66/x-ui/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/chasing66/x-ui.svg?style=flat-square
[forks-url]: https://github.com/Chasing66/x-ui/network/members
[stars-shield]: https://img.shields.io/github/stars/chasing66/x-ui.svg?style=flat-square
[stars-url]: https://github.com/Chasing66/x-ui/stargazers
[issues-shield]: https://img.shields.io/github/issues/chasing66/x-ui.svg?style=flat-square
[issues-url]: https://github.com/Chasing66/x-ui/issues
[license-shield]: https://img.shields.io/github/license/Chasing66/x-ui.svg?style=flat-square
[license-url]: https://github.com/Chasing66/x-ui/blob/main/LICENSE

[English](README.md) | [中文文档](./docs/README_zh.md)

> x-ui in docker version

You could selecet your perfer one by changing the docker image tag

|                                                            | Tag    | amd64 | arm64 | armv7 | s390x |
| ---------------------------------------------------------- | ------ | ----- | ----- | ----- | ----- |
| [vaxilu/x-ui](https://github.com/vaxilu/x-ui)              | latest | ✅    | ✅    | ✅    | ✅    |
| [FranzKafkaYu/x-ui](https://github.com/FranzKafkaYu/x-ui)  | alpha  | ✅    | ✅    | ❌    | ✅    |
| [X-UI-Unofficial/x-ui](https://github.com/X-UI-Unofficial) | beta   | ✅    | ✅    | ❌    | ✅    |

### Why Should You Use Docker

- Consistent & Isolated Environment
- Rapid Application Deployment
- Ensures Scalability & Flexibility
- Better Portability
- Cost-Effective
- In-Built Version Control System
- Security
- .....

### For this project, if you use docker

- You don't need to concern yourself with operating systems, architectures and other issues.
- You will never ruin your Linux server. If you don't want to use it, you can stop or remove it from your environment exactly.
- Last but not least, you can easily deploy and upgrade

### Hot to use it

#### Pre-condition, Docker is installed

Use the official one-key script

```bash
curl -sSL https://get.docker.com/ | sh
```

#### Start you container

##### You could use the pre-build docker image enwaiax/xuiplus

```
mkdir x-ui && cd x-ui
docker run -itd --network=host \
    -v $PWD/db/:/etc/x-ui/ \
    -v $PWD/cert/:/root/cert/ \
    --name x-ui --restart=unless-stopped \
    enwaiax/x-ui
```

Note: If you want to use [FranzKafkaYu/x-ui](https://github.com/FranzKafkaYu/x-ui), change the image as `enwaiax/x-ui:alpha`

##### Or you could use docker compose to start it

```
mkdir x-ui && cd x-ui
wget https://raw.githubusercontent.com/chasing66/x-ui/main/docker-compose.yml
docker compose up -d
```

#### How to enable ssl to your x-ui panel

This part describe how to enable ssl.

- Suppose your x-ui port is `54321`
- Suppose your IP is `10.10.10.10`
- Suppose your domain is `xui.example.com` and you have set the A recode in cloudflare
- Suppose you are using Debian 10+ or Ubuntu 18+ system
- Suppose your email is `xxxx@example.com`

##### Steps as below

1. Install nginx and python3-certbot-nginx

```bash
sudo apt update
sudo apt install python3-certbot-nginx
```

2. Add new nging configurtion

```
touch /etc/nginx/conf.d/xui.conf
```

Add below to the file. Adjust appropriately to your own situation.

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name xui.example.com;

    location / {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:54321;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
    }

    # This part desribe how to reverse websockt proxy
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

3. Check yout conf is OK

```
nginx -t
```

4. Get cert

```
certbot --nginx --agree-tos --no-eff-email --email xxxxx@example.com
```

For more details, refer to [cerbot](https://certbot.eff.org/)

5. Reload nginx config

```
nginx -s reload
```

6. Test automatic renewal

```
sudo certbot renew --dry-run
```

Note: Default credentials

Username: `admin`

Password: `admin`
