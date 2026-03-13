---
phase: 02-container-engine
verified: 2026-03-13T19:15:00Z
status: human_needed
score: 11/11 must-haves verified (automated); 2 items require human testing
human_verification:
  - test: "SSH into a running container and run `claude --version`"
    expected: "Claude Code binary is found on PATH and reports a version (installed via native installer, not NPM)"
    why_human: "Dockerfile installs via curl | bash but Docker build has not been run in this environment; PATH availability for non-interactive SSH sessions cannot be verified from the host without running the actual container"
  - test: "Start a container with GITHUB_TOKEN set in .env, then SSH in and run `gh auth status`"
    expected: "gh reports authenticated via GITHUB_TOKEN; able to run `gh repo list` or equivalent"
    why_human: "CRED-03 authentication relies on gh CLI's native GITHUB_TOKEN env var support; this is well-documented behavior but the end-to-end flow (env file -> docker -e flag -> live container -> gh reads env) requires a running container to confirm"
---

# Phase 2: Container Engine Verification Report

**Phase Goal:** Users can create, start, stop, SSH into, and remove sandbox instances running the minimal CLI container variant, with API key and GitHub credentials automatically available inside the container
**Verified:** 2026-03-13T19:15:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

All truths are drawn from the ROADMAP.md Success Criteria for Phase 2 and the combined must_haves from 02-01-PLAN.md and 02-02-PLAN.md.

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | User can create a new minimal CLI instance and be prompted for container type | VERIFIED | `menu_action_new` calls `menu_select_container_type`, stores result, and registers via `instances_add "$name" "$container_type"` — menu.sh:184-188 |
| 2  | .env file is parsed correctly and credentials loaded into shell variables | VERIFIED | `credentials_load` in lib/credentials.sh:45-80 reads line-by-line, strips comments, blank lines, and surrounding quotes; exports each KEY=VALUE |
| 3  | Missing .env file auto-creates template and warns the user | VERIFIED | `credentials_ensure_env_file` in lib/credentials.sh:18-39 creates template with `msg_warn`; called from `docker_start_instance` (docker.sh:125) |
| 4  | Missing individual credentials warn but do not block container creation | VERIFIED | `credentials_load || true` in docker.sh:74 handles missing .env gracefully; `credentials_get_docker_env_flags` emits `msg_warn` per missing key and continues |
| 5  | Dockerfile builds Claude Code via native installer (not NPM) | VERIFIED | `RUN curl -fsSL https://claude.ai/install.sh \| bash` present at Dockerfile:54; no `npm install -g @anthropic-ai/claude-code` anywhere in the file |
| 6  | Dockerfile installs GitHub CLI from official apt repository | VERIFIED | Dockerfile:13-19 uses `wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg` pipeline and installs `gh` via apt |
| 7  | Credentials are never baked into Docker image layers | VERIFIED | `grep -niE "ANTHROPIC_API_KEY\|GITHUB_TOKEN" scripts/Dockerfile` returns no results; no ARG or ENV instructions for credentials |
| 8  | docker_run_instance injects ANTHROPIC_API_KEY and GITHUB_TOKEN via -e flags | VERIFIED | docker.sh:73-76: `credentials_load \|\| true`, `credentials_get_docker_env_flags`, `cmd+=("${CSM_DOCKER_ENV_FLAGS[@]}")` wired immediately before image name |
| 9  | Container type selection menu appears when creating a new instance | VERIFIED | `menu_select_container_type` function in menu.sh:117-130 presents numbered list; called in `menu_action_new` at menu.sh:185 |
| 10 | Instance registry stores type field; old entries default to cli | VERIFIED | `instances_add` accepts `$2` type param (default "cli"), stores in JSON; `instances_get_type` uses `// "cli"` jq default for backward compat (instances.sh:46-47, 65) |
| 11 | Instance list shows container type next to name and status | VERIFIED | `instances_list_with_status` calls `instances_get_type` and formats as `"$name [$type] (port $port) - $status"` (instances.sh:203-208) |

**Score:** 11/11 truths verified (automated)

---

## Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `lib/credentials.sh` | VERIFIED | 98 lines; exports `credentials_ensure_env_file`, `credentials_load`, `credentials_get_docker_env_flags`; CSM_ROOT guard at top |
| `scripts/Dockerfile` | VERIFIED | 64 lines; native installer present; gh CLI from official apt repo; no NPM Claude Code install; no credentials in layers |
| `tests/credentials.bats` | VERIFIED | 147 lines; 9 tests covering all specified behaviors (ANTHROPIC_API_KEY, GITHUB_TOKEN, comments, blank lines, quoted values, template creation, no-overwrite, missing .env returns 1, docker flags) |
| `lib/docker.sh` | VERIFIED | Contains `credentials_load`, `credentials_get_docker_env_flags`, `CSM_DOCKER_ENV_FLAGS` expansion, and `credentials_ensure_env_file` call |
| `lib/instances.sh` | VERIFIED | `instances_add` accepts type param with "cli" default; `instances_get_type` with `// "cli"` jq fallback; `instances_list_with_status` includes type display |
| `lib/menu.sh` | VERIFIED | `menu_select_container_type` function present; wired into `menu_action_new`; `menu_main` registers default with "cli" type |
| `bin/csm` | VERIFIED | Sources `lib/credentials.sh` on line 17, after `common.sh` and before `platform.sh` |
| `tests/instances.bats` | VERIFIED | Includes type field tests: stores type, defaults to "cli", `instances_get_type`, backward compat |
| `tests/menu.bats` | VERIFIED | 46 lines; 4 tests for `menu_select_container_type` with inputs 1, empty, 2 (GUI fallback), and invalid |
| `.gitignore` | VERIFIED | `.env` entry present at line 12 |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `lib/credentials.sh` | `.env` | `while IFS= read -r line` | WIRED | credentials.sh:52 uses exact pattern; reads `${CSM_ROOT}/.env` |
| `scripts/Dockerfile` | `claude.ai/install.sh` | `curl -fsSL ... \| bash` | WIRED | Dockerfile:54 `RUN curl -fsSL https://claude.ai/install.sh \| bash` |
| `lib/docker.sh` | `lib/credentials.sh` | `credentials_load` + `CSM_DOCKER_ENV_FLAGS` array | WIRED | docker.sh:74-76: load, get flags, append to cmd array in correct order |
| `lib/menu.sh` | `lib/instances.sh` | `instances_add "$name" "$container_type"` | WIRED | menu.sh:188 passes type; menu.sh:246 passes "cli" for auto-created default |
| `bin/csm` | `lib/credentials.sh` | `source "$CSM_ROOT/lib/credentials.sh"` | WIRED | bin/csm:17; correct dependency order (after common.sh, before platform.sh) |

---

## Requirements Coverage

All requirement IDs declared across both plans are accounted for. REQUIREMENTS.md traceability table maps all seven to Phase 2.

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| CONT-01 | 02-01, 02-02 | User can build and run a minimal CLI container | SATISFIED | Dockerfile builds ubuntu:24.04 with gh CLI and Claude Code; docker_start_instance orchestrates build + run; tests confirmed via docker.bats |
| CONT-03 | 02-02 | Instance manager presents container type selection when creating new instances | SATISFIED | `menu_select_container_type` wired into `menu_action_new`; type stored per instance; 4 menu.bats tests |
| INST-01 | 02-01 | Claude Code installed via native installer (not NPM) | SATISFIED | Dockerfile:54 `curl -fsSL https://claude.ai/install.sh \| bash` as `claude` user; PATH set in `.bashrc` and `.profile`; NPM install line absent |
| CRED-01 | 02-01, 02-02 | ANTHROPIC_API_KEY automatically injected into container environment | SATISFIED | credentials_load parses .env; credentials_get_docker_env_flags builds -e flag; docker_run_instance appends to cmd array |
| CRED-02 | 02-01 | GitHub CLI pre-installed in containers | SATISFIED | Dockerfile:13-19 installs `gh` from official GitHub apt repository using signed keyring |
| CRED-03 | 02-01, 02-02 | GitHub CLI auto-authenticated with user-provided token on container build | SATISFIED (design-verified) | GITHUB_TOKEN injected via `docker run -e` at runtime; `gh` CLI reads `GITHUB_TOKEN` natively per official docs (no explicit `gh auth` step required by design — confirmed in 02-RESEARCH.md). End-to-end auth flow requires human test (see Human Verification). |
| CRED-04 | 02-01, 02-02 | Credentials never baked into Docker images | SATISFIED | No ARG/ENV/RUN with credentials in Dockerfile; verified via grep; injected only at runtime via -e flags |

**Orphaned requirements:** None. All 7 requirement IDs declared in PLAN frontmatter appear in REQUIREMENTS.md traceability as Phase 2. No Phase 2 requirements in REQUIREMENTS.md exist outside these 7.

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/menu.sh` | 127 | `echo "cli"` after `msg_warn` for GUI option | Info | msg_warn writes to stderr; echo "cli" to stdout — this is correct and intentional. No impact. |
| `tests/docker.bats` | 5-47 | All tests are static file-content greps (no behavioral tests for credential injection flow) | Warning | docker.bats verifies patterns exist in source, not runtime behavior. Covered by credentials.bats test 8 which actually invokes `credentials_get_docker_env_flags` in a live BATS process. No blocking impact. |

No blocker anti-patterns found. No TODOs, FIXME, placeholder returns (return null/return {}/return []), or stub handlers detected in phase deliverables.

---

## Human Verification Required

### 1. Claude Code binary accessible via SSH session

**Test:** Build the Docker image (`docker build -t claude-sandbox-test -f scripts/Dockerfile .` from the project root with valid SSH keys staged), start a container, and SSH in. Run `claude --version` in the SSH session.

**Expected:** Claude Code binary responds with a version string. The binary should be found at `~/.local/bin/claude` and be on PATH via `.profile` sourcing.

**Why human:** The native installer runs `curl -fsSL https://claude.ai/install.sh | bash` at build time in a non-interactive Docker context. The PATH is set in `.bashrc` and `.profile` but SSH sessions may behave differently depending on login vs. non-login shell. Cannot verify from host without running the build and live container.

### 2. GitHub CLI authenticates via injected GITHUB_TOKEN

**Test:** Set `GITHUB_TOKEN=<valid_token>` in the project's `.env` file. Create and start a new instance through the menu (or via `docker_start_instance`). SSH into the running container and run `gh auth status`.

**Expected:** Output shows `Logged in to github.com account <username> (GITHUB_TOKEN)`. Running `gh repo list` should return repositories without additional auth steps.

**Why human:** The implementation correctly injects `GITHUB_TOKEN` via `docker run -e`; `gh` reads it natively. This is well-documented behavior per https://cli.github.com/manual/gh_help_environment. However, the full runtime path (`.env` → `credentials_load` → `-e` flag → live container environment → `gh` reads it) requires a running Docker environment to confirm end-to-end. This is CRED-03's core claim and deserves live validation.

---

## Summary

Phase 2 goal is achieved at the code level. All 11 observable truths are verified against the actual codebase — not SUMMARY claims. Every artifact exists, is substantive, and is correctly wired. All 7 requirement IDs are satisfied with direct code evidence. The 4 task commits (05f2f34, 73ce2e4, 2dfce4a, 3347837) are present in git history with accurate commit messages.

Two items cannot be verified programmatically and require a running Docker environment: (1) that the Claude Code native installer binary is discoverable on PATH in an SSH session, and (2) that GITHUB_TOKEN injection results in live `gh` authentication. Both are structurally correct in the codebase and follow documented tool behavior; human testing closes the loop.

---

_Verified: 2026-03-13T19:15:00Z_
_Verifier: Claude (gsd-verifier)_
