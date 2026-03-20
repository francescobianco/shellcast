FROM alpine:3.19
RUN apk add --no-cache curl
LABEL shellcast.shell="sh" shellcast.version="1"
RUN printf '#!/bin/sh\napk info busybox 2>/dev/null | head -1 | cut -d" " -f1\n' \
    > /usr/local/bin/shellcast-version && chmod +x /usr/local/bin/shellcast-version
