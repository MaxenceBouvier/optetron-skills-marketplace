# Manager Report File Template

The manager copies this scaffold once at pre-flight to `<project-repo-root>/megatask-report.md` and updates it on every wake.

## Scaffold (copy verbatim, substitute `<<...>>` at pre-flight)

```markdown
# <<PROJECT_NAME>> — Megatask Campaign Report

## Post-compaction continuity entry point

A fresh agent after compaction reads this section first to resume the campaign.

- **Mandate:** <<one-sentence: what is being built, who is unreachable, quality bar>>
- **Locked decisions (immutable for the duration of the campaign):**
  - No autonomous prod deploy
  - ff-only merges
  - Branch naming pattern: `<<config.branch_naming.pattern>>`
  - Acceptance method: `<<config.acceptance_verification.method>>`
  - Models: impl=`<<...>>`, spec-review=`<<...>>`, code-quality-review=`<<...>>`
  - Anti-laziness in option-picking enforced
  - Standing rules from `optetron:manager` apply
- **Current phase:** issue-<<N>> / sub-phase=<<...>> / status=<<...>>
- **Next action:** <<one-line>>
- **MCP state pointers:**
  - `project_id`: <<...>>
  - `manager_session_id`: <<...>>
  - `worker_session_ids`: { issue-1: <<...>>, ... }
  - `worktree_ids`: { issue-1: <<...>>, ... }
- **Verification commands to confirm state:**
  - `git log -5`
  - `gh issue list --state open`
  - `list_sessions(include_monitors=True)` (via MCP)

## Mandate

<<paragraph: what's being built, who is unreachable, quality bar, hard rules in one block>>

## Decisions locked at kickoff

- No autonomous prod deploy
- ff-only merges
- Branch naming pattern
- Acceptance verification method
- Models (impl / spec-review / code-quality-review)
- Anti-laziness in option-picking enforced
- Standing rules from `optetron:manager` apply

## Phase status

| # | Issue | Branch | Status | Notes |
|---|---|---|---|---|
| 1 | <<...>> | <<...>> | merged@<<sha>> / in-progress / queued | <<...>> |

## Wake log (append-only)

### Wake-1 (<<timestamp>>, sub-phase=<<...>>, cadence-set=<<Ns>>)

- What I saw: <<one paragraph from `capture_session_output`>>
- What the worker did: <<one paragraph>>
- F-flags raised: <<list>>
- `advisor()` called: <<yes/no, why, what it returned>>
- Decisions: <<list>>
- Next-wake reason: <<one specific sentence>>

## Current state at last checkpoint

A fresh post-compaction agent reads this section after the continuity entry point. **Rebuild every wake.**

- Phase snapshot table (mirrors §Phase status, latest)
- What was just shipped: <<merge-sha + brief>>
- What's next: <<issue # + sub-phase>>
- Current MCP state: <<rebuilt every wake>>
- Exact `gh` / `git` / MCP commands to verify and resume:
  ```bash
  git log --oneline -10
  gh issue list --state open --limit 20
  ```

## Per-phase launch prompt

For the upcoming phase, preserved verbatim, copy-paste-ready for resume:

```text
<<filled worker launch prompt for the upcoming phase>>
```
```

## Notes for the manager

- The continuity entry point and the "current state at last checkpoint" sections are duplicated by design — one is locked at kickoff and immutable; the other is rebuilt every wake. A fresh agent reads the locked section first, then the rebuilt section, then proceeds.
- Wake log is append-only. Never edit a past wake entry. Mistakes are corrected in subsequent wake entries with explicit references (`Wake-12 corrects Wake-11`).
- Phase-complete entries on issue closure include: merge SHA, close-comment link, screenshot/test artifact paths, total wakes, total advisor calls.
