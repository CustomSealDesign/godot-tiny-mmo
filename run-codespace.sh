#!/usr/bin/env bash
# ============================================================================
# run-codespace.sh — Play the MMO from inside a GitHub Codespace (no local display).
#
# Boots the three headless servers (master, world, gateway) plus the game client,
# and streams the client to your browser through noVNC. Everything stays on
# localhost — no port rewriting, TLS, or public ports needed.
#
#   Usage:   ./run-codespace.sh            # start everything
#            ./run-codespace.sh stop       # stop everything
#
# After it starts, open the forwarded port 6080 (VS Code "PORTS" tab -> globe icon)
# and append /vnc.html — e.g. https://<name>-6080.app.github.dev/vnc.html — then
# click Connect. You'll see the game window; drive it with your mouse/keyboard.
# ============================================================================
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT_VER="4.6.3-stable"
BIN_DIR="$HOME/.local/share/godot-bin"
GODOT="$BIN_DIR/Godot_v${GODOT_VER}_linux.x86_64"
DISPLAY_NUM=99
export DISPLAY=":$DISPLAY_NUM"
WEB_PORT=6080
VNC_PORT=5900
LOG=/tmp/mmo-run
mkdir -p "$LOG"

PIDS_FILE="$LOG/pids"

stop_all() {
	echo "Stopping..."
	pkill -f "mode=client"          2>/dev/null || true
	pkill -f "mode=gateway-server"  2>/dev/null || true
	pkill -f "mode=world-server"    2>/dev/null || true
	pkill -f "mode=master-server"   2>/dev/null || true
	pkill -f "websockify.*$WEB_PORT" 2>/dev/null || true
	pkill -f "x11vnc.*$VNC_PORT"    2>/dev/null || true
	pkill -f "fluxbox"              2>/dev/null || true
	pkill -f "Xvfb :$DISPLAY_NUM"   2>/dev/null || true
	echo "Stopped."
}

if [ "${1:-}" = "stop" ]; then stop_all; exit 0; fi

# --- 1. Provision Godot (Linux headless build) --------------------------------
if [ ! -x "$GODOT" ]; then
	echo "[setup] downloading Godot $GODOT_VER ..."
	mkdir -p "$BIN_DIR"
	curl -fsSL -o /tmp/godot.zip \
		"https://github.com/godotengine/godot/releases/download/${GODOT_VER}/Godot_v${GODOT_VER}_linux.x86_64.zip"
	unzip -o -q /tmp/godot.zip -d "$BIN_DIR"
	chmod +x "$GODOT"
fi

# --- 2. Provision godot-sqlite native lib (addon bin is gitignored) -----------
SQLITE_DIR="$ROOT/addons/godot-sqlite/bin"
if [ ! -f "$SQLITE_DIR/libgdsqlite.linux.template_release.x86_64.so" ]; then
	echo "[setup] downloading godot-sqlite native lib ..."
	mkdir -p "$SQLITE_DIR"
	curl -fsSL -o /tmp/sqlite.zip \
		"https://github.com/2shady4u/godot-sqlite/releases/download/v4.7/bin.zip"
	unzip -o -j /tmp/sqlite.zip "*linux.template_debug.x86_64.so" "*linux.template_release.x86_64.so" -d "$SQLITE_DIR" >/dev/null
fi

# --- 3. Import assets on first run (cached afterwards) ------------------------
echo "[setup] importing project (first run can take a few minutes)..."
"$GODOT" --headless --path "$ROOT" --import >"$LOG/import.log" 2>&1 || true

# --- 4. Fresh start -----------------------------------------------------------
stop_all
sleep 1

# --- 5. Virtual display + window manager + VNC + web bridge -------------------
echo "[run] starting virtual display + noVNC ..."
Xvfb ":$DISPLAY_NUM" -screen 0 1280x720x24 -ac +extension GLX +render -noreset >"$LOG/xvfb.log" 2>&1 &
sleep 2
fluxbox >"$LOG/fluxbox.log" 2>&1 &
x11vnc -display ":$DISPLAY_NUM" -nopw -forever -shared -rfbport "$VNC_PORT" -quiet >"$LOG/x11vnc.log" 2>&1 &
websockify --web=/usr/share/novnc "$WEB_PORT" "localhost:$VNC_PORT" >"$LOG/novnc.log" 2>&1 &

# --- 6. Servers (master first, then world + gateway) -------------------------
echo "[run] starting servers ..."
"$GODOT" --headless --path "$ROOT" --mode=master-server >"$LOG/master.log" 2>&1 &
sleep 5
"$GODOT" --headless --path "$ROOT" --mode=world-server  >"$LOG/world.log"  2>&1 &
"$GODOT" --headless --path "$ROOT" --mode=gateway-server >"$LOG/gateway.log" 2>&1 &
sleep 5

# --- 7. Client (rendered on the virtual display, software GL) -----------------
echo "[run] starting client ..."
LIBGL_ALWAYS_SOFTWARE=1 "$GODOT" --path "$ROOT" --mode=client --audio-driver Dummy >"$LOG/client.log" 2>&1 &

sleep 3
echo
echo "======================================================================"
echo " Running. Open the forwarded port $WEB_PORT and add /vnc.html :"
echo "   https://${CODESPACE_NAME:-<codespace>}-${WEB_PORT}.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}/vnc.html"
echo " (VS Code -> PORTS tab -> forward $WEB_PORT if not auto-forwarded -> open it.)"
echo " Click 'Connect'. Logs are in $LOG/ ; stop with ./run-codespace.sh stop"
echo "======================================================================"
