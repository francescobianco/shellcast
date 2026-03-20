#!/bin/sh
# Demonstrates the shell-level portability trap analogous to macOS's sed -i:
# echo -e is bash/zsh specific — dash and posix sh print "-e line1\nline2" literally.
SHELLCAST="${SHELLCAST:-./target/release/shellcast}"

echo "=== Test: echo -e portability (analogous to macOS sed -i trap) ==="
echo ""
echo "Expected: bash/zsh PASS, dash/posix/sh FAIL"
echo "(they print the literal string '-e line1\\nline2' instead of two lines)"
echo ""
"$SHELLCAST" run tests/fixtures/echo_escape.sh \
  --ref bash:5 \
  --on bash:5,zsh:5,dash:1,sh:1,posix:1 || true

echo ""
echo "=== Test: sed -i in-place (all PASS — this is GNU sed on Linux everywhere) ==="
echo ""
echo "On macOS (BSD sed) EVERY shell would fail here, regardless of shell type."
echo "shellcast cannot reproduce this: Docker always uses GNU sed."
echo ""
"$SHELLCAST" run tests/fixtures/sed_inplace.sh \
  --ref bash:5 \
  --on bash:5,zsh:5,dash:1,sh:1,posix:1 || true
