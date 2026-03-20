#!/bin/sh
# Test: bash-only features that are expected to FAIL on POSIX shells
SHELLCAST="${SHELLCAST:-./target/release/shellcast}"

echo "=== Test: arrays.sh (expect FAIL on dash/sh/posix) ==="
"$SHELLCAST" run tests/fixtures/arrays.sh \
  --ref bash:5 \
  --on bash:5,dash:1,sh:1,posix:1 || true

echo ""
echo "=== Test: string_ops.sh (expect FAIL on dash/sh/posix) ==="
"$SHELLCAST" run tests/fixtures/string_ops.sh \
  --ref bash:5 \
  --on bash:5,dash:1,sh:1,posix:1 || true

echo ""
echo "=== Test: process_substitution.sh (expect FAIL on dash/sh/posix) ==="
"$SHELLCAST" run tests/fixtures/process_substitution.sh \
  --ref bash:5 \
  --on bash:5,dash:1,sh:1,posix:1 || true
