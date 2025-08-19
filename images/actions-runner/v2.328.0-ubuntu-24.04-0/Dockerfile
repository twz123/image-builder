# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Copyright 2025 The actions-runner-controller authors.
# SPDX-FileCopyrightText: 2025 k0s authors

FROM docker.io/library/ubuntu:24.04 AS base

ARG TARGETPLATFORM
ARG RUNNER_VERSION=2.328.0
ARG RUNNER_CONTAINER_HOOKS_VERSION=0.7.0
# Docker and Docker Compose arguments
ARG CHANNEL=stable
ARG DOCKER_VERSION=24.0.7
ARG DOCKER_COMPOSE_VERSION=v2.23.0
ARG RUNNER_USER_UID=1001
ARG DOCKER_GROUP_GID=121

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -y \
    && apt-get install -y software-properties-common \
    && add-apt-repository -y ppa:git-core/ppa \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    dumb-init \
    git \
    jq \
    openssh-client \
    sudo \
    unzip \
    zip \
    && rm -rf /var/lib/apt/lists/*

# Download latest git-lfs version
RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash && \
    apt-get install -y --no-install-recommends git-lfs

RUN adduser --disabled-password --gecos "" --uid $RUNNER_USER_UID runner \
    && groupadd docker --gid $DOCKER_GROUP_GID \
    && usermod -aG sudo runner \
    && usermod -aG docker runner \
    && echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers \
    && echo "Defaults env_keep += \"DEBIAN_FRONTEND\"" >> /etc/sudoers

ENV HOME=/home/runner

ENV RUNNER_ASSETS_DIR=/runnertmp

FROM base AS runner

ARG RUNNER_VERSION
RUN mkdir -p /src \
    && git -C /src clone -c advice.detachedHead=false --revision="refs/tags/v$RUNNER_VERSION" --depth=1 https://github.com/actions/runner.git runner

ARG DOTNETSDK_VERSION=9.0.304
ARG TARGETARCH
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
RUN --mount=type=cache,id=actions-runner-downloads-$TARGETARCH,target=/src/runner/_downloads \
  --mount=type=cache,id=actions-runner-dotnetsdk-$TARGETARCH,target=/src/runner/_dotnetsdk \
  case "${arch:=$TARGETARCH}" in \
  amd64) arch=x64 ;; \
  esac \
  && cd /src/runner/src \
  && sed -Ei 's/^DOTNETSDK_VERSION="[^"]*"/DOTNETSDK_VERSION="'"$DOTNETSDK_VERSION"'"/g' dev.sh \
  && sed -Ei 's/"version": "[^"]*"/"version": "'"$DOTNETSDK_VERSION"'"/g' global.json \
  && ./dev.sh layout Release "linux-$arch" \
  && ./dev.sh package Release "linux-$arch" \
  && install -D "../_package/actions-runner-linux-$arch-$RUNNER_VERSION.tar.gz" /opt/stage/actions-runner.tar.gz \
  && rm -rf ../_layout ../_package

FROM base
RUN --mount=from=runner,source=/opt/stage/actions-runner.tar.gz,target=/run/stage/actions-runner.tar.gz,ro \
    mkdir -p "$RUNNER_ASSETS_DIR" \
    && cd "$RUNNER_ASSETS_DIR" \
    && tar xzf /run/stage/actions-runner.tar.gz \
    && ./bin/installdependencies.sh \
    && mv ./externals ./externalstmp \
    # libyaml-dev is required for ruby/setup-ruby action.
    # It is installed after installdependencies.sh and before removing /var/lib/apt/lists
    # to avoid rerunning apt-update on its own.
    && apt-get install -y libyaml-dev \
    && rm -rf /var/lib/apt/lists/*

ENV RUNNER_TOOL_CACHE=/opt/hostedtoolcache
RUN mkdir /opt/hostedtoolcache \
    && chgrp docker /opt/hostedtoolcache \
    && chmod g+rwx /opt/hostedtoolcache

RUN cd "$RUNNER_ASSETS_DIR" \
    && curl -fLo runner-container-hooks.zip https://github.com/actions/runner-container-hooks/releases/download/v${RUNNER_CONTAINER_HOOKS_VERSION}/actions-runner-hooks-k8s-${RUNNER_CONTAINER_HOOKS_VERSION}.zip \
    && unzip ./runner-container-hooks.zip -d ./k8s \
    && rm -f runner-container-hooks.zip

RUN set -vx; \
    export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && if [ "$ARCH" = "arm64" ]; then export ARCH=aarch64 ; fi \
    && if [ "$ARCH" = "arm" ]; then export ARCH=armhf ; fi \
    && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x86_64 ; fi \
    && curl -fLo docker.tgz https://download.docker.com/linux/static/${CHANNEL}/${ARCH}/docker-${DOCKER_VERSION}.tgz \
    && tar zxvf docker.tgz \
    && install -o root -g root -m 755 docker/docker /usr/bin/docker \
    && rm -rf docker docker.tgz

RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && if [ "$ARCH" = "arm64" ]; then export ARCH=aarch64 ; fi \
    && if [ "$ARCH" = "arm" ]; then export ARCH=armv7 ; fi \
    && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x86_64 ; fi \
    && mkdir -p /usr/libexec/docker/cli-plugins \
    && curl -fLo /usr/libexec/docker/cli-plugins/docker-compose https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-${ARCH} \
    && chmod +x /usr/libexec/docker/cli-plugins/docker-compose \
    && ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/bin/docker-compose \
    && which docker-compose \
    && docker compose version

# We place the scripts in `/usr/bin` so that users who extend this image can
# override them with scripts of the same name placed in `/usr/local/bin`.
COPY entrypoint.sh startup.sh logger.sh graceful-stop.sh update-status /usr/bin/

# Copy the docker shim which propagates the docker MTU to underlying networks
# to replace the docker binary in the PATH.
COPY docker-shim.sh /usr/local/bin/docker

# Configure hooks folder structure.
COPY hooks /etc/arc/hooks/

# Add the Python "User Script Directory" to the PATH
ENV PATH="${PATH}:${HOME}/.local/bin/"
ENV ImageOS=ubuntu24

RUN echo "PATH=${PATH}" > /etc/environment \
    && echo "ImageOS=${ImageOS}" >> /etc/environment

USER runner

ENTRYPOINT ["/bin/bash", "-c"]
CMD ["entrypoint.sh"]
