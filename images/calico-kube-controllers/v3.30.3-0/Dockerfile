# https://github.com/projectcalico/calico/blob/v3.29.1/kube-controllers/Dockerfile

ARG \
  VERSION=3.30.3 \
  HASH=f24ef6afead1443b816fcfc9a6f9fdadb335a3dfab5255a2e2da2cb4fc3b5e30

FROM --platform=$BUILDPLATFORM docker.io/library/golang:1.24.7-alpine3.21 AS builder

ARG VERSION HASH
RUN --mount=source=patches,target=/run/stage/patches,ro \
  --mount=type=cache,id=calico-kube-controllers-go-modcache,target=/go/pkg/mod \
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
RUN --mount=type=cache,id=calico-kube-controllers-go-modcache,target=/go/pkg/mod,ro \
  --mount=type=cache,id=calico-kube-controllers-go-cache-$TARGETARCH,target=/root/.cache/go-build \
  --mount=type=tmpfs,target=/tmp \
  --network=none \
  go build \
  -v -mod=readonly -trimpath -buildvcs=false \
  -ldflags "-s -w -X main.VERSION=v$VERSION" \
  -o /out/usr/bin/kube-controllers \
  ./kube-controllers/cmd/kube-controllers

RUN --mount=type=cache,id=calico-kube-controllers-go-modcache,target=/go/pkg/mod,ro \
  --mount=type=cache,id=calico-kube-controllers-go-cache-$TARGETARCH,target=/root/.cache/go-build \
  --mount=type=tmpfs,target=/tmp \
  --network=none \
  go build \
    -v -mod=readonly -trimpath -buildvcs=false \
    -ldflags "-s -w -X main.VERSION=v$VERSION" \
    -o /out/usr/bin/check-status \
    ./kube-controllers/cmd/check-status

RUN mkdir /out/licenses && cp -a kube-controllers/LICENSE /out/licenses/
RUN mkdir /out/status && touch /out/status/status.json && chown 999 /out/status/status.json

FROM scratch
LABEL org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.source="https://github.com/projectcalico/calico"
COPY --from=builder /out/ /
USER 999
ENTRYPOINT ["/usr/bin/kube-controllers"]
