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
