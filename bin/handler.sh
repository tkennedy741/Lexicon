#!/bin/bash

set -euo pipefail

# Location where sessions are stored
BASE_DIR=/opt/lexicon/sessions
mkdir -p "$BASE_DIR"
umask 077

# Create unique ID for session and spawns PTY Link
SESSION_NAME="session-$(date +%m%dT%H%M%S)-$$"
LINK="$BASE_DIR/$SESSION_NAME"

#ensure no stale name
rm -f "$LINK"

# Links listener to PTY
exec socat -d -d PTY,link="$LINK",raw,echo=0 STDIO
