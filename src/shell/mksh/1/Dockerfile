FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends mksh \
    && rm -rf /var/lib/apt/lists/*
LABEL shellcast.shell="mksh" shellcast.version="1"
