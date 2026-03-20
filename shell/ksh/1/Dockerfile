FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends ksh curl \
    && rm -rf /var/lib/apt/lists/*
LABEL shellcast.shell="ksh" shellcast.version="1"
RUN printf '#!/bin/sh\nksh --version 2>&1 | head -1 | sed '"'"'s/^[[:space:]]*//'"'"'\n' \
    > /usr/local/bin/shellcast-version && chmod +x /usr/local/bin/shellcast-version
