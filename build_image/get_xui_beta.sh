#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
plain='\033[0m'

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="x86_64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="aarch64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
elif [[ $arch == "riscv64" ]]; then
    arch="riscv64"
else
    exit 1
fi

echo "Your CPU arch: ${arch}"

install_x-ui() {
    mkdir -p /go
    cd /go || exit
    last_version=$(curl -Ls "https://api.github.com/repos/X-UI-Unofficial/release/releases/latest" \
        | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [[ -z "$last_version" ]]; then
        echo -e "${red}GitHub API limitation, please try it later${plain}"
        exit 1
    fi
    echo -e "x-ui version: ${last_version}, start installation"
    wget -q -N --no-check-certificate \
        -O x-ui-linux-${arch}.tar.gz \
        https://github.com/X-UI-Unofficial/release/releases/download/"${last_version}"/x-ui-linux-${arch}.tar.gz
    if [[ $? -ne 0 ]]; then
        echo -e "${red}Failed to download x-ui${plain}"
        exit 1
    fi
    tar zxvf x-ui-linux-${arch}.tar.gz
    cd x-ui || exit
    chmod +x x-ui bin/xray-linux-${arch}
    if [[ $arch == "aarch64" || $arch == "arm64" ]]; then
        mv bin/xray-linux-aarch64 bin/xray-linux-arm64
    elif [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
        mv bin/xray-linux-x86_64 bin/xray-linux-amd64
    fi
}

echo -e "${green}Get x-ui binary file${plain}"
install_x-ui