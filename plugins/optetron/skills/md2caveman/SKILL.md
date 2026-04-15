---
name: md2caveman
description: Use when you need to compress a markdown file (notes, docs, memory files, reports) into caveman-speak to reduce input tokens while preserving code, URLs, headings, and technical substance. Overwrites the input by default; use `--out <path>` for non-destructive output. Requires hq-tools installed via `uv tool install --from ~/proj/optetron-hq/tools hq-tools` and `ANTHROPIC_API_KEY` in env.
---

# md2caveman

Compress natural-language markdown into caveman-speak to reduce LLM input tokens while keeping all technical content intact.

## When to Use

- Compressing verbose notes, reports, or memory files before feeding them as context
- NOT for already-terse content, code-only files, or previously-compressed files

## Prerequisites

`md2caveman` must be on PATH:

```bash
uv tool install --from ~/proj/optetron-hq/tools hq-tools
```

`ANTHROPIC_API_KEY` must be set in the environment.

## Usage

```bash
md2caveman <file.md>
```

Overwrites `<file.md>` in place; prints the written path to stdout on success.

## Flags

| Flag | Description |
|------|-------------|
| `--level {lite,full,ultra}` | Compression intensity (default: `full`) |
| `--out <path>` | Write compressed output to an alternative path (non-destructive) |

## Notes

**Safety:** A built-in validator checks that URLs, code blocks, and headings are preserved after compression. On failure it retries once, then aborts without overwriting — the original is always safe if validation fails.

**First run:** Uses `claude-sonnet-4-5` by default. Override with `CAVEMAN_MODEL` env var.

## Failure Modes

- **Exit 2** — bad CLI: missing file, wrong extension, invalid level, `--out` parent directory does not exist
- **Exit 1** — compression or API error — read the one-line stderr message

For upstream caveman details, see [caveman on GitHub](https://github.com/JuliusBrussee/caveman).
