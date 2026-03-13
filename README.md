# Claude Sandbox

A Docker-based isolated environment for running [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI, accessible via SSH from Claude Desktop or any terminal. Comes with [GSD (Get Shit Done)](https://github.com/glittercowboy/get-shit-done) pre-installed.

Supports **multiple instances** running simultaneously on the same machine — each with its own container, SSH port, workspace, and SSH keys.

## Prerequisites

| Dependency | Notes |
|---|---|
| **Docker Desktop** | [Download](https://www.docker.com/products/docker-desktop/) — requires Windows 10/11 with WSL2 or Hyper-V |
| **Windows OpenSSH Client** | Built into Windows 10 (1803+) / 11. Verify: `Settings > Apps > Optional Features > OpenSSH Client` |

## Quick Start

1. **Clone this repo** anywhere on your machine:
   ```
   git clone https://github.com/Jacob101mcd/claude-sandbox.git
   ```

2. **Launch the manager** — double-click `claude-manager.bat`
   - Auto-creates a `default` instance on first run
   - Choose `[S] Start` to build and start the container
   - Generates SSH keys, builds the Ubuntu 24.04 image, and writes SSH config
   - Takes a few minutes on first build

3. **Connect and run Claude** — double-click `ssh-claude.bat`
   - You should land at `claude@<container-id>:~/workspace$` with no password prompt
   - Run Claude Code with: `claude --dangerously-skip-permissions`

4. **(Optional) Connect via Claude Desktop** instead of SSH:
   - Open Claude Desktop > Settings > Developer > Edit Config
   - Add a remote SSH entry using the host alias shown in the scripts
   - Default instance uses alias `claude-sandbox` on port `2222`

## Multi-Instance Support

You can run multiple sandboxes simultaneously. Each gets its own container, SSH port, workspace, and SSH keys.

### Using the Manager

Double-click **`claude-manager.bat`** to open the interactive manager:

```
=== Claude Sandbox Manager ===
--- Instances ---
  [default]  port 2222  running  (ssh claude-sandbox)
  [rss]      port 2223  stopped  (ssh claude-rss)

--- Actions ---
  [S] Start an instance
  [T] Stop an instance
  [N] Create new instance
  [R] Remove an instance
  [Q] Quit
```

- **Start:** Select an existing instance to start
- **New:** Enter a name (e.g. `rss`) — a new container is built with the next available port
- **Stop:** Select an instance to stop its container
- **Remove:** Stop container, remove SSH config, deregister. Optionally deletes workspace/backups

### Instance Resources

Each instance `{name}` gets isolated resources:

| Resource | Location |
|---|---|
| Container | `claude-sandbox-{name}` |
| SSH port | Auto-assigned (2222, 2223, ...) |
| SSH alias | `claude-sandbox` (default) or `claude-{name}` |
| Workspace | `workspaces/{name}/` |
| SSH keys | `ssh/{name}/` |
| Backups | `backups/{name}/` |

### Connecting to a Specific Instance

- **SSH:** `ssh claude-sandbox` (default) or `ssh claude-{name}` (named instances)
- **ssh-claude.bat:** Shows a selection menu if multiple instances exist
- **Claude Desktop:** Use the SSH alias or `localhost` with the instance's port

## Scripts

| Script | Purpose |
|---|---|
| `claude-manager.bat` | Interactive manager: create, start, stop, remove instances |
| `rebuild-docker.bat` | Tear down and rebuild an instance from Dockerfile |
| `backup-claude.bat` | Snapshot instance container state + workspace to `backups/` |
| `restore-claude.bat` | Restore an instance from a previous backup |
| `ssh-claude.bat` | Open an interactive SSH shell to an instance |

All scripts show an interactive selection menu when multiple instances exist.

## File Structure

```
claude-sandbox/
  claude-manager.bat            Main entry point for managing instances
  rebuild-docker.bat            Tear down and rebuild an instance
  backup-claude.bat             Snapshot instance state + workspace
  restore-claude.bat            Restore from a previous backup
  ssh-claude.bat                Open an SSH shell to an instance
  .instances.json               (generated, gitignored) Instance registry
  scripts/
    Dockerfile                  Ubuntu 24.04 + SSH + Claude Code + GSD
    common.ps1                  Shared instance management functions
    claude-manager.ps1          Manager logic
    rebuild-claude.ps1          Full rebuild logic
    backup-claude.ps1           Backup logic
    restore-claude.ps1          Restore logic
    ssh-claude.ps1              SSH connection with instance selection
  ssh/{name}/                   (auto-generated, gitignored) Per-instance SSH keys
  workspaces/{name}/            (gitignored) Per-instance project files
  backups/{name}/               (gitignored) Per-instance backup archives
```

## SSH Details

| Setting | Value |
|---|---|
| Host alias | `claude-sandbox` (default) or `claude-{name}` |
| Host | `localhost` |
| Port | Auto-assigned per instance (starting at `2222`) |
| User | `claude` |
| Auth | Key-only (no password) |
| Key type | Ed25519 |

## What's Included in the Container

- **Ubuntu 24.04** base image
- **Node.js LTS** + npm
- **Claude Code CLI** (`@anthropic-ai/claude-code`)
- **[GSD framework](https://github.com/glittercowboy/get-shit-done)** (`get-shit-done-cc`) — pre-installed globally for the `claude` user
- **SSH server** with key-only authentication

## Integrations

### MCP Toolkit (Docker)

Sandbox instances automatically connect to the host's Docker MCP Toolkit server on startup. Claude Code inside the container can use any MCP servers configured in Docker Desktop or via the `docker mcp` CLI plugin.

**Prerequisites:**

1. Install Docker Desktop with MCP Toolkit enabled (Settings > Features > MCP Toolkit), OR install the `docker mcp` CLI plugin on Linux Docker Engine
2. Add at least one MCP server via the Docker Desktop MCP catalog or `docker mcp server add`
3. If using the `docker mcp` CLI plugin on Linux: start the gateway manually:
   ```
   docker mcp gateway run --transport sse --port 8811
   ```

**How it works:** The manager passes MCP connection details to each container. On startup, the container probes the MCP Gateway at `host.docker.internal:8811` and configures Claude Code automatically. No per-container setup needed.

**Verification:** After starting an instance, SSH in and run:
```
claude mcp list --scope user
```
Confirm the `docker-mcp` server is listed.

**Port override:** To use a non-default gateway port, set `CSM_MCP_PORT=NNNN` in your `.env` file.

**Disabling:** To disable MCP for a specific instance, the manager stores this preference per-instance in the registry.

### Remote Control

Optionally start a Claude Code remote control session inside the container, letting you continue conversations from a browser or mobile device.

**Important:** **Remote control requires a claude.ai subscription (Pro, Max, Team, or Enterprise) and does not work with API keys alone.** You must run `/login` inside the container to authenticate with your claude.ai account before remote control will function.

**Enabling:** When creating a new instance, the manager prompts `Enable remote control?`. Answer `y` to enable.

**How it works:** When enabled, the container launches `claude remote-control` as a background process on startup. The session URL is logged to `/tmp/csm-remote-control.log` inside the container.

See [Claude Code Remote Control](https://code.claude.com/docs/en/remote-control) for full documentation.

## Notes

- **SSH keys are auto-generated** per instance on first build. Each instance gets unique keys.
- **Scripts use relative paths** — you can clone this repo anywhere.
- **Workspace migration:** If upgrading from a single-instance setup, the old `workspace/` folder is automatically migrated to `workspaces/default/` on first run.
- Instance port assignments are persisted in `.instances.json` so they survive restarts.
- If Docker Desktop restarts, use `claude-manager.bat` to bring instances back up.
