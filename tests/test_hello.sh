#!/bin/sh
# Test: hello.sh should produce identical output on all POSIX shells
SHELLCAST="${SHELLCAST:-./target/release/shellcast}"
FIXTURE="tests/fixtures/hello.sh"

echo "=== Test: hello.sh (expect all PASS) ==="
"$SHELLCAST" run "$FIXTURE" \
  --ref bash:5 \
  --on bash:5,dash:1,sh:1,posix:1,zsh:5
