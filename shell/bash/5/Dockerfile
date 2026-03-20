FROM bash:5
LABEL shellcast.shell="bash" shellcast.version="5"
RUN apk add --no-cache curl make \
    && printf '#!/bin/sh\nbash --version 2>&1 | head -1\n' > /usr/local/bin/shell-version \
    && chmod +x /usr/local/bin/shell-version
