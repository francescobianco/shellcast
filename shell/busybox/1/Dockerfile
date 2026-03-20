FROM busybox:1
LABEL shellcast.shell="busybox" shellcast.version="1"
RUN printf '#!/bin/sh\nbusybox 2>&1 | head -1\n' > /bin/shellcast-version \
    && chmod +x /bin/shellcast-version
