#!/usr/bin/env bash

echo "=== USER INFO ==="
whoami
id

echo -e "\n=== SYSTEM INFO ==="
uname -a
hostname

echo -e "\n=== NETWORK INFO ==="
ip a
ip route

echo -e "\n=== ACTIVE CONNECTIONS ==="
ss -tulnp 2>/dev/null || netstat -tulnp 2>/dev/null

echo -e "\n=== RUNNING PROCESSES (top 10) ==="
ps aux --sort=-%mem | head -n 10

echo -e "\n=== SUDO CHECK ==="
sudo -n true 2>/dev/null && echo "Passwordless sudo available" || echo "No sudo access"

echo -e "\n=== HOME DIR CONTENTS ==="
ls -la ~
