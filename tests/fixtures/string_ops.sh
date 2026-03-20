#!/bin/sh
# String operations — POSIX vs bash extensions
# ${var,,} and ${var^^} are bash-only; will FAIL on dash/posix/sh
word="Hello World"
lower="${word,,}"
upper="${word^^}"
echo "Lower: $lower"
echo "Upper: $upper"
