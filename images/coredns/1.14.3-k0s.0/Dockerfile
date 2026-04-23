ARG BUILDER_IMAGE=docker.io/library/golang:1.26.2-alpine3.23

ARG \
  VERSION=1.14.3 \
  GIT_COMMIT=17fceec6d93fd1dde5ba6888c363f131ff6d647f \
  HASH=137a5da5f49c8eb81e2cc3929d462606146faaa651bd609031d867eb6c73748f

FROM --platform=$BUILDPLATFORM $BUILDER_IMAGE AS build-base
ENV GOTOOLCHAIN=local GOTELEMETRY=off
WORKDIR /go/src/coredns


FROM build-base AS sources
ARG VERSION HASH
RUN --mount=type=tmpfs,target=/tmp \
  set -eu \
  && wget -qO /tmp/sources.tar.gz https://github.com/coredns/coredns/archive/refs/tags/v$VERSION.tar.gz \
  && { echo $HASH /tmp/sources.tar.gz | sha256sum -c -; } || { sha256sum /tmp/sources.tar.gz; exit 1; } \
  && tar xf /tmp/sources.tar.gz --strip-components=1
RUN go mod download


FROM build-base AS build
RUN apk add --no-cache libcap-setcap
ARG TARGETARCH GIT_COMMIT
RUN --mount=from=sources,source=/go/src/coredns,target=/go/src/coredns,ro \
  --mount=from=sources,source=/go/pkg/mod,target=/go/pkg/mod,ro \
  --mount=type=cache,id=coredns-go-cache-$TARGETARCH,target=/root/.cache/go-build \
  --mount=type=tmpfs,target=/tmp \
  --network=none \
  CGO_ENABLED=0 \
  GOARCH=$TARGETARCH \
  go build -mod=readonly -trimpath -buildvcs=false \
    -ldflags="-s -w -X github.com/coredns/coredns/coremain.GitCommit=$GIT_COMMIT" \
    -o /coredns \
  && setcap cap_net_bind_service=+ep /coredns

FROM build-base AS baselayout
ARG SOURCE_DATE_EPOCH
RUN apk add --no-cache ca-certificates-bundle


FROM scratch
LABEL org.opencontainers.image.licenses="Apache-2.0" \
  org.opencontainers.image.source="https://github.com/coredns/coredns"
ARG VERSION

COPY --from=baselayout /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /coredns /coredns
USER 65532:65532

EXPOSE 53 53/udp
ENTRYPOINT ["/coredns"]
