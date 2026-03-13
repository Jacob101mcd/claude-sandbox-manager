#!/bin/bash
# Entrypoint: persist Docker -e env vars so SSH sessions can see them.
# Writes to claude's .bashrc so interactive SSH sessions pick them up.

CRED_BLOCK="/home/claude/.csm-env"
: > "$CRED_BLOCK"

for var in ANTHROPIC_API_KEY GITHUB_TOKEN; do
    val="${!var}"
    if [ -n "$val" ]; then
        echo "export ${var}=\"${val}\"" >> "$CRED_BLOCK"
    fi
done

chown claude:claude "$CRED_BLOCK"
chmod 600 "$CRED_BLOCK"

# Ensure .bashrc sources the credential file
if ! grep -q 'csm-env' /home/claude/.bashrc 2>/dev/null; then
    echo '[ -f "$HOME/.csm-env" ] && . "$HOME/.csm-env"' >> /home/claude/.bashrc
fi

# --- MCP Gateway auto-configuration ---
_mcp_port="${CSM_MCP_PORT:-8811}"
_mcp_url="http://host.docker.internal:${_mcp_port}/sse"

if [[ "${CSM_MCP_ENABLED:-0}" == "1" ]]; then
    # Probe gateway reachability (2-second timeout)
    if curl --silent --max-time 2 --output /dev/null --head "${_mcp_url%/sse}" 2>/dev/null || \
       curl --silent --max-time 2 --output /dev/null -w "" "${_mcp_url}" 2>/dev/null; then
        # Idempotent: only add if not already registered
        if ! su - claude -c "claude mcp get docker-mcp --scope user" &>/dev/null 2>&1; then
            if su - claude -c "claude mcp add-json docker-mcp '{\"type\":\"sse\",\"url\":\"${_mcp_url}\"}' --scope user < /dev/null" 2>/dev/null; then
                echo "[csm] MCP Gateway connected: ${_mcp_url}"
            else
                echo "[csm] WARNING: Failed to write MCP config via claude CLI"
            fi
        fi
    else
        echo "[csm] WARNING: MCP Gateway not reachable at ${_mcp_url}"
        echo "[csm]   Install Docker Desktop MCP Toolkit or run: docker mcp gateway run --transport sse"
    fi
fi

# --- Remote control (optional) ---
if [[ "${CSM_REMOTE_CONTROL:-}" == "1" ]]; then
    _rc_log="/tmp/csm-remote-control.log"
    su - claude -c "claude remote-control --name 'CSM: $(hostname)' > '${_rc_log}' 2>&1 &"
    # Give it 3 seconds to register or fail
    sleep 3
    if grep -q 'https://claude\.ai' "${_rc_log}" 2>/dev/null; then
        _rc_url="$(grep -oP 'https://claude\.ai\S+' "${_rc_log}" | head -1)"
        echo "[csm] Remote control session: ${_rc_url}"
    else
        echo "[csm] WARNING: Remote control did not start. Requires claude.ai account login (/login)."
        echo "[csm]   API keys are not supported for remote control."
    fi
fi

# Detect GUI variant by checking for vncserver binary
if command -v vncserver &>/dev/null; then
    # Set up VNC config for claude user (passwordless, localhost-only)
    mkdir -p /home/claude/.vnc
    cat > /home/claude/.vnc/config <<'VNCCONF'
SecurityTypes=None
geometry=1920x1080
depth=24
VNCCONF

    # xstartup: launch Xfce4 session
    cat > /home/claude/.vnc/xstartup <<'VNCSTART'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
VNCSTART
    chmod 755 /home/claude/.vnc/xstartup
    chown -R claude:claude /home/claude/.vnc

    # Start VNC server as claude user on display :1 (port 5901)
    su - claude -c "vncserver :1 -localhost yes" &

    # Wait for VNC server to be ready (poll, max 10 iterations)
    for i in $(seq 1 10); do
        if ss -tln 2>/dev/null | grep -q ':5901 ' || \
           netstat -tln 2>/dev/null | grep -q ':5901 '; then
            break
        fi
        sleep 0.5
    done

    # Start websockify: WebSocket-to-VNC bridge, serves noVNC UI on port 6080
    websockify --web=/usr/share/novnc/ --daemon 6080 localhost:5901
fi

exec /usr/sbin/sshd -D
