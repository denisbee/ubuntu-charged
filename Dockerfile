FROM ubuntu:latest

SHELL ["/bin/bash", "-c", "-o", "pipefail"]

RUN set -eu; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        software-properties-common \
        apt-transport-https \
        build-essential \
        openssl \
        gpg \
        jq \
        make \
        git \
        curl \
        wget \
        openssh-client \
        rsync \
        zip \
        unzip \
        xz-utils \
        pkg-config \
        libssl-dev \
        libcurl4-openssl-dev \
        libjsoncpp-dev \
        snap-; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# Node LTS
RUN set -exu; \
    ARCH=$(uname -m); \
    if [ "${ARCH}" = "x86_64" ]; then ARCH=x64; fi; \
    if [ "${ARCH}" = "aarch64" ]; then ARCH=arm64; fi; \
    VER=$(curl -sL https://nodejs.org/dist/index.tab | cut -f1,10 | grep -Ev '\-$|^version' | sort -Vk1 | tail -n1 | cut -f1); \
    curl -sL --remote-name-all https://nodejs.org/dist/$VER/node-${VER}-linux-${ARCH}.tar.xz https://nodejs.org/dist/${VER}/SHASUMS256.txt.asc; \
    git clone --depth 1 https://github.com/nodejs/release-keys.git && chmod -R go-rwx release-keys; \
    GNUPGHOME=./release-keys/gpg gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc; \
    grep " node-${VER}-linux-${ARCH}.tar.xz\$" SHASUMS256.txt | sha256sum -c - ;\
    tar -xJ -f node-${VER}-linux-${ARCH}.tar.xz -C /usr/local --strip-components=1 --no-same-owner; \
    rm -rf "node-${VER}-linux-${ARCH}.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt release-keys; \
    ln -s /usr/local/bin/node /usr/local/bin/nodejs; \
    npm install -g npm@latest; \
    npm cache clean --force; \
    node --version; \
    npm --version

# Go
ENV PATH="/usr/local/go/bin:${PATH}"
RUN set -eu; \
    ARCH="$(dpkg --print-architecture)"; \
    curl -s "https://go.dev/dl/?mode=json" \
    | jq -r "[ .[] | select(.stable == true) ] | .[].files[] | select(.arch == \"${ARCH}\" and .os == \"linux\" and .kind == \"archive\") | \"\(.sha256) \(.filename)\"" \
    | sort -rVk2 \
    | while read sha file; do \
        curl -sLO "https://go.dev/dl/${file}"; \
        sha256sum -c <<<"$sha $file"; \
        tar -C /usr/local -xf $file --no-same-owner; \
        rm $file; \
        break; \
      done; \
    go version

# uv/python
ENV UV_PYTHON_INSTALL_DIR=/usr/local/share/uv/python
ENV UV_PYTHON_BIN_DIR=/usr/local/bin
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
RUN set -eu; \
    which uv; \
    uv self version; \
    uv python install 3; \
    uv python list

# Powershell
RUN set -eu; \
    ARCH=$(uname -m); \
    if [ "${ARCH}" = x86_64 ]; then ARCH=x64; fi; \
    if [ "${ARCH}" = aarch64 ]; then ARCH=arm64; fi; \
    if [ "${ARCH}" = armv7l ]; then ARCH=arm32; fi; \
    VER=$(curl -sL "https://api.github.com/repos/PowerShell/PowerShell/releases/latest" | jq -r .tag_name); \
    curl -sLo /tmp/powershell.tar.gz "https://github.com/PowerShell/PowerShell/releases/download/$VER/powershell-${VER:1}-linux-${ARCH}.tar.gz"; \
    mkdir -p "/opt/microsoft/powershell/${VER:1:1}"; \
    tar zxf /tmp/powershell.tar.gz -C "/opt/microsoft/powershell/${VER:1:1}"; \
    chmod +x "/opt/microsoft/powershell/${VER:1:1}/pwsh"; \
    ln -s "/opt/microsoft/powershell/${VER:1:1}/pwsh" /usr/bin/pwsh; \
    rm /tmp/powershell.tar.gz; \
    pwsh --version

# Gitea CLI
RUN set -eu; \
    VER=$(curl -sL "https://gitea.com/api/v1/repos/gitea/tea/releases/latest" | jq -r .tag_name); \
    ARCH=$(uname -m); \
    if [ "${ARCH}" = x86_64 ]; then ARCH=amd64; fi; \
    if [ "${ARCH}" = aarch64 ]; then ARCH=arm64; fi; \
    if [ "${ARCH}" = armv7l ]; then ARCH=armv7; fi; \
    curl -sL -o /usr/local/bin/tea "https://dl.gitea.com/tea/${VER:1}/tea-${VER:1}-linux-${ARCH}"; \
    chmod +x /usr/local/bin/tea; \
    tea --version

# GitHub CLI
RUN set -eu; \
    ARCH=$(uname -m); \
    if [ "${ARCH}" = x86_64 ]; then ARCH=amd64; fi; \
    if [ "${ARCH}" = aarch64 ]; then ARCH=arm64; fi; \
    if [ "${ARCH}" = armv7l ]; then ARCH=armv7; fi; \
    VER=$(curl -sL "https://api.github.com/repos/cli/cli/releases/latest" | jq -r .tag_name); \
    apt-get update; \
    curl -sLo /tmp/gh_${VER:1}_linux_${ARCH}.deb https://github.com/cli/cli/releases/download/${VER}/gh_${VER:1}_linux_${ARCH}.deb; \
    apt-get install -y --no-install-recommends /tmp/gh_${VER:1}_linux_${ARCH}.deb; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/gh_${VER:1}_linux_${ARCH}.deb; \
    gh --version

# Docker CLI
RUN set -eux; \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo ${VERSION_CODENAME}) stable" > /etc/apt/sources.list.d/docker.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends docker-ce-cli docker-buildx-plugin docker-compose-plugin; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    docker --version
