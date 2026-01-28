# https://github.com/projectcalico/calico/blob/v3.29.7/node/Dockerfile.amd64

ARG \
  VERSION=3.29.7 \
  HASH=d60fd083ad0279a4bd20109d01689e4eecb7a5e8c6d5e8be2b1718e6057f85e9 \
  IPSET_VERSION=7.23 \
  IPSET_HASH=5a43c790abf157a55db5a9a22cb5f28a225f5c7969beda81566a2259aa82c9d852979eb805b11b4347f47c6a0c2cc4de6f14e4733bee5b562844422a45fb9dab \
  # https://github.com/projectcalico/calico/blob/v3.29.7/metadata.mk#L36
  BIRD_VERSION=v0.3.3-211-g9111ec3c \
  BUILDER_IMAGE=docker.io/library/golang:1.24.11-alpine3.21 \
  IPTABLES_WRAPPERS_VERSION=f6ef44b2c449cca8f005b32dea9a4b497202dbef \
  IPTABLES_VERSION=1.8.11

FROM $BUILDER_IMAGE AS builder

ARG VERSION HASH
RUN wget https://github.com/projectcalico/calico/archive/refs/tags/v$VERSION.tar.gz \
  && { echo "$HASH *v$VERSION.tar.gz" | sha256sum -c -; } \
  && mkdir /go/calico && tar xf "v$VERSION.tar.gz" --strip-components=1 -C /go/calico \
  && rm -- "v$VERSION.tar.gz"

WORKDIR /go/calico
RUN CGO_ENABLED=0 go build -buildvcs=false -v -o calico-node -ldflags "-s -w -X main.VERSION=v$VERSION" ./node/cmd/calico-node && \
  CGO_ENABLED=0 go build -buildvcs=false -v -o mountns -ldflags "-s -w -X main.VERSION=v$VERSION" ./node/cmd/mountns && chmod u+s mountns

# For currently unknown reason, compiling in alpine 3.20 creates binary
# which always segfaults. So we need to compile in alpine 3.19 still.
FROM docker.io/library/alpine:3.21 AS ipset
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

# TODO We should build bird bins from source
FROM docker.io/calico/bird:$BIRD_VERSION-$TARGETARCH$TARGETVARIANT AS bird

# Build iptables
FROM docker.io/library/alpine:3.21 AS iptables
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

FROM $BUILDER_IMAGE AS iptables-wrapper
ARG IPTABLES_WRAPPERS_VERSION
RUN apk add --no-cache git make
RUN git clone https://github.com/kubernetes-sigs/iptables-wrappers.git /iptables-wrappers
RUN cd /iptables-wrappers \
    && git checkout "${IPTABLES_WRAPPERS_VERSION}" \
    && make build \
    && test -x bin/iptables-wrapper \
    && test -x iptables-wrapper-installer.sh

# Build the image based on alpine
FROM docker.io/library/alpine:3.20
LABEL org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.source="https://github.com/projectcalico/calico"
ARG TARGETARCH

RUN apk add --no-cache bash iputils iproute2 conntrack-tools runit ca-certificates

# Copy the calico-node binary from the builder image
COPY --from=builder /go/calico/calico-node /usr/bin/calico-node
COPY --from=builder /go/calico/mountns /usr/bin/mountns

COPY --from=ipset /usr/local/sbin/ipset /usr/sbin/ipset
COPY --from=ipset /src/ipset/ChangeLog /usr/share/doc/ipset/ChangeLog

# Copy the config etc filesystem from builder
COPY --from=builder /go/calico/node/filesystem/ /
COPY --from=builder /go/calico/confd/etc/ /etc/

# Change permissions to make confd templates and output available in /etc/calico
# to all container users.
RUN chgrp -R 0 /etc/calico && \
    chmod -R g=u /etc/calico

COPY --from=bird /bird* /usr/bin/

# Copy iptables and wrappers
COPY --from=iptables /usr/local/sbin/xtables-* /sbin/
COPY --from=iptables /usr/local/sbin/iptables* /sbin/
COPY --from=iptables /usr/local/sbin/ip6tables* /sbin/
COPY --from=iptables-wrapper /iptables-wrappers/bin/iptables-wrapper /
COPY --from=iptables-wrapper /iptables-wrappers/iptables-wrapper-installer.sh /

RUN /iptables-wrapper-installer.sh --no-sanity-check

RUN echo "hosts: files dns" > /etc/nsswitch.conf

ENV SVDIR=/etc/service/enabled
CMD ["start_runit"]
