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

exec /usr/sbin/sshd -D
