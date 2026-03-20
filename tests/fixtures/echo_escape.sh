#!/bin/sh
# echo -e is a bash/zsh extension — POSIX sh and dash ignore the -e flag
# and print it literally. This is the shell-level equivalent of the
# macOS sed -i portability trap: same command, different output.
echo -e "line1\nline2"
