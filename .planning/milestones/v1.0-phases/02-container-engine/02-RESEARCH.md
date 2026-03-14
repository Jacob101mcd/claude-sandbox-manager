# Phase 2: Container Engine - Research

**Researched:** 2026-03-13
**Domain:** Docker container lifecycle, credential injection, Claude Code installation
**Confidence:** HIGH

## Summary

Phase 2 requires modifying the existing Dockerfile to replace NPM-based Claude Code installation with the native installer, adding GitHub CLI from the official apt repository, implementing `.env` file parsing for credential management, extending the `docker run` command with `-e` flags for runtime credential injection, and adding a container type selection sub-menu to the creation flow.

The existing codebase from Phase 1 provides solid foundations: `docker_run_instance()` already builds a Bash array for docker run arguments (easy to extend with `-e` flags), `instances_add()` uses atomic jq writes (extend schema to include type), and `menu.sh` has established interactive patterns to follow.

**Primary recommendation:** Follow the locked decisions exactly -- `.env` for storage, `docker run -e` for injection, native installer via `curl | sh`, gh CLI via official apt repo. The implementation is straightforward extensions of existing patterns.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- All credentials stored in `.env` file in project root (standard KEY=value format)
- `.env` file must be .gitignored
- Single file for all credentials: ANTHROPIC_API_KEY, GITHUB_TOKEN, and any future keys
- Credentials injected into containers via `docker run -e` flags at runtime
- Never baked into Docker image layers (CRED-04)
- If ANTHROPIC_API_KEY is missing from .env: warn but continue (container starts, Claude Code won't work)
- If GITHUB_TOKEN is missing from .env: warn but continue (gh CLI won't authenticate)
- Native installer via `curl | sh` during docker build (baked into image)
- Always install latest version -- no version pinning
- Run installer as claude user inside Dockerfile
- Node.js/NPM kept in image (needed for GSD framework and development tasks)
- gh CLI installed during docker build via GitHub's official apt repo
- Authentication via GITHUB_TOKEN environment variable (gh CLI reads it natively -- no explicit auth step needed)
- No gh auth setup-git or additional configuration required
- Interactive numbered menu when creating new instance: [1] Minimal CLI, [2] GUI Desktop (Phase 4)
- Menu shown even when only one type is available (Phase 2 has only CLI)
- Container type stored in .instances.json per instance: `{ port: 2222, type: "cli" }`
- Instance list in main menu shows type next to name and status

### Claude's Discretion
- Exact .env parsing implementation in Bash
- Dockerfile layer ordering and optimization
- Error message wording for missing credentials
- How to handle .env file creation (auto-create template vs manual)
- Native installer URL and invocation details

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CONT-01 | User can build and run a minimal CLI container | Dockerfile modifications (native installer, gh CLI), existing docker_build/docker_run_instance functions |
| CONT-03 | Instance manager presents container type selection when creating new instances | Menu sub-menu pattern, instances.json schema extension with type field |
| INST-01 | Claude Code installed via native installer (not NPM) during container build | Native installer command: `curl -fsSL https://claude.ai/install.sh \| bash`, run as claude user |
| CRED-01 | ANTHROPIC_API_KEY automatically injected into container environment | .env parsing + `docker run -e ANTHROPIC_API_KEY=...` flag |
| CRED-02 | GitHub CLI pre-installed in containers | Official apt repo installation in Dockerfile |
| CRED-03 | GitHub CLI auto-authenticated with user-provided token | GITHUB_TOKEN env var injected at runtime; gh CLI reads it natively |
| CRED-04 | Credentials never baked into Docker images (runtime injection only) | docker run -e flags only, never ARG/ENV in Dockerfile, verify with docker history |
</phase_requirements>

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Docker | Host-installed | Container engine | Already required by Phase 1 |
| Ubuntu 24.04 | Base image | Container OS | Already used in existing Dockerfile |
| Claude Code | Latest (native) | AI coding assistant | Native installer is officially recommended |
| GitHub CLI (gh) | Latest from official repo | GitHub operations | Official apt repo ensures API compatibility |
| Node.js LTS | From nodesource | Runtime for GSD framework | Already in Dockerfile |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| jq | JSON manipulation for .instances.json | Already a dependency from Phase 1 |
| curl | Download native installer | Already in Dockerfile |
| wget | Download gh CLI keyring | Needed for official gh repo setup |

## Architecture Patterns

### Credential Flow
```
User's .env file (host)
    |
    v
bin/csm reads .env at container start time
    |
    v
docker run -e ANTHROPIC_API_KEY=xxx -e GITHUB_TOKEN=yyy ...
    |
    v
Container environment has credentials available
    |
    v
Claude Code reads ANTHROPIC_API_KEY natively
gh CLI reads GITHUB_TOKEN natively (GH_TOKEN also works, same precedence)
```

### .env File Format
```
# Claude Sandbox Manager credentials
ANTHROPIC_API_KEY=sk-ant-xxxxx
GITHUB_TOKEN=ghp_xxxxx
```

### Modified Dockerfile Structure (Recommended Layer Order)
```dockerfile
FROM ubuntu:24.04

# 1. System packages (changes rarely -- cached well)
RUN apt-get update && apt-get install -y \
    openssh-server curl git sudo wget \
    && rm -rf /var/lib/apt/lists/*

# 2. GitHub CLI from official repo (changes rarely)
RUN wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# 3. Node.js LTS (changes rarely)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# 4. User setup (changes rarely)
RUN useradd -m -s /bin/bash claude \
    && usermod -aG sudo claude \
    && echo 'claude ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/claude \
    && chmod 0440 /etc/sudoers.d/claude

# 5. SSH setup (same as Phase 1)
# ... host key, authorized_keys setup ...

# 6. Claude Code native installer (as claude user -- may update frequently)
USER claude
RUN curl -fsSL https://claude.ai/install.sh | bash
# Ensure claude binary is on PATH for all sessions
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/claude/.bashrc

# 7. GSD framework (as claude user)
RUN npx -y get-shit-done-cc@latest --global

USER root
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
```

### .env Parsing Pattern (Recommended)
```bash
# Safe .env parser -- handles comments, blank lines, and quoted values
_load_env_file() {
    local env_file="${CSM_ROOT}/.env"

    if [[ ! -f "$env_file" ]]; then
        return 1
    fi

    local line key value
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # Extract key=value (strip inline comments, trim whitespace)
        key="${line%%=*}"
        value="${line#*=}"

        # Strip surrounding quotes from value
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"

        # Trim whitespace from key
        key="$(echo "$key" | tr -d '[:space:]')"

        # Export to caller's environment
        printf -v "$key" '%s' "$value"
    done < "$env_file"
}
```

### Credential Injection in docker_run_instance()
```bash
# In docker_run_instance(), after existing cmd array setup:
# Load credentials from .env
local anthropic_key="" github_token=""
if [[ -f "${CSM_ROOT}/.env" ]]; then
    # Parse .env file
    _load_env_file
fi

# Inject credentials via -e flags (warn if missing)
if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    cmd+=(-e "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}")
else
    msg_warn "ANTHROPIC_API_KEY not set in .env -- Claude Code will not authenticate"
fi

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    cmd+=(-e "GITHUB_TOKEN=${GITHUB_TOKEN}")
else
    msg_warn "GITHUB_TOKEN not set in .env -- GitHub CLI will not authenticate"
fi
```

### Instance Registry Schema Extension
```json
{
  "default": {
    "port": 2222,
    "type": "cli"
  }
}
```

### Anti-Patterns to Avoid
- **Baking credentials into Dockerfile ARG/ENV:** Visible in `docker history`. Always use runtime `-e` flags.
- **Using `docker run --env-file`:** Tempting but less control over individual missing-key warnings. Use explicit `-e` flags instead.
- **Running native installer as root:** The installer puts binaries in `~/.local/bin`. Run as the claude user so the binary lands in `/home/claude/.local/bin`.
- **Forgetting PATH for native installer:** The native installer installs to `~/.local/bin` which may not be on PATH in non-interactive shells. Must add to `.bashrc` or `.profile`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| GitHub CLI authentication | Custom git credential helpers | GITHUB_TOKEN env var | gh CLI reads it natively, zero config needed |
| Claude Code installation | NPM global install | Native installer `curl \| bash` | Official recommendation, self-contained, auto-updates |
| .env file parsing (complex) | Full dotenv spec parser | Simple line-by-line reader | Our .env is simple KEY=value; no multiline, no interpolation needed |
| Credential security verification | Manual layer inspection scripts | `docker history --no-trunc` | Standard Docker tool for verifying no secrets in layers |

**Key insight:** Both Claude Code and gh CLI are designed to read credentials from environment variables natively. No auth setup commands, credential helpers, or config files are needed -- just inject the right env vars at runtime.

## Common Pitfalls

### Pitfall 1: Native Installer PATH Not Available
**What goes wrong:** Claude Code binary installs to `~/.local/bin` but SSH sessions don't source `.bashrc` (non-login, non-interactive shells).
**Why it happens:** The native installer adds PATH to `.bashrc`, but `docker exec` or direct `ssh user@host command` may not load it.
**How to avoid:** Ensure `~/.local/bin` is on PATH in both `.bashrc` AND `.profile`. Alternatively, create a symlink from `/usr/local/bin/claude` to the installed binary.
**Warning signs:** `claude: command not found` when SSH-ing into container.

### Pitfall 2: Credentials Visible in Docker History
**What goes wrong:** Using `ARG` or `ENV` in Dockerfile to pass secrets makes them visible in `docker history`.
**Why it happens:** Docker layers are immutable and inspectable.
**How to avoid:** Only pass credentials via `docker run -e` at runtime. Never in Dockerfile.
**Warning signs:** Running `docker history --no-trunc <image>` shows credential values.

### Pitfall 3: .env File Not .gitignored
**What goes wrong:** Credentials committed to version control.
**Why it happens:** .gitignore entry missing or wrong path.
**How to avoid:** The existing `.gitignore` does NOT contain `.env` -- this must be added. Verify with `git status` after creating .env.
**Warning signs:** `git status` shows `.env` as untracked.

### Pitfall 4: GH_TOKEN vs GITHUB_TOKEN Confusion
**What goes wrong:** Using wrong variable name or both, causing unexpected precedence.
**Why it happens:** gh CLI supports both `GH_TOKEN` (higher priority) and `GITHUB_TOKEN` (lower priority).
**How to avoid:** Use `GITHUB_TOKEN` consistently in .env and injection. It's the more standard name and works with gh CLI. If the user also has `GH_TOKEN` set, gh CLI will prefer that.
**Warning signs:** `gh auth status` shows unexpected token source.

### Pitfall 5: Existing instances_add() Schema Break
**What goes wrong:** Adding `type` field to instances_add() breaks existing `.instances.json` files from Phase 1.
**Why it happens:** Existing entries only have `{ "port": 2222 }` without a `type` field.
**How to avoid:** When reading instance data, default missing `type` to `"cli"`. Never assume the field exists.
**Warning signs:** jq errors when accessing `.type` on old entries.

### Pitfall 6: wget Not in Ubuntu 24.04 Minimal
**What goes wrong:** GitHub CLI apt repo setup needs wget for keyring download, but `wget` is not in the base ubuntu:24.04 image.
**Why it happens:** Ubuntu Docker images are minimal and don't include wget.
**How to avoid:** Add `wget` to the apt-get install line, or use `curl` instead for the keyring download.
**Warning signs:** `wget: command not found` during docker build.

## Code Examples

### Verifying Credentials Not in Image Layers (CRED-04)
```bash
# Source: Docker documentation
# Run after building image to verify no secrets leaked
docker history --no-trunc "claude-sandbox-${name}" | grep -i -E "(anthropic|github_token|api_key)"
# Should return no results
```

### gh CLI Token Verification Inside Container
```bash
# Source: https://cli.github.com/manual/gh_help_environment
# Inside the container, verify gh can authenticate:
gh auth status
# Expected output when GITHUB_TOKEN is set:
# github.com
#   Logged in to github.com account <username> (GITHUB_TOKEN)
```

### Container Type Menu Pattern
```bash
# Consistent with existing menu.sh pattern (single-character dispatch)
menu_select_container_type() {
    echo ""
    echo "Select container type:"
    echo "  [1] Minimal CLI"
    echo "  [2] GUI Desktop (coming soon)"
    echo ""

    local choice
    read -rp "Type [1]: " choice

    case "${choice:-1}" in
        1) echo "cli" ;;
        2) msg_warn "GUI Desktop not yet available."; echo "cli" ;;
        *) msg_error "Invalid selection."; echo "cli" ;;
    esac
}
```

### Safe .env Template Auto-Creation
```bash
_ensure_env_file() {
    local env_file="${CSM_ROOT}/.env"
    if [[ ! -f "$env_file" ]]; then
        cat > "$env_file" << 'ENVEOF'
# Claude Sandbox Manager - Credentials
# These values are injected into containers at runtime (never baked into images).

# Required for Claude Code to authenticate
ANTHROPIC_API_KEY=

# Required for GitHub CLI (gh) to authenticate
GITHUB_TOKEN=
ENVEOF
        msg_warn "Created ${env_file} -- please add your credentials"
    fi
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `npm install -g @anthropic-ai/claude-code` | `curl -fsSL https://claude.ai/install.sh \| bash` | 2025 (GA announcement) | No Node.js dependency for Claude Code itself; auto-updates built in |
| `gh auth login --with-token` | `GITHUB_TOKEN` env var | Always supported | No auth step needed; gh reads token from env automatically |
| Manual apt repo for gh | Still official apt repo | Current | Node:20 image includes gh; ubuntu:24.04 does not |

**Deprecated/outdated:**
- NPM installation of Claude Code: Officially deprecated. Native installer is faster, has no dependencies, and auto-updates.
- Note: Anthropic's own devcontainer Dockerfile still uses npm as of 2026-03, but their docs explicitly say native is recommended and npm is deprecated.

## Open Questions

1. **Native installer in non-interactive Docker build**
   - What we know: `curl -fsSL https://claude.ai/install.sh | bash` works interactively. Docker builds are non-interactive.
   - What's unclear: Whether the installer prompts for anything or has flags to suppress prompts.
   - Recommendation: Test during implementation. The installer is designed for `curl | bash` piping which implies non-interactive support. If issues arise, fall back to npm as Anthropic's devcontainer does.

2. **Native installer binary location in PATH**
   - What we know: Installs to `~/.local/bin/claude`. SSH sessions may not source `.bashrc`.
   - What's unclear: Whether `/home/claude/.local/bin` is already on default PATH in ubuntu:24.04.
   - Recommendation: Explicitly add to `.bashrc` and `.profile`, and optionally symlink to `/usr/local/bin/`.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | BATS (installed via npm devDependency) + ShellCheck |
| Config file | None -- BATS runs directly on test files |
| Quick run command | `npx bats test/` |
| Full suite command | `npx bats test/ && npx shellcheck lib/*.sh bin/csm` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CONT-01 | Build and run minimal CLI container | integration | `npx bats test/test_docker.bats -f "build cli"` | No -- Wave 0 |
| CONT-03 | Container type selection menu | unit | `npx bats test/test_menu.bats -f "type select"` | No -- Wave 0 |
| INST-01 | Claude Code installed via native installer | integration | `npx bats test/test_docker.bats -f "claude installed"` | No -- Wave 0 |
| CRED-01 | ANTHROPIC_API_KEY injected | unit | `npx bats test/test_credentials.bats -f "anthropic key"` | No -- Wave 0 |
| CRED-02 | GitHub CLI pre-installed | integration | `npx bats test/test_docker.bats -f "gh installed"` | No -- Wave 0 |
| CRED-03 | GitHub CLI auto-authenticated | unit | `npx bats test/test_credentials.bats -f "github token"` | No -- Wave 0 |
| CRED-04 | Credentials not in image layers | integration | `npx bats test/test_credentials.bats -f "no secrets in layers"` | No -- Wave 0 |

### Sampling Rate
- **Per task commit:** `npx bats test/ -x`
- **Per wave merge:** `npx bats test/ && npx shellcheck lib/*.sh bin/csm`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/test_credentials.bats` -- covers CRED-01, CRED-03, CRED-04 (.env parsing, injection logic, layer inspection)
- [ ] `test/test_docker.bats` -- covers CONT-01, INST-01, CRED-02 (container build/run, claude binary check, gh check)
- [ ] `test/test_menu.bats` -- covers CONT-03 (container type selection submenu)
- [ ] `test/` directory creation
- [ ] Note: BATS already available via npm devDependency pattern from Phase 1; ShellCheck available via npm

## Sources

### Primary (HIGH confidence)
- [Claude Code official docs - Setup](https://code.claude.com/docs/en/setup) - Native installer command, installation path, system requirements
- [GitHub CLI official environment docs](https://cli.github.com/manual/gh_help_environment) - GH_TOKEN/GITHUB_TOKEN precedence and behavior
- [GitHub CLI Linux install docs](https://github.com/cli/cli/blob/trunk/docs/install_linux.md) - Official apt repository setup commands
- [Anthropic claude-code devcontainer Dockerfile](https://github.com/anthropics/claude-code/blob/main/.devcontainer/Dockerfile) - Reference Docker setup

### Secondary (MEDIUM confidence)
- [Anthropic threads announcement](https://www.threads.com/@claudeai/post/DQe2GgUAK6m/) - Native installer GA, no Node.js dependency
- [.env parsing patterns](https://gist.github.com/mihow/9c7f559807069a03e302605691f85572) - Community-verified Bash .env loading patterns

### Tertiary (LOW confidence)
- Native installer behavior in Docker build (non-interactive) -- not explicitly documented; needs validation during implementation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official docs confirm all tools and installation methods
- Architecture: HIGH - Straightforward extensions of existing Phase 1 patterns
- Pitfalls: HIGH - Well-documented Docker security practices; PATH issue is common and well-understood
- .env parsing: MEDIUM - No formal .env spec; implementation is simple enough that edge cases are unlikely

**Research date:** 2026-03-13
**Valid until:** 2026-04-13 (stable domain; native installer URL unlikely to change)
