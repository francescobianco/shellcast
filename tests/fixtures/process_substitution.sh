#!/bin/bash
# Process substitution <() is bash/zsh only — will FAIL on dash/posix/sh
while read -r line; do
  echo "Line: $line"
done < <(printf 'foo\nbar\nbaz\n')
