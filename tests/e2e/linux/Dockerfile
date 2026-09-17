FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive

RUN <<EOF
set -eux
apt-get update
apt-get install --assume-yes \
    curl \
    git \
    golang \
    libglu1-mesa \
    unzip \
    zip
EOF

COPY metadata.lua /e2e/metadata.lua
COPY hooks /e2e/hooks
COPY lib /e2e/lib
COPY tests/e2e/linux /e2e/tests/e2e/linux

ENTRYPOINT ["bash"]
CMD ["/e2e/tests/e2e/linux/run.sh"]
