# https://github.com/projectcalico/calico/blob/v3.29.7/kube-controllers/Dockerfile

ARG \
  VERSION=3.29.7 \
  HASH=d60fd083ad0279a4bd20109d01689e4eecb7a5e8c6d5e8be2b1718e6057f85e9

FROM --platform=$BUILDPLATFORM docker.io/library/golang:1.25.6-alpine3.23 AS builder

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
    -ldflags "-s -w -X main.VERSION=v$VERSION" \
    -o /out/usr/bin/kube-controllers \
    ./kube-controllers/cmd/kube-controllers \
  && go build \
    -mod=readonly -trimpath -buildvcs=false \
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
