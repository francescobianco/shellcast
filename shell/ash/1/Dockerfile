FROM alpine:3.19
LABEL shellcast.shell="ash" shellcast.version="1"
RUN printf '#!/bin/sh\napk info busybox 2>/dev/null | head -1 | cut -d" " -f1\n' \
    > /usr/local/bin/shellcast-version && chmod +x /usr/local/bin/shellcast-version
