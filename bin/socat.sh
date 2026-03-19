#!/bin/bash
# Creates listener on port 8080, for every connection launch handler.sh with a new fork
exec /usr/bin/socat TCP-LISTEN:8080,reuseaddr,fork EXEC:/opt/lexicon/handler.sh
