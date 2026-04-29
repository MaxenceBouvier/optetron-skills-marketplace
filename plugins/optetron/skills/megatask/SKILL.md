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
