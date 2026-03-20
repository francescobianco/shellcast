FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends dash \
    && rm -rf /var/lib/apt/lists/*
LABEL shellcast.shell="dash" shellcast.version="1"
