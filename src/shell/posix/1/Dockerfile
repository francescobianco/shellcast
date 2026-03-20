FROM debian:bookworm-slim
# dash is the most POSIX-conformant shell available on Debian
RUN apt-get update \
    && apt-get install -y --no-install-recommends dash \
    && ln -sf /bin/dash /bin/posix \
    && rm -rf /var/lib/apt/lists/*
LABEL shellcast.shell="posix" shellcast.version="1"
