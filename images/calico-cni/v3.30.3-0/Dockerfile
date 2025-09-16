# https://github.com/projectcalico/calico/blob/v3.29.2/cni-plugin/Dockerfile

ARG \
  VERSION=3.30.3 \
  HASH=f24ef6afead1443b816fcfc9a6f9fdadb335a3dfab5255a2e2da2cb4fc3b5e30 \
  # https://github.com/projectcalico/calico/blob/v3.30.3/metadata.mk#L55-L58
  # Calico has FLANNEL_VERSION=main branch and CNI_VERSION=master.
  # v3.30.3 was released 2025-08-22: https://github.com/projectcalico/calico/releases/tag/v3.30.3
  #
  # https://github.com/projectcalico/calico/blob/v3.30.3/cni-plugin/Makefile#L169
  # https://github.com/projectcalico/flannel-cni-plugin/commits/main/?since=2024-09-12&until=2025-08-22
  FLANNEL_VERSION=5a977558e9fbbf93ff7ba927847fbca194e02416 \
  #
  # https://github.com/projectcalico/calico/blob/v3.30.3/cni-plugin/Makefile#L150
  # https://github.com/projectcalico/containernetworking-plugins/commits/master/?since=2025-01-27&until=2025-08-22
  CNI_VERSION=9ffe547cb3b66f80dd32a00fc69a6d0082b55321 \
  BUILDER_IMAGE=docker.io/library/golang:1.24.7-alpine3.21

FROM --platform=$BUILDPLATFORM $BUILDER_IMAGE AS builder

ARG VERSION HASH
RUN --mount=source=patches,target=/run/stage/patches,ro \
  --mount=type=cache,id=calico-cni-go-modcache,target=/go/pkg/mod \
  --mount=type=tmpfs,target=/tmp \
  set -e \
  && apk add --no-cache cmd:patch \
  && wget -qO /tmp/src.tar.gz https://github.com/projectcalico/calico/archive/refs/tags/v$VERSION.tar.gz \
  && { printf '%s */tmp/src.tar.gz' "$HASH" | sha256sum -c -; } \
  && mkdir /go/calico \
  && tar xf /tmp/src.tar.gz --strip-components=1 -C /go/calico \
  && for f in /run/stage/patches/*.patch; do patch -d /go/calico -p1 -i "$f"; done \
  && go -C /go/calico mod download -x

WORKDIR /go/calico

ARG TARGETARCH
ENV GOARCH=$TARGETARCH CGO_ENABLED=0
RUN --mount=type=cache,id=calico-cni-go-modcache,target=/go/pkg/mod,ro \
  --mount=type=cache,id=calico-cni-go-cache-$TARGETARCH,target=/root/.cache/go-build \
  --mount=type=tmpfs,target=/tmp \
  --network=none \
  go build \
    -v -mod=readonly -trimpath -buildvcs=false \
    -ldflags "-s -w -X main.VERSION=v$VERSION" \
    -o /out/opt/cni/bin/ \
    ./cni-plugin/cmd/calico

RUN --mount=type=cache,id=calico-cni-go-modcache,target=/go/pkg/mod,ro \
  --mount=type=cache,id=calico-cni-go-cache-$TARGETARCH,target=/root/.cache/go-build \
  --mount=type=tmpfs,target=/tmp \
  --network=none \
  go build \
    -v -mod=readonly -trimpath -buildvcs=false \
    -ldflags "-s -w -X main.VERSION=v$VERSION" \
    -o /out/opt/cni/bin/ \
    ./cni-plugin/cmd/install \
  && cd /out/opt/cni/bin \
  && ln -s calico calico-ipam

FROM $BUILDER_IMAGE AS flannel
ARG FLANNEL_VERSION

RUN apk add --no-cache git make bash
RUN mkdir -p /go/flannel
WORKDIR /go/flannel

RUN git clone --single-branch https://github.com/projectcalico/flannel-cni-plugin.git /go/flannel \
  && git reset --hard $FLANNEL_VERSION

RUN make build_linux

FROM $BUILDER_IMAGE AS cni-bins
ARG CNI_VERSION

RUN apk add --no-cache git make bash
RUN mkdir -p /go/cni
WORKDIR /go/cni

RUN git clone --single-branch https://github.com/projectcalico/containernetworking-plugins.git /go/cni \
  && git reset --hard $CNI_VERSION

RUN GOFLAGS='-buildvcs=false' CGO_ENABLED=0 ./build_linux.sh -x -v -ldflags "-X github.com/containernetworking/plugins/pkg/utils/buildversion.BuildVersion=$(GIT_VERSION)"


FROM scratch
LABEL org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.source="https://github.com/projectcalico/calico"
COPY --from=builder /out/ /
COPY --from=flannel /go/flannel/dist/flannel-* /opt/cni/bin/flannel
COPY --from=cni-bins /go/cni/bin/* /opt/cni/bin/
ENV PATH=/opt/cni/bin
WORKDIR /opt/cni/bin
CMD ["/opt/cni/bin/install"]
