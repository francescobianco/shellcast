#!/bin/sh
# Tests whether `local x="value"` silently breaks on set -e.
# POSIX-correct style: declare and assign separately.
myfunc() {
  local result
  result="$(echo hello)"
  echo "$result"
}
myfunc
