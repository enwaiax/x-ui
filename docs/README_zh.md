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

> x-ui docker 版本

可以通过使用不同的`tag`来使用不同作者的镜像

|                                                            | Tag      | amd64 | arm64 | armv7 | s390x |
| ---------------------------------------------------------- | -------- | ----- | ----- | ----- | ----- |
| [vaxilu/x-ui](https://github.com/vaxilu/x-ui)              | latest   | ✅    | ✅    | ✅    | ✅    |
| [FranzKafkaYu/x-ui](https://github.com/FranzKafkaYu/x-ui)  | alpha-zh | ✅    | ✅    | ❌    | ✅    |
| [X-UI-Unofficial/x-ui](https://github.com/X-UI-Unofficial) | beta     | ✅    | ✅    | ❌    | ✅    |

### 为什么要使用`docker`

- 一致性且能保证环境隔离
- 快速部署
- 保证灵活性和扩展性
- 更好的可移植性
- 低成本
- 方便控制版本
- 安全
- .....

### 对于 x-ui，如果使用 docker

- 无需关心原宿主机的系统，架构，版本
- 不会破坏原系统，如果不想使用，很方便就能完全干净的卸载
- 部署方便且容易升级

### 如何使用

#### 前提：安装好 docker

使用官方一键脚本

```bash
curl -sSL https://get.docker.com/ | sh
```

#### 运行你的容器

##### 使用 [vaxilu/x-ui](https://github.com/vaxilu/x-ui) 版本的

```
mkdir x-ui && cd x-ui
docker run -itd --network=host \
    -v $PWD/db/:/etc/x-ui/ \
    -v $PWD/cert/:/root/cert/ \
    --name x-ui --restart=unless-stopped \
    enwaiax/x-ui
```

注意: 如果希望使用[FranzKafkaYu/x-ui](https://github.com/FranzKafkaYu/x-ui)版本，仅需要讲上述镜像修改为 `enwaiax/x-ui:alpha-zh`

##### 使用 docker-compose 运行

```
mkdir x-ui && cd x-ui
wget https://raw.githubusercontent.com//chasing66/x-ui/main/docker-compose.yml
docker compose up -d
```

#### 如何启用 ssl

- 假设你的 x-ui 端口是 `54321`
- 假设你的 IP 是 `10.10.10.10`
- 假设你的域名是 `xui.example.com`，且已经做好 A 记录解析
- 假设你使用的是 Debian 10+或者 Ubuntu 18+的系统
- 假设你的邮箱是 `xxxx@example.com`

##### 步骤如下

1. 安装必要软件

```bash
sudo apt update
sudo apt install snapd nginx
sudo snap install core
sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
```

2. 新建一个 nginx 配置

```
touch /etc/nginx/conf.d/xui.conf
```

增加以下配置，按照实际情况调整

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

    # 反代websocket
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

3. 检查配置是否正常

```
nginx -t
```

4. 申请证书，按照提示设置

```
certbot --nginx --agree-tos --no-eff-email --email xxxxx@example.com
```

更多细节可以参考 [cerbot](https://certbot.eff.org/)

5. 刷新 nginx 配置生效

```
ngins -s reload
```

6. 配置定时任务

```
sudo certbot renew --dry-run
```
