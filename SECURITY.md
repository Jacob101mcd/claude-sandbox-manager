# Security

This document explains the security posture of Claude Sandbox Manager: what's hardened, what's your responsibility, and the trade-offs involved in running AI agents in containers.

The goal is honest, practical disclosure — not alarming you, but not hiding anything either.

---

## Risk Summary

| Risk | Severity | Mitigation | Status |
|------|----------|------------|--------|
| Container escape | Low | Dropped capabilities, no-new-privileges, resource limits | 🟢 Hardened |
| Credential exposure | Medium | `.env` gitignored, runtime injection only, never baked into image | 🟢 Hardened |
| Network access from container | Medium | Outbound internet intentionally enabled (Claude Code needs it) | 🟡 User responsibility |
| Resource abuse | Low | Memory and CPU limits enforced via docker flags | 🟢 Hardened |
| AI agent permissions (`--dangerously-skip-permissions`) | Medium | Container isolation is what makes this trade-off acceptable | 🟡 User responsibility |
| SSH key exposure | Low | Per-instance key pairs, localhost-only binding, key-only auth | 🟢 Hardened |
| Volume mount exposure | Medium | Only your workspace directory is mounted — no host system paths | 🟡 User responsibility |
| Image supply chain | Low | Dockerfile builds from official `ubuntu:22.04` base | 🟢 Hardened |

---

## Container Escape

Containers are sandboxed but not VMs. Kernel-level exploits could theoretically cross container boundaries. CSM mitigates this by dropping unnecessary Linux capabilities at container start:

- `MKNOD` — prevents creating device files
- `AUDIT_WRITE` — prevents writing to audit log (reduces attack surface)
- `SETFCAP` — prevents setting file capabilities
- `SETPCAP` — prevents changing process capabilities
- `NET_BIND_SERVICE` — prevents binding to privileged ports
- `SYS_CHROOT` — prevents chroot calls
- `FSETID` — prevents setuid/setgid on file creation

`--no-new-privileges` is also set, preventing privilege escalation via setuid binaries inside the container.

---

## Credential Exposure

API keys and tokens are sensitive. CSM's approach:

- `.env` file is gitignored — your credentials never end up in version control
- Credentials are injected at runtime via `docker run -e` flags — they are never written into image layers
- No credentials are printed to stdout in normal operation

If you add credentials to `Dockerfile` or bake them into a custom image layer, that protection is bypassed — don't do that.

---

## Network Access

Claude Code requires outbound internet access to reach the Anthropic API and to run `npm install`, `pip install`, and similar operations during coding tasks. **Containers have full outbound internet access by default** — this is intentional and necessary for Claude Code to function.

What this means: the AI agent running inside the container can make outbound HTTP/HTTPS requests. It cannot receive inbound connections from the internet (no open ports on the host by default beyond the SSH forwarding you set up).

If you're concerned about egress, consider running containers on an isolated Docker network with a firewall or proxy — this is outside the scope of CSM but is possible with Docker network configuration.

---

## Resource Abuse

An AI agent that runs many parallel tasks or gets into a loop could consume excessive CPU or memory. CSM enforces limits:

- **Memory:** `--memory=2g` by default (configurable in `csm-config.json`)
- **CPU:** `--cpus=2` by default (configurable in `csm-config.json`)

These are enforced by the Docker daemon via Linux cgroups. If Claude Code exceeds memory, the container process will be OOM-killed — abrupt but contained.

---

## AI Agent Permissions (`--dangerously-skip-permissions`)

Claude Code is started inside each container with `--dangerously-skip-permissions`. This flag tells Claude Code to proceed with file system operations without asking for confirmation on each one.

**Why this is acceptable here:** The container is the sandbox. Claude Code has full filesystem access *inside the container*, which only contains your workspace and the development tools you've installed. It does not have access to your host filesystem (beyond the workspace directory you explicitly mount), your SSH keys, your credentials, or other processes on your machine.

**Why this flag exists:** Claude Code's normal confirmation flow is designed for running directly on a developer's machine where the stakes are high. Inside a disposable container, that friction reduces utility without adding meaningful protection.

**What you're responsible for:** Understanding that the agent can freely modify, delete, and create files in the mounted workspace. Review container behavior when running sensitive operations. Keep your workspace backup before extended autonomous sessions.

---

## Docker Desktop vs Docker Engine

The security boundary differs depending on your Docker installation:

**Docker Desktop (macOS, Windows, Linux optional)**
- Runs containers inside a lightweight Linux VM (Hyperkit on macOS, Hyper-V/WSL2 on Windows)
- Even if a container escape occurred, the attacker would land inside the VM — not on your host OS
- Stronger isolation for security-sensitive workloads
- Recommended if you're running untrusted workloads or want maximum isolation

**Docker Engine (Linux direct)**
- Containers run directly on the host kernel via namespaces and cgroups
- No VM boundary — a kernel-level exploit could reach the host
- Still well-isolated for typical workloads; billions of containers run this way in production
- CSM's capability drops and `--no-new-privileges` reduce the attack surface, but there's no VM layer

**Recommendation:** If you're on macOS or Windows, Docker Desktop is your default and provides strong isolation. If you're on Linux and security is a concern, consider running Docker Engine with additional hardening (e.g., gVisor, user namespaces) or use a VM.

---

## What We Do

- Drop 7 Linux capabilities on every container
- Set `--no-new-privileges` to prevent privilege escalation
- Enforce configurable memory and CPU limits
- SSH bound to `127.0.0.1` only (no external exposure)
- SSH key-only authentication, no password login, no root password
- Credentials injected at runtime, never in image layers
- `.env` gitignored in project root
- Containers do not run as root (container user is `claude`)
- Image built from official `ubuntu:22.04` base

---

## What's Your Responsibility

- **Rotate API keys** periodically, and immediately if you suspect exposure
- **Review workspace contents** before committing to git — the agent may have created files you don't want published
- **Keep Docker updated** — security fixes are released regularly
- **Understand `--dangerously-skip-permissions`** — know what the agent can do inside the container
- **Don't mount sensitive host paths** — the default mount is just your workspace; adding `~/.ssh`, `/etc`, or other sensitive directories expands the agent's reach
- **Monitor for unexpected resource usage** — if a container is pegging CPU for hours, investigate
- **Review container logs** — `docker logs <container>` shows what Claude Code has been doing

---

## Hardening Tips

**Rotate API keys regularly.** Your `ANTHROPIC_API_KEY` and `GITHUB_TOKEN` are the highest-value secrets in this setup. Rotate them at a schedule that matches your risk tolerance.

**Use Docker Desktop for VM isolation.** On macOS and Windows, Docker Desktop is the default. On Linux, you're on Docker Engine; consider whether the VM boundary matters for your threat model.

**Set conservative resource limits.** If you're running CSM on a shared machine or a laptop with limited RAM, lower the defaults in `csm-config.json`:
```json
{
  "defaults": {
    "memory_limit": "1g",
    "cpu_limit": 1
  }
}
```

**Review workspace contents before pushing.** An agent working autonomously for an hour may create API keys in config files, write test data containing sensitive values, or modify gitignore files. Review diffs carefully.

**Use per-project workspaces.** Don't reuse one container for multiple unrelated projects — keep workspaces isolated so one project's context doesn't bleed into another.

**Inspect images before use.** If you've extended the `Dockerfile` with custom layers, verify you haven't accidentally added secrets or backdoored tools.

---

## Reporting Issues

Found a security issue? Open a [GitHub issue](https://github.com/Jacob101mcd/claude-sandbox-manager/issues). For sensitive findings, mention it's security-related in the title so it gets prompt attention.
