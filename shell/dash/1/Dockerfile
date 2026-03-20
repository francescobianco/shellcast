FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends dash curl \
    && rm -rf /var/lib/apt/lists/*
LABEL shellcast.shell="dash" shellcast.version="1"
RUN printf '#!/bin/sh\ndpkg-query -W dash 2>/dev/null | awk '"'"'{print "dash " $2}'"'"'\n' \
    > /usr/local/bin/shellcast-version && chmod +x /usr/local/bin/shellcast-version
