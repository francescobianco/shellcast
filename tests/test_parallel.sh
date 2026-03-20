#!/bin/sh
# Test: parallel execution with JSON report output
SHELLCAST="${SHELLCAST:-./target/release/shellcast}"
REPORT="/tmp/shellcast-parallel-report.json"

echo "=== Test: parallel run with JSON report ==="
"$SHELLCAST" run tests/fixtures/hello.sh \
  --ref bash:5 \
  --on bash:5,dash:1,sh:1,posix:1 \
  --parallel \
  --report "$REPORT" || true

echo ""
echo "--- JSON Report ---"
cat "$REPORT"
