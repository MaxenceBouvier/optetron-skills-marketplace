# Megatask Project Config — Schema

The per-project file at `docs/superpowers/megatask.config.md` carries every parameter the manager substitutes into the worker launch template and uses to drive phase transitions. The skill's **Config bootstrap** flow walks the user through every section below if the file is missing, then writes it and commits.

## Required keys

- `stack.lint`, `stack.test`, `stack.build`
- `issue_source.type` (one of `gh` / `explicit` / `linear`)
- `acceptance_verification.method`
- `models.manager`, `models.worker`, `models.subagent_implementation`, `models.subagent_spec_review`, `models.subagent_code_quality_review`
- `branch_naming.pattern`
- `deploy_guardrails.forbid_autonomous_deploy`
- `reachability.user_reachable`

If any required key is missing, the manager refuses to start the campaign and prompts the user to fix the config.

## Annotated example

```markdown
# Megatask Config

Project params for `/megatask` campaign sessions. Edit to override defaults.

## Stack & verification commands

- install: `npm install`
- lint: `npm run lint`
- test: `npm run test`
- targeted_test: `npm run test -- {path}`        # `{path}` is substituted by the worker for targeted runs
- build: `npm run build`
- typecheck: `tsc --noEmit`                      # optional; omit if not used

## Dev server (optional — set `enabled: false` for non-web projects)

- enabled: true
- start_cmd: `npm run dev`
- url: `http://127.0.0.1:3000`
- worker_port: 3100                              # worker-side dev server for self-checks (avoid clash with manager)
- worker_port_var: PORT                          # env var to set when launching worker dev server
- dev_cmd: `npm run dev`                         # command the worker runs prefixed with `<worker_port_var>=<worker_port>`

## Issue source

- type: gh                                       # one of: gh / explicit / linear
- repo: MaxenceBouvier/some-website              # required if type=gh
- list_path: docs/megatask-issues.md             # required if type=explicit
- linear_team: ENG                               # required if type=linear

## Acceptance verification

- method: chrome-devtools-mcp                    # one of: chrome-devtools-mcp / cli-integration / api-http / custom
- artifact_dir: docs/smoke/issue-{N}/
- description: |
    Manager runs the chrome-devtools MCP server, navigates to each affected route on
    `npm run dev` (port 3000), takes one screenshot per acceptance bullet, queries the
    DOM for non-visual claims, pulls the browser console (any unhandled error / hydration
    warning / 4xx-5xx fetch fails the smoke). Saves to docs/smoke/issue-{N}/.

## Models

- manager: opus
- worker: opus
- subagent_implementation: sonnet
- subagent_spec_review: sonnet
- subagent_code_quality_review: sonnet

## Branch naming

- pattern: `manager/optetron-website-issue-{N}`  # dashes only, no dots ({N} substituted per issue)

## Deploy guardrails

- prod_deploy_cmd: `scripts/deploy-to-production.sh`
- forbid_autonomous_deploy: true                 # manager NEVER runs prod_deploy_cmd

## Submodule constraints (omit the section if there are none)

- frozen_submodules:
  - themes/neon-tokyo

## Project-specific skills (optional — referenced from worker launch prompt)

- contributing-to-optetron-website                # e.g. project-style guide skill

## Reachability

- user_reachable: false                          # default for autonomous campaign
- escalation_channel: send_notification          # one of: send_notification / off
```

## Bootstrap flow

When the manager's pre-flight finds `docs/superpowers/megatask.config.md` missing, the flow is:

1. Read this schema doc.
2. Ask the user one section at a time. **Never assume defaults silently** — present each default and get explicit confirmation. The default for `models.subagent_*` is `sonnet`; the default for `models.manager` and `models.worker` is `opus`. Other defaults are project-specific and have no safe assumption.
3. Detect stack heuristically before asking — read `package.json` / `pyproject.toml` / `go.mod` / `Cargo.toml` etc. and pre-fill `stack.lint` / `stack.test` / `stack.build` candidates. The user confirms or overrides.
4. Render the answers into the annotated-example shape above.
5. Write `docs/superpowers/megatask.config.md`.
6. Commit: `chore(megatask): add config`.

## Changing model defaults later

To change models for a single campaign run, edit `docs/superpowers/megatask.config.md` before launching `/megatask`. The manager re-reads the config at every campaign start. Mid-campaign overrides are forbidden (Hard rule #17 in `SKILL.md`) — restart the campaign with the new config if model needs to change.

## Notes

- All paths in the config are repo-relative.
- All commands are run from repo root.
- The config file itself is committed; do NOT gitignore.
- If a project has a non-trivial setup (e.g. multiple package managers in a monorepo), use `description:` blocks to spell out the exact invocation. The manager substitutes them verbatim into the worker launch template.
