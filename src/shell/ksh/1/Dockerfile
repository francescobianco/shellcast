FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends ksh \
    && rm -rf /var/lib/apt/lists/*
LABEL shellcast.shell="ksh" shellcast.version="1"
