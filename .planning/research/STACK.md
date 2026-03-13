# Technology Stack

**Project:** Claude Sandbox Manager
**Researched:** 2026-03-13
**Overall confidence:** HIGH

## Executive Decision

Replace the Windows-only PowerShell/.bat scripts with a TypeScript Node.js CLI. Node.js is the correct choice here because: (1) the target audience already has Node.js installed (Claude Code requires it), (2) Docker management via dockerode is mature, (3) cross-platform by default, and (4) the team is already in the Node/TypeScript ecosystem.

**Do NOT use:** Python (extra runtime dependency), Go (compiled binary distribution complexity for a tool targeting non-technical users), Rust (same), or pure shell scripts (the whole reason for the rewrite is that .bat/.ps1 is not cross-platform).

## Recommended Stack

### Language & Runtime

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| TypeScript | ^5.5 | Type-safe development | Catches container config errors at compile time; the codebase manages SSH keys, ports, and Docker args where typos cause silent failures | HIGH |
| Node.js | >=20 LTS | Runtime | Required by Claude Code already; users guaranteed to have it | HIGH |
| ESM modules | — | Module system | All recommended libraries (execa, chalk, ora) are ESM-only; fighting CJS compatibility is not worth it | HIGH |

### CLI Framework

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Commander.js | ^14.0 | Command parsing and routing | Zero dependencies, 35M weekly downloads, excellent TypeScript support, fastest startup (18ms). This is a multi-command CLI (start, stop, backup, config) but not complex enough to need oclif's plugin architecture. Commander handles subcommands cleanly. | HIGH |
| @inquirer/prompts | ^8.3 | Interactive menus and user input | The rewritten modern version of Inquirer.js. Provides select lists, confirmations, and text input. Essential for the "accessible to non-Docker-experts" requirement — users pick from menus instead of memorizing flags. | HIGH |

**Why not oclif:** Oclif adds 30+ dependencies, 85ms startup time, and is designed for enterprise plugin ecosystems (Salesforce CLI, Heroku CLI). This project has ~10 commands, not 100. Over-engineering.

**Why not yargs:** Yargs is great for argument parsing but weaker at interactive menus. Commander + @inquirer/prompts gives cleaner separation between command routing and user interaction.

### Docker Integration

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| dockerode | ^4.0.9 | Docker Engine API client | Programmatic container lifecycle (create, start, stop, export, inspect) without shelling out to `docker` CLI. Handles streaming, promises, and all Docker API endpoints. 1200+ dependents, actively maintained. | HIGH |
| @types/dockerode | latest | TypeScript definitions | dockerode is plain JS; type definitions are separate | HIGH |

**Why not shell out to `docker` CLI:** The current PowerShell scripts shell out to `docker build`, `docker run`, etc. This works but: (1) parsing CLI output is fragile, (2) error handling is string matching, (3) streaming build output needs special handling. Dockerode gives typed responses and proper error objects. Use dockerode for all container operations except `docker build` (where dockerode's build streaming is equivalent).

**Why not Docker Compose:** The project explicitly moved away from docker-compose to docker build/run for instance isolation. Each instance gets its own image and container. Compose adds unnecessary abstraction for single-container instances.

### Process Execution (for non-Docker commands)

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| execa | ^9.6 | Running SSH keygen, system commands | Cross-platform child process execution with proper error handling, timeout support, and streaming. Used for ssh-keygen, ssh-keyscan, and any commands that dockerode doesn't cover. ESM-only. | HIGH |

**Why not child_process directly:** execa provides better defaults (rejects on non-zero exit, strips final newline, combines stdout/stderr sanely), cross-platform path handling, and TypeScript types.

### Terminal UI & Output

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| chalk | ^5.4 | Colored terminal output | The standard for terminal coloring. ESM-only from v5. Zero dependencies. | HIGH |
| ora | ^8.0 | Spinners for long operations | Docker builds and exports take time. Ora provides clean single-line spinners that handle stdout writes gracefully. | HIGH |
| listr2 | ^9.0 | Multi-step task lists | For operations like "build image, create container, configure SSH, start container" — shows progress through each step. Better UX than sequential console.log. | MEDIUM |

**Why not ink (React for CLI):** Ink is powerful but heavy for this use case. We need menus and spinners, not a full reactive terminal UI. @inquirer/prompts + ora + chalk covers all needs without adding React as a dependency to a Docker management tool.

### Configuration

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| conf | ^13.0 | User settings storage | Stores config in OS-native location (~/.config on Linux, ~/Library/Preferences on macOS, %APPDATA% on Windows). JSON-backed, schema validation, atomic writes. Replaces the current `.instances.json` in project root. | HIGH |

**Why not cosmiconfig:** Cosmiconfig searches for config files up the directory tree (like .eslintrc). That pattern is for per-project config. Sandbox manager config is per-user (which instances exist, backup settings, default container type). `conf` is purpose-built for this.

**Why not plain JSON file:** The current approach (`.instances.json` in project root) breaks when the tool is installed globally. `conf` handles OS-specific paths, file permissions, and atomic writes.

### Build & Development

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| tsup | ^8.0 | Bundle TypeScript to distributable JS | Fast esbuild-based bundler. Generates ESM output, handles node_modules, produces a single entry point. Note: tsup is in maintenance mode; tsdown is the successor but too new for production use. tsup remains stable and widely used. | MEDIUM |
| tsx | ^4.0 | Development-time TypeScript execution | Run .ts files directly during development without a build step. Fast (esbuild-backed). | HIGH |
| vitest | ^3.0 | Testing | Fast, TypeScript-native, ESM-native. No config needed for basic usage. | HIGH |

**Why not tsc for building:** tsc does not bundle. You'd need tsc + a bundler. tsup does both in one step.

**Why not jest:** Jest has poor ESM support and requires transform configuration for TypeScript. Vitest works out of the box with ESM + TypeScript.

### GUI Container Stack (Docker-side, not Node.js)

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Xvfb | — | Virtual framebuffer | Standard X11 virtual display. Runs in Docker without real GPU. Lightweight. | HIGH |
| x11vnc | — | VNC server | Exposes Xvfb display over VNC protocol. Simple, well-tested. | HIGH |
| noVNC | ^1.5 | Browser-based VNC client | Zero-install access to GUI containers via web browser. Users open localhost:6080 and get a desktop. No VNC client needed. | HIGH |
| supervisord | — | Process manager in container | Manages Xvfb + x11vnc + noVNC + sshd in GUI containers. Standard for multi-process Docker containers. | HIGH |
| Fluxbox or Openbox | — | Window manager | Minimal window managers. Fluxbox is ~2MB. Openbox is similar. Either works; Fluxbox has slightly better defaults for container use. | HIGH |

**Why not KasmVNC:** KasmVNC is more polished but (1) non-standard VNC (breaks regular VNC clients), (2) heavier, (3) has its own licensing concerns. noVNC + x11vnc is the proven, lightweight, standard approach for Docker containers. KasmVNC is better for enterprise Kasm Workspaces deployments, not single-container dev environments.

### Backup System

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| dockerode export API | — | Container filesystem export | `container.export()` in dockerode streams the container filesystem as a tar. Pipe to file with optional gzip compression. Matches the PROJECT.md decision to use `docker export`. | HIGH |
| Node.js streams + zlib | built-in | Compression | Pipe dockerode export stream through `zlib.createGzip()` to a file write stream. No external dependency needed. | HIGH |

**Why not docker commit + save:** `docker export` captures the full filesystem as a flat tar (no layers, no metadata). This is correct for backups intended to be portable snapshots. `docker commit` + `docker save` preserves layers but produces larger files and is meant for image distribution, not backup.

### SSH Management

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| execa (ssh-keygen) | — | Key generation | Cross-platform invocation of ssh-keygen for ed25519 key pairs. Replaces the PowerShell-specific key generation. | HIGH |
| Node.js fs | built-in | SSH config file management | Read/write ~/.ssh/config entries programmatically. The current regex-based PowerShell approach works; port it to Node with proper parsing. | HIGH |

**Why not an SSH library (ssh2):** We don't need to establish SSH connections from the manager. We just generate keys and write config. The user (or Claude Code) SSHes in directly. ssh2 would be overhead for no benefit.

### Docker Desktop MCP Toolkit Integration

| Technology | Approach | Purpose | Why | Confidence |
|------------|----------|---------|-----|------------|
| Docker MCP Gateway | Configuration-based | Share MCP servers with containers | Docker Desktop MCP Toolkit handles MCP server lifecycle. Containers connect through the MCP Gateway. Integration is configuration, not code — the manager ensures containers are configured to access the gateway endpoint. | MEDIUM |

**Note:** MCP Toolkit integration is primarily about Docker configuration (network settings, environment variables) rather than a Node.js library. The manager needs to: (1) detect if MCP Toolkit is available, (2) configure container networking to reach the gateway, (3) set appropriate environment variables. This is dockerode configuration, not a separate dependency.

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Language | TypeScript/Node.js | Go | Users already have Node.js (Claude Code dependency). Go binary distribution adds complexity for non-technical audience. |
| Language | TypeScript/Node.js | Python | Extra runtime dependency. Python version management is a mess for end users. |
| CLI framework | Commander.js | oclif | Too heavy (30+ deps, 85ms startup) for a 10-command CLI |
| CLI framework | Commander.js | yargs | Weaker interactive menu story; Commander + @inquirer/prompts is cleaner |
| Docker client | dockerode | Shell out to docker CLI | Fragile output parsing, poor error handling, no TypeScript types |
| Interactive UI | @inquirer/prompts | ink (React) | Over-engineered for menus and confirmations; adds React dependency |
| Config | conf | cosmiconfig | cosmiconfig is for per-project config; this needs per-user config |
| Config | conf | dotenv + JSON | No OS-native paths, no atomic writes, no schema validation |
| Testing | vitest | jest | Jest has poor ESM support; vitest is ESM-native |
| GUI VNC | noVNC + x11vnc | KasmVNC | Non-standard VNC, heavier, licensing concerns |
| Build | tsup | tsc | tsc doesn't bundle; need extra tooling |

## Project Structure

```
claude-sandbox-manager/
  src/
    cli.ts                  # Commander setup, command definitions
    commands/
      start.ts              # Start/create instance
      stop.ts               # Stop instance
      list.ts               # List instances
      remove.ts             # Remove instance
      backup.ts             # Backup instance
      restore.ts            # Restore instance
      config.ts             # Settings management
    lib/
      docker.ts             # Dockerode wrapper, image building, container lifecycle
      ssh.ts                # Key generation, config file management
      backup.ts             # Export/import logic
      config.ts             # conf-based settings store
      ui.ts                 # chalk/ora/listr2 helpers
    containers/
      minimal/
        Dockerfile          # CLI-only container
      gui/
        Dockerfile          # GUI container with Xvfb/noVNC
        supervisord.conf    # Process manager config
    types/
      index.ts              # Shared type definitions
  bin/
    claude-sandbox.ts       # Entry point (#!/usr/bin/env node)
  package.json
  tsconfig.json
  tsup.config.ts
```

## Installation

```bash
# Core dependencies
npm install commander@^14.0 @inquirer/prompts@^8.3 dockerode@^4.0 execa@^9.6 chalk@^5.4 ora@^8.0 conf@^13.0 listr2@^9.0

# TypeScript types
npm install -D @types/dockerode @types/node

# Build & development
npm install -D tsup@^8.0 tsx@^4.0 typescript@^5.5 vitest@^3.0
```

## Key Compatibility Notes

1. **ESM-only packages:** chalk v5+, ora v8+, execa v6+, and conf v12+ are all ESM-only. The project MUST use `"type": "module"` in package.json. This is not optional.

2. **Node.js 20+ requirement:** All recommended packages target Node 20+. This aligns with Claude Code's own requirements.

3. **dockerode is CJS:** dockerode (v4.0.9) is CommonJS but can be imported in ESM projects via `import Docker from 'dockerode'`. TypeScript handles the interop.

4. **Platform-specific SSH:** ssh-keygen behavior differs slightly across platforms. The execa wrapper should normalize key path separators and handle Windows `icacls` vs Unix `chmod` for key permissions.

5. **Docker socket path:** dockerode auto-detects the Docker socket (`/var/run/docker.sock` on Linux/macOS, `//./pipe/docker_engine` on Windows). No special config needed.

## Sources

- [Commander.js npm](https://www.npmjs.com/package/commander) - v14.0.3 confirmed
- [dockerode npm](https://www.npmjs.com/package/dockerode) - v4.0.9 confirmed
- [dockerode GitHub](https://github.com/apocas/dockerode) - API documentation
- [@inquirer/prompts npm](https://www.npmjs.com/package/@inquirer/prompts) - v8.3.0 confirmed
- [execa npm](https://www.npmjs.com/package/execa) - v9.6.1 confirmed
- [Docker MCP Toolkit docs](https://docs.docker.com/ai/mcp-catalog-and-toolkit/toolkit/)
- [Claude Code native installer](https://code.claude.com/docs/en/setup) - curl-based installer replaces npm
- [vnc-containers GitHub](https://github.com/silentz/vnc-containers) - Xvfb + x11vnc + noVNC reference
- [docker export docs](https://docs.docker.com/reference/cli/docker/container/export/)
- [tsup GitHub](https://github.com/egoist/tsup) - maintenance mode noted
- [conf GitHub](https://github.com/sindresorhus/conf) - OS-native config storage
