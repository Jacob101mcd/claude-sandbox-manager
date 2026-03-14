# Contributing to Claude Sandbox Manager

Thanks for your interest in contributing! Here's how to get started.

## Reporting Issues

Open a [GitHub Issue](https://github.com/Jacob101mcd/claude-sandbox-manager/issues) to report bugs or request features. Include:

- What you expected to happen
- What actually happened
- Your OS and Docker version (`docker --version`)
- Steps to reproduce

## Development Setup

1. Clone the repo:
   ```bash
   git clone https://github.com/Jacob101mcd/claude-sandbox-manager.git
   cd claude-sandbox-manager
   ```

2. Prerequisites:
   - **Docker Desktop** or **Docker Engine**
   - **Bash** (Linux/macOS) or **PowerShell** (Windows)
   - **[BATS](https://github.com/bats-core/bats-core)** — for running tests

## Project Structure

```
bin/        Main entry point (csm)
lib/        Shell modules (credentials, docker, ssh, instances, settings, menu, etc.)
scripts/    Dockerfile, entrypoint, Windows PowerShell/batch scripts
tests/      BATS test suite
```

## Running Tests

```bash
bats tests/*.bats
```

Tests use mocks for Docker commands and run without a live Docker daemon.

## Submitting Changes

1. Fork the repo and create a feature branch
2. Make your changes
3. Run the test suite and confirm all tests pass
4. Open a pull request with a clear description of what you changed and why

## License

By contributing, you agree that your contributions will be licensed under the [Apache 2.0 License](LICENSE).
