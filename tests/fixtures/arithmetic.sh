#!/bin/sh
# Arithmetic — POSIX $(( )) is portable, but let and (( )) are bash-only
a=10
b=3
result=$((a + b))
echo "Sum: $result"
result=$((a * b))
echo "Product: $result"
result=$((a / b))
echo "Quotient: $result"
result=$((a % b))
echo "Remainder: $result"
