FROM alpine:3.19
RUN apk add --no-cache zsh curl make
LABEL shellcast.shell="zsh" shellcast.version="5"
RUN printf '#!/bin/sh\nzsh --version 2>&1 | head -1\n' > /usr/local/bin/shellcast-version \
    && chmod +x /usr/local/bin/shellcast-version
