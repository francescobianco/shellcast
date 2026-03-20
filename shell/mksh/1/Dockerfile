FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends mksh curl make \
    && rm -rf /var/lib/apt/lists/*
LABEL shellcast.shell="mksh" shellcast.version="1"
RUN printf '#!/bin/sh\nmksh -c '"'"'echo "mksh $KSH_VERSION"'"'"' 2>/dev/null\n' \
    > /usr/local/bin/shell-version && chmod +x /usr/local/bin/shell-version
