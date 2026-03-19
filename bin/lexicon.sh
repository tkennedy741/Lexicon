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
		echo "Available scripts:"
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

		payload=$(cat <<EOF
bash -s << 'EOF_REMOTE'
$(cat "$script_path")
EOF_REMOTE
EOF
)
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
echo "Now interacting with session:$PTYPATH"
echo -e "Commands: /send <text>\n /list (show sessions)\n /switch (choose another)\n /script [name]\n /quit"

while read -r cmd; do
        case "$cmd" in
                /send\ *)
                        payload=${cmd#'/send '}
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
		/read)
			if read -r -t 0.2 line < "$PTYPATH"; then
				echo "REMOTE> $line"
			else
				echo "(no data)"
			fi
			;;
		/quit)
			echo "bye"
			break
			;;
		*)
			echo "Invalid command!"
			echo "commands: /send <text>, /read, /quit"
			;;
	esac
done
