FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive

# NOTE: no heredoc here. This Dockerfile is built through the daemon's
# classic `POST /build` endpoint via testcontainers-go
# (tests/e2e/linux/e2e_test.go), which does not understand `RUN <<EOF`
# heredocs and silently drops their body. The chained-`;` form below works
# on both the classic builder and BuildKit (`docker build`).
RUN set -o errexit -o nounset -o xtrace; \
    apt-get update; \
    apt-get install --assume-yes \
        curl \
        git \
        golang \
        zip

COPY metadata.lua /e2e/metadata.lua
COPY hooks /e2e/hooks
COPY lib /e2e/lib

# Long-lived container: the Go test (e2e_test.go) drives every phase through
# exec calls, so the main process just idles here.
CMD ["sleep", "infinity"]
