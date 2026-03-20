FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends dash curl make \
    && ln -sf /bin/dash /bin/posix \
    && rm -rf /var/lib/apt/lists/*
LABEL shellcast.shell="posix" shellcast.version="1"
RUN printf '#!/bin/sh\ndpkg-query -W dash 2>/dev/null | awk '"'"'{print "posix/dash " $2}'"'"'\n' \
    > /usr/local/bin/shell-version && chmod +x /usr/local/bin/shell-version
