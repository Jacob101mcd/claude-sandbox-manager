FROM ubuntu:24.04 AS base

# System packages (rarely change -- maximize cache)
RUN apt-get update && apt-get install -y \
    openssh-server \
    curl \
    git \
    sudo \
    wget \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI from official apt repository
RUN wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (LTS) and npm
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Create claude user with sudo (must exist before native installer)
RUN useradd -m -s /bin/bash claude \
    && usermod -aG sudo claude \
    && echo 'claude ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/claude \
    && chmod 0440 /etc/sudoers.d/claude

# SSH setup -- key-only (no password ever)
RUN mkdir /var/run/sshd \
    && printf '\nPermitRootLogin no\nPasswordAuthentication no\nKbdInteractiveAuthentication no\nPubkeyAuthentication yes\nAuthorizedKeysFile .ssh/authorized_keys\nHostKey /etc/ssh/ssh_host_ed25519_key\n' >> /etc/ssh/sshd_config \
    && sed -i 's/session.*required.*pam_loginuid.so/session optional pam_loginuid.so/' /etc/pam.d/sshd

# Stable SSH host key -- baked in so the fingerprint never changes across rebuilds
COPY _build_ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key
COPY _build_ssh/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.pub
RUN chmod 600 /etc/ssh/ssh_host_ed25519_key \
    && chmod 644 /etc/ssh/ssh_host_ed25519_key.pub

# Bake YOUR public key into the image (this survives every rebuild)
COPY _build_ssh/id_claude.pub /tmp/id_claude.pub

RUN mkdir -p /home/claude/.ssh \
    && cat /tmp/id_claude.pub >> /home/claude/.ssh/authorized_keys \
    && chown -R claude:claude /home/claude/.ssh \
    && chmod 700 /home/claude/.ssh \
    && chmod 600 /home/claude/.ssh/authorized_keys \
    && rm /tmp/id_claude.pub

# Install Claude Code via native installer (not NPM)
USER claude
RUN curl -fsSL https://claude.ai/install.sh | bash
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/claude/.bashrc \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/claude/.profile

# Verify Claude Code binary is accessible
RUN /home/claude/.local/bin/claude --version

# Install GSD (Get Shit Done) framework for the claude user
RUN npx -y get-shit-done-cc@latest --global
USER root

# ──────────────────────────────────────────────
# CLI stage: minimal -- just entrypoint + SSH
# ──────────────────────────────────────────────
FROM base AS cli

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22
CMD ["/usr/local/bin/entrypoint.sh"]

# ──────────────────────────────────────────────
# GUI stage: full desktop (Xfce + VNC + Chromium)
# ──────────────────────────────────────────────
FROM base AS gui

# Install desktop environment and VNC stack
RUN apt-get update && apt-get install -y --no-install-recommends \
    xfce4 \
    xfce4-terminal \
    tigervnc-standalone-server \
    novnc \
    python3-websockify \
    python3-numpy \
    dbus-x11 \
    chromium-browser \
    && rm -rf /var/lib/apt/lists/*

# Chromium wrapper: container-safe launch flags
RUN printf '#!/bin/sh\nexec chromium-browser --no-sandbox --disable-gpu --disable-dev-shm-usage --homepage=about:blank "$@"\n' \
    > /usr/local/bin/chromium-safe \
    && chmod +x /usr/local/bin/chromium-safe

# Xfce desktop configuration for claude user
RUN mkdir -p /home/claude/Desktop

# Workspace desktop shortcut: folder icon pointing to /home/claude/workspace
RUN printf '[Desktop Entry]\nVersion=1.0\nType=Application\nName=Workspace\nComment=Open workspace folder\nExec=thunar /home/claude/workspace\nIcon=folder\nTerminal=false\nCategories=Utility;\n' \
    > /home/claude/Desktop/workspace.desktop \
    && chmod +x /home/claude/Desktop/workspace.desktop \
    && chown -R claude:claude /home/claude/Desktop

# Disable screensaver and power manager autostart (not needed in a container)
RUN rm -f /etc/xdg/autostart/xfce4-screensaver.desktop \
          /etc/xdg/autostart/xfce4-power-manager.desktop \
    || true

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22 6080
CMD ["/usr/local/bin/entrypoint.sh"]
