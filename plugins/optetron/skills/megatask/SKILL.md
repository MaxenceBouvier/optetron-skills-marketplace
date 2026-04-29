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
