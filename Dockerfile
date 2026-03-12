FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    openssh-server \
    curl \
    git \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (LTS) and npm
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Create claude user with sudo (must exist before GSD install)
RUN useradd -m -s /bin/bash claude \
    && echo 'claude:claude123' | chpasswd \
    && adduser claude sudo

# SSH setup — key-only (no password ever)
RUN mkdir /var/run/sshd \
    && printf '\nPermitRootLogin no\nPasswordAuthentication no\nKbdInteractiveAuthentication no\nPubkeyAuthentication yes\nAuthorizedKeysFile .ssh/authorized_keys\nHostKey /etc/ssh/ssh_host_ed25519_key\n' >> /etc/ssh/sshd_config

# SSH_DIR points to the instance-specific ssh key directory (e.g. ssh/default)
ARG SSH_DIR=ssh/default

# Stable SSH host key — baked in so the fingerprint never changes across rebuilds
COPY ${SSH_DIR}/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key
COPY ${SSH_DIR}/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.pub
RUN chmod 600 /etc/ssh/ssh_host_ed25519_key \
    && chmod 644 /etc/ssh/ssh_host_ed25519_key.pub

# Bake YOUR public key into the image (this survives every rebuild)
COPY ${SSH_DIR}/id_claude.pub /tmp/id_claude.pub

RUN mkdir -p /home/claude/.ssh \
    && cat /tmp/id_claude.pub >> /home/claude/.ssh/authorized_keys \
    && chown -R claude:claude /home/claude/.ssh \
    && chmod 700 /home/claude/.ssh \
    && chmod 600 /home/claude/.ssh/authorized_keys \
    && rm /tmp/id_claude.pub

# Install GSD (Get Shit Done) framework for the claude user
USER claude
RUN npx -y get-shit-done-cc@latest --global
USER root

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]