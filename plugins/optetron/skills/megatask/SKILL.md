---
name: megatask
description: Use when starting a long-running autonomous manager session that orchestrates multiple sequential worker sessions to resolve a queue of issues / tasks under full autonomy, with anti-rubber-stamp and anti-laziness discipline, phase-aware wake cadence, and per-issue ff-merge.
---

# Megatask — Autonomous Campaign Orchestrator

## Overview

Megatask is a campaign-shaped recipe layered on top of `optetron:manager`. It runs one manager session that orchestrates many *sequential* worker sessions to resolve a queue of issues / tasks under full autonomy, with the anti-rubber-stamp + anti-laziness discipline turned all the way up. Each issue gets its own worktree, its own worker session, a phase-aware wake cadence tuned to the worker's current sub-phase, an automated acceptance smoke run by the manager, an ff-merge into `main`, and an issue close — strictly in that order.

**Megatask is NOT a replacement for `manager`.** Manager remains the autonomous-loop primitive (wake discipline, escalation matrix, anti-rubber-stamp, MCP quick-ref). Megatask is the campaign layer on top.

## When to use

- A queue of related issues / tasks needs to be resolved sequentially under full autonomy.
- The user is unreachable for the duration (or reachable only via `send_notification`).
- Each task in the queue is small enough to be one worker, one branch, one ff-merge, one issue close.
- Quality bar is high — patchy / quick-and-dirty work is unacceptable; the manager must read every option a worker presents and pick the cleanest, not the recommended/fastest.

**Don't use for:** single-issue work (just dispatch a normal worker via `optetron:manager`), parallel issue execution (megatask is strictly sequential — parallel mode is a future extension), or anything that requires the user to "open the page and look" mid-campaign.

## REQUIRED BACKGROUND

You MUST understand `optetron:manager` before using this skill. That skill defines:
- Autonomous wake-loop shape and wake-interval discipline (5-min cache TTL, never 300s).
- Escalation matrix (what auto-decides, what escalates, what notifies).
- Anti-rubber-stamp behavioral rules (read all approaches, demand evidence, section-by-section spec review).
- MCP tools quick-ref (`list_sessions`, `capture_session_output`, `send_action`, etc.).

Megatask layers on top of those primitives — it does not redefine them.

## Pre-flight checklist (run once at session start)

1. **Clean tree, in sync with main.** `git status` clean. `git fetch && git status` up-to-date with `origin/main`. If not clean, fix or escalate before dispatching workers.
2. **Read project config.** Read `docs/superpowers/megatask.config.md`. If absent, run the **Config bootstrap** flow below (next section), write the file, commit. If present, validate every required key is set.
3. **Baseline green.** Run `<install> && <lint> && <test> && <build>` per `config.stack`. Abort the campaign if red — fix or escalate first; never start a campaign on a red baseline.
4. **Dev server (if `config.dev_server.enabled`).** Boot the dev server in a tmux pane the manager owns. Confirm `config.dev_server.url` serves a 200.
5. **Manager report.** Initialize `megatask-report.md` at repo root from `report-template.md` if absent. Commit (`chore(megatask): initialize campaign report`).
6. **Per-issue pre-flight.** For each issue in the queue, check whether it is already done against current `main` (read acceptance bullets, run a quick spot-check). If done → close the issue with a citing comment, skip its phase. If not → keep in queue at its slot. Do not redo finished work.
7. **Schedule first wake** (270s default). Begin issue-1 phase on next wake.

## Config bootstrap

If `docs/superpowers/megatask.config.md` is missing, walk the user through inline setup before launching any worker:

1. Read `config-schema.md` (sibling file in this skill) for the schema + annotated example.
2. Ask the user one section at a time — stack & verification commands, dev server (if any), issue source, acceptance verification method, models, branch naming, deploy guardrails, submodule constraints, reachability. **Never assume defaults silently** — present them, but get explicit confirmation.
3. Write the answers to `docs/superpowers/megatask.config.md`.
4. Commit: `chore(megatask): add config`.
5. Proceed to baseline-green step of pre-flight.

Required keys (skill must refuse to start the campaign if missing):
- `stack.lint`, `stack.test`, `stack.build`
- `issue_source.type` (one of `gh` / `explicit` / `linear`)
- `acceptance_verification.method`
- `models.manager`, `models.worker`, `models.subagent_implementation`, `models.subagent_spec_review`, `models.subagent_code_quality_review`
- `branch_naming.pattern`
- `deploy_guardrails.forbid_autonomous_deploy`
- `reachability.user_reachable`

## Phase-aware wake cadence

Inherits from `optetron:manager` (5-min prompt-cache TTL, never 300s). Megatask overrides for brainstorm sub-phases.

| Worker sub-phase | Wake cadence | Detection signal (parse last meaningful line of `capture_session_output`) |
|---|---|---|
| Context gathering (worker reading codebase / docs / `CLAUDE.md`) | **120s** | Worker just launched; no questions yet; capture-output shows file reads |
| Brainstorm — interview phase | **60s** | Last worker message ends with `?` or "which approach…" |
| Brainstorm — design presentation | **60s** | Worker presents 2-3 options + recommends, awaits manager pick |
| Spec writing | **120s** | Worker says "drafting / writing spec / writing the design doc" |
| Spec review (manager-side) | **on-demand** | Manager-side blocker, no sleep — review now, F-flag inline |
| Plan writing (via `superpowers:writing-plans`) | **120s** | Worker invokes writing-plans, drafting tasks |
| Plan review (manager-side) | **on-demand** | Manager-side blocker |
| Subagent execution (worker dispatched its own subagent) | **270–600s** | Worker says "dispatching subagent" / capture shows sub-agent activity |
| Awaiting permission decision | **60s + push notification** | Permission prompt detected |
| Manager visual / acceptance smoke (chrome-devtools / cli running) | **60s** | Active manager-side work |
| Idle / long build / no signal | **1800s** | Nothing changed in last tick, no active phase |

**Switch the moment sub-phase transitions** — don't wait the full tick. Each wake = `capture_session_output` tail + parse last meaningful message + reschedule with new cadence.

**Anti-pattern (from `manager`):** never set 90–120s during subagent execution. Subagent runs span minutes; short ticks = self-inflicted false alarm + corruption risk. If you catch yourself thinking "let me just check on progress" mid-subagent-execution, extend the wake instead.

## Worker dispatch protocol (per-issue loop, runs until queue empty)

1. `create_worktree(branch=<config.branch_naming.pattern with {N} substituted>, from_ref="main")`.
2. `launch_session(worktree_id, prompt=<filled worker template>, model=config.models.worker, permission_mode="auto", monitor_level="permissions_only", name="<issue-{N}>")`. Branch and session names: dashes only, never dots.
3. Inject the filled worker launch prompt via `send_message` followed by tmux Enter (see `manager` skill for the exact pattern). Verify via `capture_session_output` — `[Pasted text …]` means not submitted.
4. **Wake-loop with phase-aware cadence** (table above). Each wake:
   - `list_sessions(include_monitors=True)` → rebuild status table from MCP state (canonical).
   - `capture_session_output(sid)` → parse last meaningful message, detect sub-phase, set next cadence.
   - Decide one of: answer / approve / merge / escalate / nothing. Apply the `manager` escalation matrix.
   - Append a wake-N entry to `megatask-report.md` (even short polling wakes — one-line tick entry).
   - `ScheduleWakeup(delaySeconds=N, prompt="<<autonomous-loop-dynamic>>", reason="<one specific sentence>")`.
5. **Manager checkpoints** (worker pings; each gets section-by-section F-flag review):
   - Brainstorm doc landed.
   - Spec draft landed.
   - Plan draft landed.
   - Implementation green (`<lint> && <test> && <build>` all pass on the worker's worktree).
   - Worker says "ready to merge".
6. **Manager-side automated acceptance smoke** when the worker says "ready to merge". Run per `config.acceptance_verification.method`, save artifacts to `config.acceptance_verification.artifact_dir/issue-{N}/`, write a `report.md` mapping each acceptance bullet → pass/fail. **If any bullet fails → reject, send F-flags to worker, do NOT merge.**

**Strict ordering for closure of an issue (steps 7–11 are sequential, not optional):**

7. **ff-merge.** `git merge --ff-only <worker-branch>` from the manager's `main` worktree. If non-ff (the manager's wake-log commits drifted main), rebase the worker branch onto main first. If conflict → escalate.
8. **Push.** `git push origin main`.
9. **Close the issue.** As soon as the merge is pushed, the manager MUST close the corresponding issue: `gh issue close {N} --comment "Fixed in <merge-sha>. Acceptance verified: <checklist>."` (or the equivalent close call for non-GH issue sources). No orphaned issues — an unmerged issue is acceptable, a merged-but-still-open issue is a bug.
10. `stop_session(sid)`. Worktree cleanup deferred to closure sweep.
11. Append phase-complete entry to `megatask-report.md` (merge sha, close-comment link, screenshot/test artifacts paths) and move to next issue.

## Anti-laziness in option-picking (manager-side discipline)

When the worker presents 2–3 options for a design choice, **read every option in full**. The worker's recommended option is frequently the laziest / fastest-to-ship — that bias is structural, not a worker failure. Your job is to pick the option with the highest long-term code-quality and UX coherence, even if it requires more worker effort.

Concretely:
- Read approach #1, #2, #3 carefully, in full. Do not skim non-recommended options.
- Invert worker framing. "A is fastest, B is cleaner" → default to B unless A has concrete evidenced reason. "C is over-engineered" from the worker often translates to "C is correct, I don't want to write it."
- Demand primary-source evidence for the worker's recommendation: file/line citation, failing test, screenshot. "Standard practice" / "this is how X library does it" / "I think" is not evidence.
- Section-by-section spec review with F-flag identifiers (`F1`, `F2`, …). Do NOT collapse — workers bury issues in collapsed sections.

**Worker-side coding discipline** — no hardcoded magic values, no `as any` / `// @ts-expect-error` / `// eslint-disable-*`, no `!important`, no copy-paste when reuse is feasible, no `TODO clean up later` / `FIXME` in committed code, accessibility (`prefers-reduced-motion`) honored — **is enforced by `superpowers:subagent-driven-development`**, not by megatask. Megatask layers on top; it does not duplicate.

## Auto-mode brainstorming override

Workers running in auto mode (Claude Code opus + auto-approve permissions + monitor sidecar) tend to barrel through the brainstorming question session and design-proposal step, defaulting to "auto means proceed". This is a campaign-killer — without the question session and the manager's option-pick, every worker ships its own laziest recommendation.

The worker launch prompt (`worker-launch-template.md`) contains a **CRITICAL** block instructing the worker that auto-mode does NOT skip the brainstorming question session or the design proposal — it only auto-executes already-decided steps. The manager rejects worker output that skipped them.

When dispatching a worker, **never edit out** the auto-mode override block from the launch template. If a worker still skips the question session, the correct action is to reset the worker's worktree and re-dispatch with a sharper directive — not to accept the skipped work and "review the spec extra carefully".

## Manager report file

`megatask-report.md` lives at the project repo root. Initialized from `report-template.md` (sibling of this SKILL.md) at pre-flight. Updated on **every** wake — even short polling wakes get a one-line tick entry (`tick: still on issue-2 spec-writing, no change`). The trail must be dense and resumable: a fresh post-compaction agent must be able to resume the campaign from this file alone.

Mandatory sections:
1. **Post-compaction continuity entry point** (read first by any fresh resuming agent).
2. **Mandate.**
3. **Decisions locked at kickoff** (immutable for the duration of the campaign).
4. **Phase status table.**
5. **Wake log** (append-only).
6. **Current state at last checkpoint** (rebuild every wake).
7. **Per-phase launch prompt** (verbatim, copy-paste-ready).

See `report-template.md` for the verbatim scaffold.

## Closure sweep (after queue empty)

1. Final green: `<lint> && <test> && <build>` on `main`.
2. **Full automated acceptance regression** if applicable to the project type. For web: `chrome-devtools` MCP walks every route, screenshots at multiple viewports, console-clean check on each, saves to `<artifact_dir>/final/`. For CLI / library / API: full integration suite + smoke run. Manager reads each artifact itself — no human in the loop.
3. **Worktree cleanup.** Call `cleanup_merged_worktrees` via the agent-dashboard MCP server (with confirmation token).
4. Append `ALL N ISSUES SHIPPED` entry to `megatask-report.md` — merge-SHA list, summary of what changed.
5. **Notify user.** `send_notification(urgency="low", body=<deploy-ready note + report path>)`.
6. **Do NOT auto-deploy.** Production deploy is user-only.
7. `stop_session` (manager).

## Hard rules

Manager-side standing orders for the duration of the campaign. Numbered for reference in wake-log entries.

1. **Never autonomous prod deploy.** `config.deploy_guardrails.prod_deploy_cmd` is user-only. Phase ends at green-on-`main` + deploy-ready note in report; user runs the deploy.
2. **Never bump frozen submodules** unless the issue explicitly requires it; surface the reason in the spec for manager approval if forced.
3. **Targeted tests during iteration** (`<config.stack.targeted_test>`); full suite only at green gate.
4. **Conventional Commits** + lint clean + strict typing on every commit. Pre-commit hooks must pass — never `--no-verify`.
5. **Dashes in branch names, never dots** (tmux parses `session.window`). Verify before `create_worktree`.
6. **ff-merge per phase**: rebase worker onto current `main` if drifted → ff-merge → push. Non-ff / conflict / destructive → escalate per `manager` matrix.
7. **Anti-rubber-stamp** (inherited from `manager`): read ALL options worker presents; section-by-section F-flag review; worker pushback only with primary-source evidence.
8. **Anti-laziness in option-picking (manager-side):** when the worker presents 2–3 options, do NOT default to the recommended one. Read every option in full. Pick the highest long-term code-quality and UX coherence option, even if it requires more worker effort. Worker-side coding discipline is enforced by `superpowers:subagent-driven-development` — not duplicated here.
9. **Phase-aware wake cadence**: switch the moment sub-phase transitions, don't wait the full tick. Never 300s. Never set 90–120s during subagent execution.
10. **No human-in-the-loop checks if `config.reachability.user_reachable=false`.** Anything requiring "ask the user to look" replaced with automated assertion (chrome-devtools MCP / integration test / curl). If `user_reachable=true`, manager may notify and pause.
11. **Manager↔worker exchanges file-based or text-based only.** Image files (PNG / SVG / screenshots / committed mermaid renders) are fine — manager reads them. ASCII / markdown text diagrams are fine. Visual companion server (live browser-driven mockups via `superpowers:brainstorming` companion mode) is forbidden — manager cannot interact with it; workers must decline the companion when offered.
12. **Frontend-design skill mandatory** for any visual/UI work (web projects only — gated by `config.acceptance_verification.method`).
13. **Escalation on doubt**: user unreachable → call `advisor()` with ultrathink and continue. User reachable → escalate per `manager` matrix.
14. **Issue closure required**: every merged phase ends with issue-source close (`gh issue close` / Linear API / etc.) + citing comment. No orphaned issues — a merged-but-still-open issue is a bug.
15. **Standing-rule supremacy** (from `manager`): pre-authorized escalation triggers fire even in autonomous mode — they're standing orders, not interruptions.
16. **Auto-mode does NOT skip brainstorming interview / design steps.** Worker launch prompt explicitly overrides this; manager rejects worker output that skipped them.
17. **Model overrides via `megatask.config.md` only.** Worker launch template substitutes from config. Manager does not improvise model choices mid-campaign.

## Support files (in this skill directory)

- `worker-launch-template.md` — verbatim worker launch prompt with `{{PLACEHOLDERS}}`. Manager copies it, substitutes placeholders from `config`, sends as the worker's first message after `launch_session`.
- `report-template.md` — manager report file scaffold. Copied once at pre-flight to `<repo-root>/megatask-report.md`.
- `config-schema.md` — schema + annotated example for `docs/superpowers/megatask.config.md`. Read at config-bootstrap time when a project does not yet have a config file.
