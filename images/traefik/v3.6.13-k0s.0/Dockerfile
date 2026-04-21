ARG \
  VERSION=3.6.13 \
  HASH=eeaf33e6311ec6ca9fc4e6d6aab95d06f942ff7eb54170b94856569296083521 \
  BUILDIMAGE=docker.io/library/golang:1.26.2-alpine3.23 \
  DISTROLESS_BASEIMAGE=gcr.io/distroless/static-debian13:nonroot@sha256:e3f945647ffb95b5839c07038d64f9811adf17308b9121d8a2b87b6a22a80a39 \
  HPC_BASEIMAGE=mcr.microsoft.com/oss/v2/kubernetes/windows-host-process-containers-base-image:2.0.0@sha256:97a4f486986c5e87e8fcc335f12ee042fcb9265d668e5d9acd75e24ea7873635

FROM --platform=$BUILDPLATFORM $BUILDIMAGE AS sources
WORKDIR /go/src/traefik
ARG VERSION HASH
RUN --mount=type=tmpfs,target=/tmp \
  set -euo pipefail \
  && wget -qO /tmp/sources.tar.gz https://github.com/traefik/traefik/archive/refs/tags/v$VERSION.tar.gz \
  && { echo $HASH /tmp/sources.tar.gz | sha256sum -c -; } || { sha256sum /tmp/sources.tar.gz; exit 1; } \
  && tar xf /tmp/sources.tar.gz --strip-components=1
RUN go mod download


FROM sources AS builder
RUN apk add --no-cache make


FROM builder AS binary
ARG TARGETOS TARGETARCH SOURCE_DATE_EPOCH
RUN --mount=type=cache,id=calico-gocache-$TARGETOS-$TARGETARCH,target=/root/.cache/go-build \
  --network=none \
  `# https://github.com/traefik/traefik/blob/v3.6.13/Makefile#L61` \
  && sed -i 's/${FLAGS\[\*\]}/$(FLAGS)/g' Makefile \
  && `# https://github.com/traefik/traefik/blob/v3.6.13/Makefile#L59` \
  && make --touch generate-webui \
  && make binary \
    GOOS=$TARGETOS \
    GOARCH=$TARGETARCH \
    FLAGS='-mod=readonly -trimpath -buildvcs=false' \
    `# https://github.com/traefik/traefik/blob/v3.6.13/Makefile#L11` \
    DATE=$(date -u -d @$SOURCE_DATE_EPOCH '+%Y-%m-%d_%I:%M:%S%p') \
  && mkdir /out \
  && mv -v dist/*/*/traefik /out/


FROM $DISTROLESS_BASEIMAGE AS final-linux
COPY --from=binary /out /
ENTRYPOINT ["/traefik"]


FROM $HPC_BASEIMAGE AS final-windows
COPY --from=binary /out/traefik /traefik.exe
ENTRYPOINT ["$env:CONTAINER_SANDBOX_MOUNT_POINT\\traefik.exe"]


FROM final-$TARGETOS

ARG VERSION
LABEL org.opencontainers.image.title="Traefik for k0s" \
  org.opencontainers.image.vendor=k0sproject \
  org.opencontainers.image.source=https://github.com/k0sproject/image-builder \
  org.opencontainers.image.licenses=Apache-2.0 \
  org.opencontainers.image.url=https://traefik.io \
  org.opencontainers.image.version="v$VERSION"
