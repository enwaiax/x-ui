# x-ui docker image

> x-ui in docker version

You could selecet your perfer one by changing the docker image tag

|                                                           | Tag    | amd64 | arm64 | armv7 | armv6 | s390x |
| --------------------------------------------------------- | ------ | ----- | ----- | ----- | ----- | ----- |
| [vaxilu/x-ui](https://github.com/vaxilu/x-ui)             | latest | ✅    | ✅    | ✅    | ✅    | ✅    |
| [FranzKafkaYu/x-ui](https://github.com/FranzKafkaYu/x-ui) | alpha  | ✅    | ✅    | ❌    | ❌    | ✅    |

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

##### Or you could use docker compose to start it

```
mkdir x-ui && cd x-ui
wget https://raw.githubusercontent.com//chasing66/x-ui/main/docker-compose.yml
docker compose up -d
```

##### Build image local by yourself

Clone this repo

```
cd build_image
docker build -t enwaiax/x-ui .

```

Then start it
