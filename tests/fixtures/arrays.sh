#!/bin/bash
# Arrays are bash-specific — will FAIL on dash, sh, posix
fruits=(apple banana cherry)
echo "Count: ${#fruits[@]}"
echo "First: ${fruits[0]}"
echo "All: ${fruits[@]}"
