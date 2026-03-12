# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Environment

This is a Docker-based sandbox (Ubuntu 24.04) accessed via SSH on port 2222. The workspace is bind-mounted from the Windows host at `C:\claude-sandbox\workspace`.

- **Working directory inside container:** `/home/claude/workspace`
- **Real test data:** `Press Workcenters/` — 9 workcenter directories containing hundreds of real RSLogix 500 `.rss` files

## Commands

```bash
# Install package in editable mode (run from workspace root)
pip install -e ".[dev]"

# Run all tests
pytest

# Run a single test file
pytest tests/test_parsers_ladder.py

# Run a specific test
pytest tests/test_parsers_ladder.py::test_function_name -v

# Lint
ruff check .

# Decompile an RSS file
rss-decompile "Press Workcenters/WC 101/some_file.RSS"
```

## Project: rss_decompiler

A Python 3.11+ CLI tool that decompiles RSLogix 500 `.rss` binary PLC project files into structured JSON.

### Architecture

`.rss` files are OLE/CFB compound documents (like MS Office files) containing named streams: PROGRAM FILES, DATA FILES, I/O CONFIGURATION, MEM DATABASE, etc. Each stream has a 16-byte RSLogix header followed by a zlib-compressed payload.

**Two-pass pipeline** (`cli.py`):
1. **Pass 1:** Scan MEM DATABASE stream to extract rung comments and symbol table
2. **Pass 2:** Dispatch all OLE streams through the parser registry, injecting rung comments into PROGRAM FILES output

**Parser registry** (`parsers/__init__.py`): A `REGISTRY` dict maps stream name patterns to parser functions. Unknown streams fall back to hex dump (`hex_fallback.py`) so no data is ever dropped.

### Key modules

| Module | Purpose |
|---|---|
| `cli.py` | Typer CLI entry point, two-pass orchestration |
| `container.py` | OLE/CFB container operations (stream enumeration, summary extraction) |
| `dispatcher.py` | Routes streams to parsers via REGISTRY |
| `stream_header.py` | 16-byte header decoding + zlib decompression |
| `format_notes.py` | Constants: stream names, data file types, opcodes, processor types |
| `model.py` | TypedDict definitions for output structures |
| `parsers/ladder.py` | Ladder logic + MEM DATABASE (rung comments) — most complex parser |
| `parsers/data_files.py` | Timers, counters, integers, floats, bits |
| `parsers/io_config.py` | Rack/slot/module I/O layout |
| `parsers/metadata.py` | Version, processor info, summary information |

### Dependencies

- `olefile` — OLE/CFB compound document parsing
- `construct` — Binary structure declarations
- `typer` + `rich` — CLI framework and output formatting

## Claude Skill Integration

The `rss-decompiler-skill/` directory provides a Claude skill for decompiling RSS files. It is symlinked into `.claude/commands/rss-decompile.md`.
