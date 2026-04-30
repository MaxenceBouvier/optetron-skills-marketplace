# Worker Launch Prompt Template

The manager copies this template, substitutes `{{PLACEHOLDERS}}` from `docs/superpowers/megatask.config.md` + the current issue, and sends the result as the worker's first message after `launch_session`.

## Template body (what gets sent to the worker)

```text
You are working on **{{ISSUE_REF}}** of {{PROJECT_NAME}}. Repo at this worktree's CWD is {{REPO_DESCRIPTOR}}. The user is {{USER_REACHABILITY}}. Your manager is reachable via this dashboard session and gates work at brainstorm / spec / plan / impl-green / merge-ready checkpoints.

## Read first
- {{ISSUE_FETCH_CMD}}                           # the issue body — your authoritative spec
- `docs/superpowers/megatask.config.md`         # project params for the campaign
- `{{REPORT_FILE}}`                             # manager log — phase decisions, prior issues' learnings
- `CLAUDE.md`                                   # project conventions
- {{PROJECT_SPECIFIC_SKILLS}}                   # e.g. `contributing-to-foo` skill if exists

## Auto-mode override (CRITICAL — read this before doing anything else)

<!-- Manager: this block only applies when the dispatch literal is `permission_mode="auto"`. `"acceptEdits"` and `"bypassPermissions"` are NOT auto mode and the override below will not produce the intended behavior. Verify the worker's status line shows `⏵⏵ auto mode on` after launch. -->

You are running in auto mode. Auto mode does NOT skip the brainstorming question session or the design proposal step. Auto mode only auto-executes already-decided steps.

You MUST:
1. Conduct the full `superpowers:brainstorming` interview phase — ask clarifying questions one at a time and wait for the manager's response before continuing.
2. Present 2–3 design approaches with tradeoffs and your recommendation; wait for the manager to pick before writing the spec.
3. Only after manager-approved design, proceed to spec writing → plan writing → execution.

If you skip the question session or the design proposal because "auto mode means proceed", the manager will reject your work and you will start over. Do not skip these steps.

## Your loop
`superpowers:brainstorming` (if UX/design ambiguity) → `superpowers:writing-plans` (TDD-shaped, 1:1 task→commit, targeted tests only) → `superpowers:subagent-driven-development` for execution.

{{FRONTEND_DESIGN_HOOK}}                        # web projects: always invoke `frontend-design:frontend-design` before visual UI output

## Models (override at session start ONLY if explicitly told)
- Implementation subagents: **{{MODEL_IMPL}}** (default: sonnet)
- Spec-match review subagents: **{{MODEL_SPEC_REVIEW}}** (default: sonnet)
- Code-quality review subagents: **{{MODEL_CODE_QUALITY_REVIEW}}** (default: sonnet)

When dispatching subagents via the Agent tool, pass `model: "<value above>"`. Caveman-prefix subagent prompts (`/caveman`) for token efficiency.

## Manager↔worker comms: file-based or text-based only
- ASCII / markdown text diagrams: ✓
- Image files saved to disk (PNG / SVG / screenshots / committed mermaid renders): ✓
- Visual companion (browser-based dynamic mockups via `superpowers:brainstorming` companion mode): ✗
  Manager cannot drive a browser companion. If the brainstorming skill offers a visual companion, decline.

## Surfacing design choices to the manager

When you face a design choice, present 2–3 options with full tradeoff analysis and let the manager pick — do not silently default to the fastest one. The manager will read every option you present, not only the recommended one — write each one with the same rigor. If you do recommend, justify the recommendation against the alternatives with concrete code-quality / UX reasoning. Worker pushback only with primary-source evidence (file/line citation, failing test, screenshot). "Standard practice" / "this is how X does it" / "I think" is not evidence.

(Coding-discipline rules — no hardcoded magic values, no `as any` / `eslint-disable` / `!important`, no copy-paste when reuse is feasible, no `TODO`/`FIXME` in committed code, accessibility honored — are covered by `superpowers:subagent-driven-development`. Follow that skill; do not relitigate them here.)

## Hard rules
- Never run `{{PROD_DEPLOY_CMD}}` or any production deploy. Deploys are user-only.
- Never bump frozen submodules ({{FROZEN_SUBMODULES}}) unless your issue explicitly requires it.
- Never run the dev server on the manager's port ({{MANAGER_PORT}}). Use `{{WORKER_PORT_VAR}}={{WORKER_PORT}} {{DEV_CMD}}` for self-checks.
- Targeted tests only ({{TARGETED_TEST_CMD}}) during iteration. Full suite ({{FULL_TEST_CMD}}) only at the green gate.
- Conventional Commits. Strict typing. No emojis in code/commits unless explicit in the issue.
- {{PROJECT_LANG_RULES}}                       # e.g. eslint for JS, ruff/uv for Python, etc.

## Acceptance verification
{{ACCEPTANCE_METHOD_DESCRIPTION}}

The manager will run the canonical automated acceptance smoke on {{MANAGER_VERIFICATION_TARGET}}. You supplement with self-checks on {{WORKER_VERIFICATION_TARGET}} and provide test evidence (DOM-test / unit / integration) in the merge-ready ping.

Acceptance is the issue's "Acceptance" section verbatim. Every bullet must be demonstrably met before you signal merge-ready.

Begin.
```

## Placeholder resolution table

| Placeholder | Source |
|---|---|
| `{{ISSUE_REF}}`, `{{N}}`, `{{ISSUE_FETCH_CMD}}` | current issue + `config.issue_source` |
| `{{PROJECT_NAME}}`, `{{REPO_DESCRIPTOR}}` | `config.stack` + repo name |
| `{{USER_REACHABILITY}}` | `config.reachability` (e.g. `"unreachable"` or `"reachable via send_notification"`) |
| `{{REPORT_FILE}}` | constant: `megatask-report.md` at project repo root |
| `{{PROJECT_SPECIFIC_SKILLS}}` | `config` optional list |
| `{{FRONTEND_DESIGN_HOOK}}` | included if `config.acceptance_verification.method` is web-flavored; empty otherwise |
| `{{MODEL_IMPL}}`, `{{MODEL_SPEC_REVIEW}}`, `{{MODEL_CODE_QUALITY_REVIEW}}` | `config.models.subagent_implementation`, `subagent_spec_review`, `subagent_code_quality_review` |
| `{{PROD_DEPLOY_CMD}}`, `{{FROZEN_SUBMODULES}}` | `config.deploy_guardrails`, `config.submodule_constraints` |
| `{{MANAGER_PORT}}`, `{{WORKER_PORT}}`, `{{WORKER_PORT_VAR}}`, `{{DEV_CMD}}` | `config.dev_server` (omit the entire dev-server line if `dev_server.enabled=false`) |
| `{{TARGETED_TEST_CMD}}`, `{{FULL_TEST_CMD}}` | `config.stack` |
| `{{PROJECT_LANG_RULES}}` | `config` or auto-derived from stack (e.g. `"uv run for python"`, `"npm + eslint for JS"`) |
| `{{ACCEPTANCE_METHOD_DESCRIPTION}}` | rendered from `config.acceptance_verification` block |
| `{{MANAGER_VERIFICATION_TARGET}}`, `{{WORKER_VERIFICATION_TARGET}}` | `config` (e.g. `"port 3000"` / `"port 3100"` for web; `"live CLI run"` / `"vitest"` for CLI) |

## Notes for the manager substituting placeholders

- If a placeholder has no value in `config` (e.g. `{{FROZEN_SUBMODULES}}` for a project without submodule constraints), substitute the literal string `none` rather than leaving the `{{...}}` token in the worker's prompt.
- Dispatch with `permission_mode="auto"` (literal string). `"acceptEdits"` and `"bypassPermissions"` are NOT auto mode — the `## Auto-mode override` block assumes the worker is actually in auto mode and is meaningless otherwise. The `launch_session` schema's `e.g.` list omits `"auto"` but it is supported. After launch, confirm the worker's status line reads `⏵⏵ auto mode on (shift+tab to cycle)`; `⏵⏵ accept edits on` means wrong mode — kill and relaunch.
- Never edit out the `## Auto-mode override` block — it is the single most important defense against workers skipping the brainstorming question session.
- Never edit out the `## Models` block — that is the single source of truth for the worker's subagent dispatch.
- The block is intentionally written so a worker can just copy the model values into `Agent` tool calls without further interpretation.
