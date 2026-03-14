![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-blue)
![License](https://img.shields.io/badge/license-Apache%202.0-green)
![Docker](https://img.shields.io/badge/requires-Docker-2496ED)

# Claude Sandbox Manager

Claude Sandbox Manager (CSM) is an interactive CLI tool that creates and manages isolated Docker containers for running [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Each sandbox is a full Ubuntu 24.04 environment with Claude Code pre-installed, accessible via SSH from your terminal or Claude Desktop.

Multiple sandboxes can run simultaneously — each with its own container, SSH port, workspace, and SSH keys.

---

## Why I built this

I wanted to let Claude Code loose on a project without worrying about my machine. Claude Code is powerful, and that power cuts both ways: give it enough autonomy and it will happily refactor things you didn't ask it to touch, delete files it thinks are redundant, or install packages you didn't expect. 

The obvious answer is containers. But spinning up a Docker environment with the right SSH setup, key management, and port assignments every time you start a new project is tedious. I wanted something I could just run, and have a ready-to-go Claude Code environment in a minute or two without thinking about Docker.

I also work on multiple projects simultaneously. One container per project means each project gets a clean workspace with no cross-contamination — Claude Code's context stays scoped to what's relevant, and the agent can't see (or accidentally modify) your other work.

Finally, I wanted this to be approachable for people who aren't Docker experts. You shouldn't need to understand bind mounts, port forwarding, or capability flags to get a safe AI coding environment. CSM handles all of that so you can focus on the work.

---

## Who is this for

- **Developers exploring AI coding assistants** who want a contained environment to experiment without risk to their main machine
- **People cautious about running AI agents with elevated permissions** — CSM provides the container isolation that makes `--dangerously-skip-permissions` a reasonable trade-off
- **Anyone juggling multiple projects with Claude Code** who wants reproducible, isolated environments per project
- **Teams that want a consistent Claude Code setup** that works the same way on Linux, macOS, and Windows without per-machine configuration
- **Developers who just want something that works** without needing to understand Docker internals

---

## Prerequisites

| Dependency | Notes |
|---|---|
| **Docker Desktop** or **Docker Engine** | [Download Docker Desktop](https://www.docker.com/products/docker-desktop/) (macOS/Windows/Linux). Linux users can also use Docker Engine directly. |
| **Git** | For cloning the repo. Pre-installed on most systems. |
| **SSH client** | Pre-installed on Linux and macOS. On Windows 10/11, SSH is built in (Settings > Apps > Optional Features > OpenSSH Client). |

---

## Quick Start

### Windows

```batch
git clone https://github.com/Jacob101mcd/claude-sandbox-manager.git
cd claude-sandbox-manager
```

Double-click `claude-manager.bat` to open the interactive manager. The same flow applies — auto-creates a default instance, choose `[S] Start`, then connect via `ssh claude-sandbox`.

---

### Linux / macOS (BETA, not fully tested)

```bash
git clone https://github.com/Jacob101mcd/claude-sandbox-manager.git
cd claude-sandbox-manager
chmod +x bin/csm
./bin/csm
```

The manager auto-creates a `default` instance on first run. Choose `[S] Start` to build and start it. The first build takes a few minutes as it downloads Ubuntu 24.04 and installs Claude Code.

Once running, SSH in:

```bash
ssh claude-sandbox
```

Then run Claude Code inside the container:

```bash
claude --dangerously-skip-permissions
```

## Multi-Instance Support

Each instance gets its own container, SSH port, workspace, and SSH keys. You can run as many simultaneously as your machine supports.

### Manager Interface

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
  [B] Backup an instance
  [E] Restore an instance
  [P] Preferences
  [Q] Quit
```

- **[S] Start** — Build and start a stopped instance (first build takes a few minutes)
- **[T] Stop** — Stop a running instance's container
- **[N] New** — Create a new instance with a unique name; assigns the next available SSH port
- **[R] Remove** — Stop, deregister, and optionally delete workspace and backups
- **[B] Backup** — Export container state and workspace to `backups/{name}/`
- **[E] Restore** — Restore a previous backup
- **[P] Preferences** — Configure default settings (see [Configuration](#configuration) below)
- **[Q] Quit** — Exit the manager

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

---

## Configuration

Access settings via **`[P] Preferences`** in the manager's main menu.

### Available Settings

| Setting | Default | Description |
|---|---|---|
| **Auto-backup** | Off | Automatically backup an instance on container start |
| **Default container type** | `cli` | Container variant to use when creating new instances (`cli` or `gui`) |
| **Memory limit** | `2g` | Docker memory limit per container (e.g. `1g`, `4g`, `512m`) |
| **CPU limit** | `2` | Docker CPU limit per container (e.g. `1`, `0.5`, `4`) |
| **MCP port** | `8811` | Port for the Docker MCP Gateway on the host |

Settings are stored in `csm-config.json` in the project root. This file is auto-created with sensible defaults on first run and is gitignored — your preferences stay local.

Example `csm-config.json`:

```json
{
  "defaults": {
    "container_type": "cli",
    "memory_limit": "2g",
    "cpu_limit": 2
  },
  "backup": {
    "auto_backup": false
  },
  "integrations": {
    "mcp_port": 8811
  }
}
```

Resource limit changes apply to all instances on their next start.

---

## Integrations

### MCP Toolkit (Docker)

Sandbox instances automatically connect to the host's Docker MCP Toolkit server on startup. Claude Code inside the container can use any MCP servers configured in Docker Desktop or via the `docker mcp` CLI plugin.

**Prerequisites:**

1. Install Docker Desktop with MCP Toolkit enabled (Settings > Features > MCP Toolkit), OR install the `docker mcp` CLI plugin on Linux Docker Engine
2. Add at least one MCP server via the Docker Desktop MCP catalog or `docker mcp server add`
3. If using the `docker mcp` CLI plugin on Linux: start the gateway manually:
   ```bash
   docker mcp gateway run --transport sse --port 8811
   ```

**How it works:** The manager passes MCP connection details to each container. On startup, the container probes the MCP Gateway at `host.docker.internal:8811` and configures Claude Code automatically. No per-container setup needed.

**Verification:** After starting an instance, SSH in and run:

```bash
claude mcp list --scope user
```

Confirm the `docker-mcp` server is listed.

**Port override:** To use a non-default gateway port, update **MCP port** in `[P] Preferences`.

**Disabling:** To disable MCP for a specific instance, the manager stores this preference per-instance in the registry.

### Remote Control

Optionally start a Claude Code remote control session inside the container, letting you continue conversations from a browser or mobile device.

**Important:** Remote control requires a claude.ai subscription (Pro, Max, Team, or Enterprise) and does not work with API keys alone. You must run `/login` inside the container to authenticate with your claude.ai account before remote control will function.

**Enabling:** When creating a new instance, the manager prompts `Enable remote control?`. Answer `y` to enable.

**How it works:** When enabled, the container launches `claude remote-control` as a background process on startup. The session URL is logged to `/tmp/csm-remote-control.log` inside the container.

See [Claude Code Remote Control](https://code.claude.com/docs/en/remote-control) for full documentation.

---

## Security

CSM is designed to make `--dangerously-skip-permissions` a reasonable trade-off. The container is the sandbox — Claude Code can do whatever it wants inside it without reaching your host machine.

| Risk | Status |
|---|---|
| Container escape | 🟢 Hardened — dropped capabilities, no-new-privileges, resource limits |
| Credential exposure | 🟢 Hardened — `.env` gitignored, runtime injection only, never in image layers |
| Resource abuse | 🟢 Hardened — memory and CPU limits enforced via Docker flags |
| Network access from container | 🟡 User responsibility — outbound internet required for Claude Code to function |
| AI agent permissions (`--dangerously-skip-permissions`) | 🟡 User responsibility — container isolation is what makes this trade-off acceptable |

**Why `--dangerously-skip-permissions` is acceptable here:** Claude Code has full access *inside the container*, which only contains your workspace. It doesn't have access to your host filesystem, SSH keys, or other processes on your machine.

For the full risk analysis, hardening tips, and Docker Desktop vs Docker Engine isolation comparison, see [SECURITY.md](SECURITY.md).

---

## What's Included

### Container Contents

- **Ubuntu 24.04** base image
- **Node.js LTS** + npm
- **Claude Code** — installed via the official native installer
- **GitHub CLI** (`gh`) — for git operations and GitHub integrations
- **SSH server** — key-only authentication, localhost-only binding

### Container Variants

When creating a new instance, you choose a variant (or set a default in `[P] Preferences`):

| Variant | Description | Use Case |
|---|---|---|
| **CLI** (minimal) | Bare Ubuntu + Claude Code + GitHub CLI | Command-line work, coding tasks, automated workflows |
| **GUI** (desktop) | Xfce desktop + noVNC + Chromium | Visual tasks, browser-based testing, GUI development |

The GUI variant runs a full desktop accessible at `http://localhost:{vnc-port}` in your browser — no VNC client needed.

---

## SSH Details

| Setting | Value |
|---|---|
| Host alias | `claude-sandbox` (default) or `claude-{name}` |
| Host | `localhost` |
| Port | Auto-assigned per instance (starting at `2222`) |
| User | `claude` |
| Auth | Key-only (no password) |
| Key type | Ed25519 |

---

## Notes

- **SSH keys are auto-generated** per instance on first build. Each instance gets unique Ed25519 key pairs.
- **Paths are relative** — you can clone this repo anywhere on your machine.
- **Workspace migration:** If upgrading from a single-instance setup, the old `workspace/` folder is automatically migrated to `workspaces/default/` on first run.
- Instance port assignments are persisted in `.instances.json` so they survive restarts and manager relaunches.
- Licensed under [Apache 2.0](LICENSE).
