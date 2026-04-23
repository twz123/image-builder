ARG BUILDER_IMAGE=docker.io/library/golang:1.26.1-alpine3.23

ARG \
  VERSION=1.14.2 \
  GIT_COMMIT=dd1df4f5db93767a44e37638df44969503b320d2 \
  HASH=ab933ed4f04de3cf377d0ecc8399fa1a6613cecdd7a1c40d90eb0a7471463fdb

FROM --platform=$BUILDPLATFORM $BUILDER_IMAGE AS build-base
ENV GOTOOLCHAIN=local CGO_ENABLED=0 GOTELEMETRY=off
WORKDIR /go/src/coredns
RUN apk add --no-cache ca-certificates-bundle libcap-setcap

FROM build-base AS sources
ARG VERSION HASH
RUN --mount=type=tmpfs,target=/tmp \
  set -eu \
  && wget -qO /tmp/src.tar.gz https://github.com/coredns/coredns/archive/refs/tags/v$VERSION.tar.gz \
  && { printf '%s */tmp/src.tar.gz' "$HASH" | sha256sum -c -; } \
  && tar xf /tmp/src.tar.gz --strip-components=1 \
  && go mod download

FROM build-base AS build
ARG TARGETARCH GIT_COMMIT
ENV GOARCH=$TARGETARCH
RUN --mount=from=sources,source=/go/src/coredns,target=/go/src/coredns,ro \
  --mount=from=sources,source=/go/pkg/mod,target=/go/pkg/mod,ro \
  --mount=type=cache,id=coredns-go-cache-$TARGETARCH,target=/root/.cache/go-build \
  --mount=type=tmpfs,target=/tmp \
  --network=none \
  go build -v -mod=readonly -trimpath -buildvcs=false \
    -ldflags="-s -w -X github.com/coredns/coredns/coremain.GitCommit=$GIT_COMMIT" \
    -o /coredns \
  && setcap cap_net_bind_service=+ep /coredns

FROM scratch
LABEL org.opencontainers.image.licenses="Apache-2.0" \
  org.opencontainers.image.source="https://github.com/coredns/coredns"
ARG VERSION

COPY --from=build /coredns /coredns
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
USER 65532:65532

EXPOSE 53 53/udp
ENTRYPOINT ["/coredns"]
