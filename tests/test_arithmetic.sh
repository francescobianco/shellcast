#!/bin/sh
# Test: POSIX arithmetic should match across all shells
SHELLCAST="${SHELLCAST:-./target/release/shellcast}"

echo "=== Test: arithmetic.sh (expect all PASS) ==="
"$SHELLCAST" run tests/fixtures/arithmetic.sh \
  --ref bash:5 \
  --on bash:5,dash:1,sh:1,posix:1,zsh:5
