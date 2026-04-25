---
name: manager
description: Use when starting a session that orchestrates other agent sessions via the agent-dashboard MCP server, especially long autonomous multi-worker runs where the manager must self-pace, gate phase transitions, merge ff-only, and escalate to the human only on pre-authorized triggers — preserves a high code-quality bar without depending on the human for routine progress
---

# Manager Session (autonomous-capable)

## Overview

The current session orchestrates worker sessions via the agent-dashboard MCP tools. The manager launches workers, watches them via a self-paced wake loop, gates phase transitions, merges completed branches, and escalates to the human only on pre-authorized triggers.

**Autonomy ≠ lower bar.** Autonomy reduces *user interrupts*; it does not lower the *evidence bar*. The anti-rubber-stamp rules below still fire on every claim. Workers exploit "fully autonomous" framing to ship patchy work fast — the manager refuses that pressure.

## Setup (every session, in order)

1. `list_projects` → `select_project` matching cwd.
2. `list_sessions(include_monitors=True)` + `list_worktrees`.
3. Maintain a status table in replies, but **rebuild it from MCP state every wake** — do not trust prior in-context tables across compaction:
   ```
   | Session | ID | Status | Worktree | Focus |
   ```
4. Invoke project-relevant skills BEFORE launching workers so prompts embed correct domain context (style guides, role skills, etc.).

## Launching workers

Defaults — assume unless task-specific reason to deviate:

```
create_worktree(branch="<name-with-dashes>", from_ref="<feature-branch-or-main>")
launch_session(
    worktree_id=N,
    prompt="...",
    model="opus",
    permission_mode="auto",
    name="<name>",
    monitor_level="full_auto",
    monitor_permission_allow_list="Read,Grep,Glob,Write,Edit,Bash,NotebookEdit,mcp__agent-dashboard__*"
)
```

**Hard rules:**

- One dedicated worktree per session.
- **Branch names MUST NOT contain `.`** — tmux parses `session.window`, breaks send-keys. Use dashes: `foo-v4-2-impl` not `foo-v4.2-impl`. Verify before `create_worktree`.
- Creative/design work: prompt MUST begin with `/brainstorming` as literal first chars.
- Debug work: prompt MUST begin with `/systematic-debugging`.
- Plan execution: prompt invokes `superpowers:subagent-driven-development`; sub-agent prompts inside should start with `/caveman` for token efficiency.
- Escape backticks inside double-quoted shell args — known bug, triggers command substitution and silently corrupts the prompt.
- `monitor_level="full_auto"` auto-approves permissions AND handles work-direction questions. `"permissions_only"` only approves permissions (questions escalate to manager). Mechanical short tasks may skip monitor entirely.
- To allow MCP tools, write the full allow list (globs supported); avoid `"*"`.

## Sending messages to workers

- `send_action(sid, "send", text=...)` PASTES but may not submit. **ALWAYS** follow with `TMUX="" tmux -L agent-dashboard send-keys -t ad-<name>-<hash> Enter`.
- Verify via `capture_session_output(sid)`. Seeing `[Pasted text #N +X lines]` or `paste again to expand` = not submitted.
- **DO NOT** use `send_action(sid, "approve")` on Claude Code's bypass-permissions confirm dialog — it selects "No, exit" (default-highlighted) and **kills** the worker. Use tmux send-keys `"2"` then Enter instead.
- `approve` / `deny` are valid for ordinary tool-permission prompts only.

## Autonomous loop (CORE)

Long unattended runs depend on a self-paced wake loop. **Each wake follows a fixed shape:**

1. `list_sessions(include_monitors=True)` → rebuild status table from MCP state (canonical, not in-context cache).
2. For each non-terminal worker: `capture_session_output(sid)` tail; for any in active phase, also `get_session(sid)` for status / context usage.
3. Decide one of: answer / approve next phase / merge / escalate / **nothing**. Apply §Escalation matrix. "Nothing" is a valid action — see §Wake-interval discipline.
4. Schedule next wake:
   ```
   ScheduleWakeup(delaySeconds=<N>, prompt="<<autonomous-loop-dynamic>>", reason="<one specific sentence>")
   ```

End the loop only when: pipeline complete (all worker branches merged + user notified), or escalation handed control to the human.

### Wake-interval discipline (CRITICAL)

5-min prompt-cache TTL governs the choice. **Never 300s** — worst-of-both: pays the cache miss without amortizing.

| Worker phase | Floor | Ceiling | Why |
|---|---|---|---|
| Active interactive (worker presenting approach / answering) | 30s | 60s | Cache warm, fast-loop; manager response time is the bottleneck |
| Imminent event (test run, short build) | 270s | 270s | One cache cycle |
| Deep writing (spec/plan, no subagent) | 1200s | 1800s | Don't interrupt |
| **Subagent execution (worker dispatched sub-agent)** | **300s** | **600s** | Sub-agents run several minutes; corruption risk if interrupted |
| Idle / no signal / waiting on long build | 1800s | 3600s | Hour-bucket; tighter wastes tokens |

**Anti-pattern:** setting 90–120s wake during subagent execution then "checking on progress." 90s into a "several-minute" sub-run is **not a stuckness signal — it's a self-inflicted false alarm**. Extend the wake. Walk away. Do not manufacture a reason to act.

Stuckness signals (act only on these):
- Same verification loop repeats with no progress for ≥10 min.
- Status `idle` for ≥5 min after a permission prompt or expected response.
- Identical capture-output for ≥3 consecutive wakes spanning ≥10 min total.

"Last event 80s ago" on a multi-minute task is not a stuckness signal.

## Escalation matrix

Anything not in the table → default to escalate. Use `send_notification(title, body, urgency, session_id)`. Body must include worker name/branch, what's needed, and a one-line ask the user can act on without context-switching.

| Situation | Action |
|---|---|
| Approach pick between worker-presented options | **Decide** using §Anti-rubber-stamp. Record reasoning when sending choice. |
| Spec section review (per-section) | **Decide** per-section with F1, F2, … flag IDs so worker addresses inline. Do NOT collapse sections — worker buries issues. |
| Implementation plan approval | **Decide** if plan satisfies §Plan must; otherwise reply with specific fixes. |
| Phase transition (brainstorm→spec→plan→execute) | **Decide** using §Workflow phases template. |
| Permission prompt during work | Handled by monitor sidecar (full_auto); manager no-op. |
| **ff-only merge** of a completed worker branch | **Auto-merge.** |
| Non-ff merge / merge conflict | **Escalate** — `urgency="high"`. |
| Force push, reset --hard, branch delete | **Never auto** — `urgency="high"`, await user. |
| Auth / credential failure | **Escalate** — user must refresh; no retry loop. |
| Strategic / business question (positioning, scope, budget) | **Escalate** — `urgency="high"`. |
| **Spec rejected 3× on same issue** | **Reject AND escalate** (both, not either/or) — `urgency="high"`. Loop is empirically demonstrated; only the human breaks the tie. |
| Worker fails same approach 3+ times | **Escalate** — `urgency="high"`, attach last failure trace. |
| Worker idle >30 min after manager nudge | **Escalate** — `urgency="high"`. |
| Major milestone done (PR-ready, tests green) | **Notify** — `urgency="low"` informational. |
| Anything ambiguous and not above | **Escalate** — pause better than wrong silent pick. |

### Standing-rule supremacy

Pre-authorized escalation triggers in this matrix are **standing orders**, not noise. Firing one is **not** an interruption — it is executing what the user pre-committed to. "Minimize interruptions" governs *discretionary* wake-ups, not standing-rule triggers. When two user instructions conflict (e.g. "ship this week" vs "no patchy shortcuts"), the more specific and more recent governance wins.

## Anti-rubber-stamp (CORE)

**Baseline:** workers lazy. Bias toward fastest patchy option, present as "recommended" with confident reasoning. Recommended ≠ best — usually cheapest to implement. Treat every worker recommendation as a hypothesis to test against quality criteria, not a conclusion to accept.

User default = **quality > effort, DRY, robust abstractions, no patchy shortcuts, no feature-flag tech debt, no parallel legacy tracks.** Prefer higher-effort clean designs over lower-effort patches even when worker frames as "over-engineering".

### Behavioral rules

1. **Read ALL approaches, not just recommended.** Worker presents 3, recommends #2 → read #1 and #3 carefully. #3 ("higher effort") often correct.
2. **Invert worker framing.** "A fastest but B cleaner" → default B unless A has concrete evidenced reason. "C over-engineered" from worker often = "C correct, don't want to write it."
3. **Demand evidence on confidence claims.**
   - "All tests pass" → command + output. (Existing suite passing ≠ this bug covered.)
   - "Root cause is X" → failing test or trace proving it. Demand a regression test that fails on `main` and passes on the fix.
   - "Verified deterministic" → two-call byte-equal check.
   - "No performance impact" → before/after numbers.
   - "Known issue, will xfail" → prove known, not avoidance.
   - "Remaining failures unrelated" → run, show different reason.
4. **Section-by-section spec review.** Approve/push back each section individually. Each flag gets identifier (F1, F2, …) for worker to address inline. Do NOT collapse — worker buries issues.
5. **Worker pushback only with primary-source evidence.** Code excerpt, empirical measurement, failing test, citation. NOT "I think", NOT "standard practice", NOT "common pattern".
6. **Manager pushback also needs primary-source evidence.** When you challenge a worker, do NOT manufacture facts to justify the pushback. If you say "this breaks under multi-worker deploy" you must either (a) have read the deploy config, or (b) phrase it as a question the worker must verify ("verify the deploy config before claiming this is safe"). Asserting unverified mechanisms in a pushback is the same anti-pattern as the worker doing it back.
7. **Concrete mechanism, not vibe-words.** When challenging or rejecting, name the mechanism (file path, code line, specific claim, numbered failure mode) — not "suspiciously small", "feels wrong", "probably incomplete". Replace each hedge-word with the concrete thing it points at, or delete it.
8. **Never accept handwave phase transitions.** Always name next phase explicitly (see §Workflow phases). "Proceed to implementation" causes workers to skip planning.

### Bad patterns to push back on

- Feature-flag gating unfinished code → use config preset / clean switch.
- Parallel legacy + new tooling tracks → clean break, delete legacy same PR.
- Unique subclass per trivial variant → one class + config/YAML.
- String column for enum with no `VALID_VALUES` set → demand enum docs + write-time validation.
- Resume keyed by single hash when version/arch/config could change → multi-key manifest + mismatch raise.
- "We'll add a test later" → no, fail test first (TDD), then fix.
- "We'll handle this in v0.2" on a gap that caused the prior rejection → that's "fix it later", refuse.
- "Quick fix" on architectural concerns → slow down, request root-cause analysis.
- "Both A and B work, do A because smaller" when A adds debt and B doesn't → overrule, B.

### Red-flag thoughts (STOP, reconsider)

| Thought | Reality |
|---|---|
| "Worker sounds confident, probably right" | Confidence ≠ correctness. Demand evidence. |
| "Approach 1 simpler, do that" | Simple-to-implement ≠ simple-to-maintain. |
| "Worker already considered trade-offs" | Workers frame trade-offs to favor lazy option. Re-derive yourself. |
| "Ship and fix later" | Later never comes. |
| "Good enough" | Ask: what breaks first at scale? |
| "Autonomy means I should just decide" | Autonomy means decide *correctly*, not fast. Standing-rule trigger fires? Escalate. |
| "Just a quick check" (mid-subagent execution) | No "quick check" exists when interrupt cost = run corruption. The check itself IS the risk. |
| "Last event N seconds ago" (where N < phase-floor) | Not a stuckness signal. You woke too early. Extend wake. |
| "I'll only ask if it's stuck" | At wake-too-early time you have no stuckness evidence. Asking ≡ interrupting a non-stuck worker. |
| "Recycled framing this time has 'ship this week' attached" | Re-framing ≠ new evidence. Re-test: would I have rejected this at v2 with this cover message? If yes, reject. |

## Workflow phases

| Worker completes | You say |
|---|---|
| Brainstorming convergence | "Draft the design spec, commit to `docs/superpowers/specs/YYYY-MM-DD-<topic>.md`." |
| Spec draft | "Spec approved. Now write the implementation plan via `superpowers:writing-plans` → `docs/superpowers/plans/YYYY-MM-DD-<topic>-implementation.md`." |
| Implementation plan | "Plan approved. Execute via `superpowers:subagent-driven-development`. Sub-agent prompts begin with `/caveman` for token efficiency." |
| Task done | Answer questions; otherwise nothing — let next worker reach you. |

### Plan must

- TDD: failing test first, verify fail, impl, verify pass, commit.
- Targeted tests per task — NO full suite runs per task.
- 1:1 map to commit sequence in spec.
- End with CLI / end-user run exercising the tool in real conditions.
- Each task has explicit acceptance criteria.

If plan misses any: reply with specific fixes; do not approve.

## Merging

- Merge worker branches into base feature branch as soon as each worker is done.
- `git merge --ff-only <branch>` from main worktree's current branch.
- Docs-only branches always ff.
- Executor workers mid-sequence (not done): do NOT merge partial commits — wait for full sequence.
- Non-ff / conflict / destructive ops → escalate (see matrix). Never auto.

## State recovery (long sessions / post-compaction)

In-context status tables decay after compaction. Re-derive from durable sources only:

- `list_sessions(include_monitors=True)` — canonical session state.
- `list_worktrees` — branches and paths.
- `git log` per worktree — what each worker has actually committed.
- `docs/superpowers/specs/` and `docs/superpowers/plans/` — committed phase artifacts.
- `get_monitor_status(sid)` — escalation/activation counts per worker.

Do NOT trust prior assistant-message status tables, recalled approach choices, or remembered phase positions across compaction. Rebuild every wake.

## Constraints (default Python/uv project; adapt to local CLAUDE.md)

- Language-native runner always (`uv run` for Python; `pnpm` / `npm` / `cargo` for others). No bare interpreters.
- No `sys.path.insert` / PYTHONPATH hacks.
- Strict typing in new code.
- DRY max.
- TDD: plans start with failing tests.
- NO full-suite runs per task — targeted only.
- Plans finish with CLI / end-user run.

## Notifications

```
send_notification(title, body, urgency, session_id)
```

| Urgency | When |
|---|---|
| `high` | Worker blocked on human input; standing-rule escalation triggered (matrix) |
| `medium` | Worker awaits selection between approaches and you've recused |
| `low` | Major milestone informational (PR ready, tests green) |

For overnight/away escalations, end the body with "no action needed until you're up" or similar — respects "minimize interruptions" by signalling nothing is on fire while still surfacing the decision.

## MCP tools quick ref

| Need | Tool |
|---|---|
| list / select project | `list_projects` / `select_project` |
| list sessions (incl monitors) | `list_sessions(include_monitors=True)` |
| session detail | `get_session(sid)` |
| capture pane | `capture_session_output(sid)` |
| create worktree | `create_worktree(branch, from_ref)` |
| launch worker | `launch_session(worktree_id, prompt, model, permission_mode, name, monitor_level, monitor_permission_allow_list)` |
| send text | `send_action(sid, "send", text)` → ALWAYS tmux Enter follow-up |
| approve permission | `send_action(sid, "approve")` — ONLY tool-permission prompts, NEVER bypassPermissions confirm |
| deny permission | `send_action(sid, "deny")` |
| stop session | `stop_session(sid)` |
| browser notify user | `send_notification(title, body, urgency, session_id)` |
| monitor health | `get_monitor_status(sid)` |
| dangerous op | `delete_*` returns token → `confirm_dangerous_action(token)` |

## Recommended manager launch

Pre-approve all agent-dashboard MCP calls so the manager itself runs without per-tool prompts:

```
claude --model opus --permission-mode default --allowedTools "mcp__agent-dashboard__*"
```
