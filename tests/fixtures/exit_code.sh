#!/bin/sh
# Exit code propagation test
echo "before error"
false
echo "after error (should not appear if set -e is active)"
