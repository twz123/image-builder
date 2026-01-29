# https://github.com/projectcalico/calico/blob/v3.29.7/node/Dockerfile.amd64

ARG \
  VERSION=3.29.7 \
  HASH=d60fd083ad0279a4bd20109d01689e4eecb7a5e8c6d5e8be2b1718e6057f85e9 \
  IPSET_VERSION=7.23 \
  IPSET_HASH=5a43c790abf157a55db5a9a22cb5f28a225f5c7969beda81566a2259aa82c9d852979eb805b11b4347f47c6a0c2cc4de6f14e4733bee5b562844422a45fb9dab \
  # https://github.com/projectcalico/calico/blob/v3.29.7/metadata.mk#L36
  BIRD_COMMIT=9111ec3c3ff3e769727a5940d3d829a0be8b5201 \
  BIRD_HASH=5aaf11e2f0ba3c44cdf27746c0b5da631befd67636579ff5e2ac65b144bee0b3 \
  ALPINE_IMAGE=docker.io/library/alpine:3.23.3 \
  BUILDER_IMAGE=docker.io/library/golang:1.25.6-alpine3.23 \
  IPTABLES_WRAPPERS_VERSION=f6ef44b2c449cca8f005b32dea9a4b497202dbef \
  IPTABLES_VERSION=1.8.11

FROM --platform=$BUILDPLATFORM $BUILDER_IMAGE AS builder

ARG VERSION HASH
WORKDIR /go/src/calico
RUN --mount=type=tmpfs,target=/tmp \
  wget -qO /tmp/sources.tar.gz https://github.com/projectcalico/calico/archive/refs/tags/v$VERSION.tar.gz \
  && { echo "$HASH */tmp/sources.tar.gz" | sha256sum -c -; } \
  && tar xf /tmp/sources.tar.gz --strip-components=1
RUN --mount=type=cache,id=calico-node-gomodcache,target=/go/pkg/mod \
  go mod download

ARG TARGETARCH
RUN --mount=type=cache,id=calico-node-gomodcache,target=/go/pkg/mod,ro \
  --mount=type=cache,id=calico-node-gocache-$TARGETARCH,target=/root/.cache/go-build \
  --network=none \
  export GOARCH=$TARGETARCH \
  && export CGO_ENABLED=0 \
  && go build -mod=readonly -trimpath -buildvcs=false -ldflags "-s -w -X main.VERSION=v$VERSION" ./node/cmd/calico-node \
  && go build -mod=readonly -trimpath -buildvcs=false -ldflags "-s -w -X main.VERSION=v$VERSION" ./node/cmd/mountns \
  && chmod u+s mountns

FROM $ALPINE_IMAGE AS ipset
RUN apk add --no-cache \
  build-base pkgconf curl \
  libmnl-dev libmnl-static

ARG IPSET_VERSION IPSET_HASH
RUN curl -sSLo ipset.tar.bz2 "http://ipset.netfilter.org/ipset-$IPSET_VERSION.tar.bz2" \
  && { echo "$IPSET_HASH *ipset.tar.bz2" | sha512sum -c -; } \
  && mkdir -p /src/ipset && tar xf "ipset.tar.bz2" --strip-components=1 -C /src/ipset \
  && rm -- "ipset.tar.bz2"

WORKDIR /src/ipset
RUN printf '#!/usr/bin/env sh\nexec cc -static "$@"\n' >/src/cc-static && chmod +x /src/cc-static
RUN CC=/src/cc-static CFLAGS=-static LDFLAGS=-static ./configure --enable-static --disable-shared --with-kmod=no
RUN make && strip src/ipset
RUN make install
# Just a sanity check that it's not segfaulting
RUN ipset -h


FROM --platform=$BUILDPLATFORM $ALPINE_IMAGE AS bird-sources
ARG BIRD_COMMIT BIRD_HASH
WORKDIR /bird
RUN --mount=type=tmpfs,target=/tmp \
  wget -qO /tmp/sources.tar.gz https://github.com/projectcalico/bird/archive/$BIRD_COMMIT.tar.gz \
  && sha256sum -b /tmp/sources.tar.gz \
  && { echo "$BIRD_HASH */tmp/sources.tar.gz" | sha256sum -c -; } \
  && tar xf /tmp/sources.tar.gz --strip-components=1


FROM $ALPINE_IMAGE AS bird
RUN apk add --no-cache gcc musl-dev make autoconf flex bison linux-headers
ARG TARGETARCH
RUN --mount=from=bird-sources,source=/bird,target=/run/stage/bird,ro \
  --mount=type=tmpfs,target=/build \
  --network=none \
  cp -a /run/stage/bird /build/ \
  && cd /build/bird \
  && ARCH=$TARGETARCH DIST=/dist OBJ=obj ./create_binaries.sh \
  && find /dist/$TARGETARCH/ -type f -maxdepth 1 -exec strip '{}' ';'


# Build iptables
FROM $ALPINE_IMAGE AS iptables
ARG IPTABLES_VERSION

RUN apk add build-base curl pkgconf \
	linux-headers \
	libmnl-dev libmnl-static \
	libnftnl-dev

RUN curl --proto '=https' --tlsv1.2 -L https://www.netfilter.org/projects/iptables/files/iptables-$IPTABLES_VERSION.tar.xz \
	| tar -C / -Jx

ARG TARGET_OS
# -D__UAPI_DEF_ETHHDR is required to build on musl.
# If this CFLAG isn't defined, itpables will define it in include/xtables.h
# and will have a conflict with musl, which defines it in
# /usr/include/netinet/if_ether.h
RUN cd /iptables-$IPTABLES_VERSION && \
  CFLAGS="-Os -D__UAPI_DEF_ETHHDR=0" ./configure --sysconfdir=/etc --enable-static --disable-shared --without-kernel --disable-devel

RUN make -j$(nproc) -C /iptables-$IPTABLES_VERSION LDFLAGS=-all-static
RUN make -j$(nproc) -C /iptables-$IPTABLES_VERSION install

RUN strip /usr/local/sbin/xtables-legacy-multi
RUN strip /usr/local/sbin/xtables-nft-multi
RUN scanelf -Rn /usr/local && file /usr/local/sbin/*

FROM --platform=$BUILDPLATFORM $BUILDER_IMAGE AS iptables-wrapper
RUN apk add --no-cache patch make

ARG IPTABLES_WRAPPER_VERSION=06cad2ec6cb5ed0945b383fb185424c0a67f55eb
ARG IPTABLES_WRAPPER_HASH=fde9ccd22b337fd297180cd21938c0a82030187fc29aabb6800472295d62752a

WORKDIR /go/src/iptables-wrapper
RUN --mount=type=tmpfs,target=/tmp \
  wget -qO /tmp/sources.tar.gz https://github.com/kubernetes-sigs/iptables-wrappers/archive/$IPTABLES_WRAPPER_VERSION.tar.gz \
  && { echo "$IPTABLES_WRAPPER_HASH */tmp/sources.tar.gz" | sha256sum -c -; } \
  && tar xf /tmp/sources.tar.gz --strip-components=1
RUN --mount=type=cache,id=calico-node-gomodcache,target=/go/pkg/mod \
  go mod download

ARG TARGETARCH
RUN --mount=source=files,target=/run/stage/files,ro \
  --mount=type=tmpfs,target=/go/iptables-wrapper/bin \
  --mount=type=cache,id=calico-node-gomodcache,target=/go/pkg/mod,ro \
  --mount=type=cache,id=calico-node-gocache-$TARGETARCH,target=/root/.cache/go-build \
  --network=none \
  set -euo pipefail \
  && patch </run/stage/files/iptables-wrapper.patch \
  && GOARCH="$TARGETARCH" make build \
  && mv bin/iptables-wrapper .

# Build the image based on alpine
FROM $ALPINE_IMAGE
LABEL org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.source="https://github.com/projectcalico/calico"
ARG TARGETARCH

RUN apk add --no-cache bash iputils iproute2 conntrack-tools runit ca-certificates

# Copy the calico-node binary from the builder image
COPY --from=builder /go/src/calico/calico-node /usr/bin/calico-node
COPY --from=builder /go/src/calico/mountns /usr/bin/mountns

COPY --from=ipset /usr/local/sbin/ipset /usr/sbin/ipset
COPY --from=ipset /src/ipset/ChangeLog /usr/share/doc/ipset/ChangeLog

# Copy the config etc filesystem from builder
COPY --from=builder /go/src/calico/node/filesystem/ /
COPY --from=builder /go/src/calico/confd/etc/ /etc/

# Change permissions to make confd templates and output available in /etc/calico
# to all container users.
RUN chgrp -R 0 /etc/calico && \
    chmod -R g=u /etc/calico

COPY --from=bird /dist/$TARGETARCH/* /usr/bin/

# Copy iptables and wrappers
COPY --from=iptables \
  /usr/local/sbin/xtables-* \
  /usr/local/sbin/iptables* \
  /usr/local/sbin/ipt6ables* \
  /sbin/
RUN --mount=from=iptables-wrapper,source=/go/src/iptables-wrapper,target=/run/stage/iptables-wrapper,ro \
  cp -a /run/stage/iptables-wrapper/iptables-wrapper-installer.sh /run/stage/iptables-wrapper/iptables-wrapper / \
  && /iptables-wrapper-installer.sh

RUN echo "hosts: files dns" > /etc/nsswitch.conf

ENV SVDIR=/etc/service/enabled
CMD ["start_runit"]
