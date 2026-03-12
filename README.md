# Claude Sandbox

A Docker-based isolated environment for running [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI, accessible via SSH from Claude Desktop or any terminal. Comes with [GSD (Get Shit Done)](https://github.com/glittercowboy/get-shit-done) pre-installed.

## Prerequisites

| Dependency | Notes |
|---|---|
| **Docker Desktop** | [Download](https://www.docker.com/products/docker-desktop/) — requires Windows 10/11 with WSL2 or Hyper-V |
| **Windows OpenSSH Client** | Built into Windows 10 (1803+) / 11. Verify: `Settings > Apps > Optional Features > OpenSSH Client` |
| **Claude Desktop** | [Download](https://claude.ai/download) — connects to the sandbox over SSH |

## Quick Start

1. **Clone this repo** anywhere on your machine:
   ```
   git clone https://github.com/YOUR_USERNAME/claude-sandbox.git
   cd claude-sandbox
   ```

2. **Build the container** — double-click `rebuild-docker.bat`
   - Generates SSH keys automatically on first run
   - Builds Ubuntu 24.04 image with Claude Code CLI + GSD
   - Takes a few minutes on first run

3. **Start the container** — double-click `start-claude.bat`
   - Starts the container and writes SSH config to `~/.ssh/config`
   - Fixes Windows permissions on the SSH private key
   - Run this after reboots or Docker Desktop restarts

4. **Configure Claude Desktop** to connect via SSH:
   - Open Claude Desktop > Settings > Developer > Edit Config
   - Add a remote SSH entry:
     - Host: `localhost`
     - Port: `2222`
     - User: `claude`
     - Key: `<your-clone-path>\ssh\id_claude`
   - Or use the SSH alias `claude-sandbox` (written to `~/.ssh/config` by the start script)

5. **Test the connection** — double-click `ssh-claude.bat`
   - You should land at `claude@<container-id>:~/workspace$` with no password prompt

## Scripts

| Script | Purpose |
|---|---|
| `start-claude.bat` | Start container + configure SSH client |
| `rebuild-docker.bat` | Tear down and rebuild from Dockerfile |
| `backup-claude.bat` | Snapshot container state + workspace to `backups/` |
| `restore-claude.bat` | Restore from a previous backup (overwrites current state) |
| `ssh-claude.bat` | Open an interactive SSH shell in the container |

## File Structure

```
claude-sandbox/
  Dockerfile              Ubuntu 24.04 + SSH + Claude Code + GSD
  docker-compose.yml      Container config (ports, volumes)
  CLAUDE.md               Project guidance for Claude Code
  scripts/
    start-claude.ps1      Start logic + SSH key generation + client setup
    rebuild-claude.ps1    Full rebuild logic + SSH key generation
    backup-claude.ps1     Backup logic
    restore-claude.ps1    Restore logic
  ssh/                    (auto-generated, gitignored)
    id_claude             SSH private key — keep secret, never share
    id_claude.pub         SSH public key — baked into Docker image
    ssh_host_ed25519_key  Stable host key (persists across rebuilds)
  workspace/              (gitignored) Your project files, bind-mounted into container
  backups/                (gitignored) Timestamped backup archives
```

## SSH Details

| Setting | Value |
|---|---|
| Host alias | `claude-sandbox` (written to `~/.ssh/config`) |
| Host | `localhost` |
| Port | `2222` |
| User | `claude` |
| Auth | Key-only (no password) |
| Key type | Ed25519 |

## What's Included in the Container

- **Ubuntu 24.04** base image
- **Node.js LTS** + npm
- **Claude Code CLI** (`@anthropic-ai/claude-code`)
- **GSD framework** (`get-shit-done-cc`) — pre-installed globally for the `claude` user
- **SSH server** with key-only authentication

## Notes

- **SSH keys are auto-generated** on first `start-claude.bat` or `rebuild-docker.bat` run. Each clone gets unique keys.
- **Scripts use relative paths** — you can clone this repo anywhere, not just `C:\claude-sandbox`.
- The `workspace/` folder is bind-mounted into the container at `/home/claude/workspace`. Files there survive container restarts and rebuilds.
- Backups include the full Docker image snapshot + workspace files. Restoring overwrites everything.
- If Docker Desktop restarts, run `start-claude.bat` to bring the container back up.
