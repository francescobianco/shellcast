#!/bin/sh
# sed -i in-place editing.
# All shellcast containers run GNU sed on Linux, so -i works identically
# across all shells — this test PASSES everywhere and proves the point:
# the sed -i difference is OS-level (GNU vs BSD sed), NOT shell-level.
#
# On macOS (BSD sed), EVERY shell would fail with:
#   sed: 1: "...": undefined label
# because BSD sed requires: sed -i '' 's/x/y/' file
#
# shellcast cannot detect this — you need to test on a real macOS host
# or add a custom image with BSD sed installed.

tmpfile=$(mktemp)
printf 'hello world\n' > "$tmpfile"
sed -i 's/hello/goodbye/' "$tmpfile"
cat "$tmpfile"
rm -f "$tmpfile"
