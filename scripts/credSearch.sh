#!/usr/bin/env bash

echo "=== Searching for interesting files ==="

find /home /root -type f \( \
    -iname "*.ssh*" -o \
    -iname "*.bash_history" -o \
    -iname "*config*" -o \
    -iname "*pass*" \
\) 2>/dev/null | head -n 50

echo -e "\n=== Grepping for passwords ==="

grep -Ri "password" /home 2>/dev/null | head -n 20
