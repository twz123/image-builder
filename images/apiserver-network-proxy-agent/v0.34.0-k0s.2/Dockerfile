ARG \
  VERSION=0.34.0 \
  HASH=f338b1db93558121252eec01113a9adcf542d2c23d6c63a092cf9d2ae95317ac \
  DEFAULT_BASEIMAGE=gcr.io/distroless/static-debian12:nonroot@sha256:e8a4044e0b4ae4257efa45fc026c0bc30ad320d43bd4c1a7d5271bd241e386d0 \
  RISCV_BASEIMAGE=ghcr.io/go-riscv/distroless/static-unstable:latest@sha256:0bd27d7ab1f1863abecdebe207870375364fddc1d0ae87179ef176403d04e27b

FROM --platform=$BUILDPLATFORM docker.io/library/golang:1.25.3-alpine3.22 AS build
ENV CGO_ENABLED=0 GOTELEMETRY=off
WORKDIR /go/src/kubernetes-sigs/apiserver-network-proxy

ARG VERSION HASH
RUN --mount=type=cache,id=konnectivity-go-modcache,target=/go/pkg/mod \
  --mount=type=tmpfs,target=/tmp \
  set -e \
  && wget -qO /tmp/src.tar.gz https://github.com/kubernetes-sigs/apiserver-network-proxy/archive/refs/tags/v$VERSION.tar.gz \
  && { printf '%s */tmp/src.tar.gz' "$HASH" | sha256sum -c -; } \
  && tar xf /tmp/src.tar.gz --strip-components=1 \
  && go mod download -x

ARG TARGETARCH
ENV GOARCH=$TARGETARCH
RUN --mount=type=cache,id=konnectivity-go-modcache,target=/go/pkg/mod,ro \
  --mount=type=cache,id=konnectivity-agent-go-cache-$TARGETARCH,target=/root/.cache/go-build \
  --mount=type=tmpfs,target=/tmp \
  --network=none \
  go build \
  -v -mod=readonly -trimpath -buildvcs=false \
  -ldflags "-s -w" \
  ./cmd/agent

FROM $DEFAULT_BASEIMAGE AS final-amd64
FROM $DEFAULT_BASEIMAGE AS final-arm64
FROM $DEFAULT_BASEIMAGE AS final-arm
FROM $RISCV_BASEIMAGE   AS final-riscv64
# nobody:nobody
USER 65534:65534

FROM final-$TARGETARCH
LABEL org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.source="https://github.com/kubernetes-sigs/apiserver-network-proxy"
COPY --from=build /go/src/kubernetes-sigs/apiserver-network-proxy/agent /proxy-agent
ENTRYPOINT ["/proxy-agent"]
