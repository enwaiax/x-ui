#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
plain='\033[0m'

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    echo -e "${red}Failed to detect schema, use default schema: ${arch}${plain}"
fi

echo "Your CPU arch: ${arch}"

install_x-ui() {
    mkdir -p /go
    cd /go || exit
    last_version=$(curl -Ls "https://api.github.com/repos/FranzKafkaYu/x-ui/releases/latest" |
        grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [[ -z "$last_version" ]]; then
        echo -e "${red}GitHub API limitation, please try it later${plain}"
        exit 1
    fi
    echo -e "x-ui version: ${last_version}, start installation"
    wget -q -N --no-check-certificate \
        -O x-ui-linux-"${arch}".tar.gz \
        https://github.com/FranzKafkaYu/x-ui/releases/download/"${last_version}"/x-ui-linux-"${arch}".tar.gz
    if [[ $? -ne 0 ]]; then
        echo -e "${red}Failed to download x-ui${plain}"
        exit 1
    fi
    tar zxvf x-ui-linux-"${arch}".tar.gz
    chmod +x x-ui/x-ui
}

echo -e "${green}Get x-ui binary file${plain}"
install_x-ui
