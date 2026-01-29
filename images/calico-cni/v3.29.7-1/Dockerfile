# https://github.com/projectcalico/calico/blob/v3.29.2/cni-plugin/Dockerfile

ARG \
  VERSION=3.29.7 \
  HASH=d60fd083ad0279a4bd20109d01689e4eecb7a5e8c6d5e8be2b1718e6057f85e9 \
  # https://github.com/projectcalico/calico/blob/v3.29.7/metadata.mk#L52-L55
  # Calico has FLANNEL_VERSION=main branch and CNI_VERSION=master.
  # v3.29.7 was released 2025-11-20: https://github.com/projectcalico/calico/releases/tag/v3.29.7
  #
  # https://github.com/projectcalico/calico/blob/v3.29.7/cni-plugin/Makefile#L169
  # https://github.com/projectcalico/flannel-cni-plugin/commits/main/?since=2024-09-12&until=2025-11-20
  FLANNEL_VERSION=v1.2.0-flannel2-go1.22.7 \
  #
  # https://github.com/projectcalico/calico/blob/v3.29.7/cni-plugin/Makefile#L150
  # https://github.com/projectcalico/containernetworking-plugins/commits/master/?since=2025-01-27&until=2025-11-20
  CNI_PLUGINS_VERSION=9ffe547cb3b66f80dd32a00fc69a6d0082b55321 \
  CNI_PLUGINS_HASH=97162c06333ba91c1d4ab8085ed4be09a81a45216c594eb3011332c953a501ba

FROM --platform=$BUILDPLATFORM docker.io/library/golang:1.25.6-alpine3.23 AS build-base


FROM build-base AS builder
ARG VERSION HASH
WORKDIR /go/src/calico
RUN --mount=type=tmpfs,target=/tmp \
  wget -qO /tmp/sources.tar.gz https://github.com/projectcalico/calico/archive/refs/tags/v$VERSION.tar.gz \
  && { echo $HASH /tmp/sources.tar.gz | sha256sum -c -; } \
  && tar xf /tmp/sources.tar.gz --strip-components=1
RUN go mod download

ARG TARGETARCH
RUN --mount=type=cache,id=calico-gocache-$TARGETARCH,target=/root/.cache/go-build \
  --network=none \
  export GOARCH=$TARGETARCH \
  && export CGO_ENABLED=0 \
  && go build \
    -mod=readonly -trimpath -buildvcs=false \
    -o /out/ \
    -ldflags "-s -w -X main.VERSION=v$VERSION" \
    ./cni-plugin/cmd/calico ./cni-plugin/cmd/install

RUN set -e \
  && cd /out \
  && ln -s calico calico-ipam


FROM build-base AS flannel-cni-plugin
RUN apk add --no-cache git bash

ARG FLANNEL_VERSION
WORKDIR /go/src/flannel-cni-plugin
RUN git -C .. -c advice.detachedHead=false clone -b $FLANNEL_VERSION https://github.com/projectcalico/flannel-cni-plugin.git
RUN go mod download

ARG TARGETARCH
RUN --mount=type=cache,id=calico-gocache-$TARGETARCH,target=/root/.cache/go-build \
  --network=none \
  GOARCH=$TARGETARCH TAG=$FLANNEL_VERSION EXTRA_LDFLAGS=-s scripts/build_flannel.sh


FROM build-base AS cni-plugins
RUN apk add --no-cache make bash

ARG CNI_PLUGINS_VERSION CNI_PLUGINS_HASH
WORKDIR /go/src/cni-plugins
RUN --mount=type=tmpfs,target=/tmp \
  wget -qO /tmp/sources.tar.gz https://github.com/projectcalico/containernetworking-plugins/archive/$CNI_PLUGINS_VERSION.tar.gz \
  && { echo $CNI_PLUGINS_HASH /tmp/sources.tar.gz | sha256sum -c -; } \
  && tar xf /tmp/sources.tar.gz --strip-components=1

ARG TARGETARCH
RUN --network=none \
  export GOARCH=$TARGETARCH \
  && export CGO_ENABLED=0 \
  && export GOFLAGS='-trimpath -buildvcs=false' \
  && ./build_linux.sh \
    -ldflags "-s -w -X github.com/containernetworking/plugins/pkg/utils/buildversion.BuildVersion=$CNI_PLUGINS_VERSION"


FROM scratch
LABEL org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.source="https://github.com/projectcalico/calico"
COPY --from=builder /out/* /opt/cni/bin/
COPY --from=flannel-cni-plugin /go/src/flannel-cni-plugin/dist/flannel-* /opt/cni/bin/flannel
COPY --from=cni-plugins /go/src/cni-plugins/bin/* /opt/cni/bin/
ENV PATH=/opt/cni/bin
WORKDIR /opt/cni/bin
CMD ["/opt/cni/bin/install"]
