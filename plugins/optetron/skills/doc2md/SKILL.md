---
name: doc2md
description: Use when you need to convert a PDF, DOCX, XLSX, PPTX, or HTML document into token-efficient markdown for LLM context (reading papers, reports, client briefs, specs). Produces clean markdown with tables preserved and page headers/footers stripped. Requires hq-tools installed via `uv tool install --from ~/proj/optetron-hq/tools hq-tools`.
---

# doc2md

Convert documents (PDF, DOCX, XLSX, PPTX, HTML, MD) to clean markdown for LLM ingestion.

## When to Use

- Converting source documents into markdown so an LLM can read them as context
- NOT for interactive document manipulation — for that, consider [docling's MCP server](https://docling-project.github.io/docling/)

## Prerequisites

`doc2md` must be on PATH:

```bash
uv tool install --from ~/proj/optetron-hq/tools hq-tools
```

## Usage

```bash
doc2md <path-to-document>
```

Prints the written `.md` file path to stdout on success.

## Flags

| Flag | Description |
|------|-------------|
| `--out <path>` | Write markdown to a specific output path instead of the default |
| `--device auto\|cpu\|cuda` | Force inference device (default: `auto`) |
| `--keep-headers-footers` | Preserve page headers and footers (stripped by default) |

## Notes

**First run:** docling downloads ~500 MB of models into `~/.cache/docling` on first invocation. Subsequent runs are fast.

**Performance:** On a CUDA-capable host, pass `--device cuda` for significantly faster conversion.

## Supported Formats

PDF, DOCX, XLSX, PPTX, HTML, MD

## Failure Modes

- **Exit 2** — bad CLI usage: missing file, unrecognized device value, `--out` parent directory does not exist
- **Exit 1** — conversion error — read the one-line stderr message

For advanced docling options, see [docling docs](https://docling-project.github.io/docling/).
