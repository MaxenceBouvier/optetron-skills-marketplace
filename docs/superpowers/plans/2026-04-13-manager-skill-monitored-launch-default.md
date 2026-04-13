# Manager Skill — Monitored Launch Default Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make monitored session launch the single default pattern in the manager skill, with inline notes for variations, removing the separate "Monitor Agents" section.

**Architecture:** Edit one Markdown file — replace the "Launching Sessions" section (lines 19–43) with a consolidated version, then delete the "Monitor Agents" section (lines 126–186). No other sections change.

**Tech Stack:** Markdown, git.

---

### Task 1: Replace the "Launching Sessions" section

**Files:**
- Modify: `plugins/agent-dashboard/skills/manager/SKILL.md:19-43`

- [ ] **Step 1: Verify the exact current text to replace**

Read lines 19–43 of `plugins/agent-dashboard/skills/manager/SKILL.md` and confirm they start with `## Launching Sessions` and end with the `send-keys` tmux note. The exact block to replace is:

```markdown
## Launching Sessions

```
create_worktree(branch="feature-name", from_ref="main")
launch_session(worktree_id=N, prompt="...", model="opus", permission_mode="default", name="feature-name")
```

To launch with an automatic monitor sidecar, add `monitor_level`:

```
launch_session(worktree_id=N, prompt="...", model="opus", permission_mode="default", name="feature-name", monitor_level="full_auto")
```

- Always create a dedicated worktree per task
- Give sessions descriptive names matching the worktree branch
- Provide a clear, detailed prompt with full context (the session has no prior conversation history)
- Escape backticks in prompts (known bug: backticks in double-quoted shell args trigger command substitution)
- **For creative / design work (features, components, new functionality, behavior changes): the prompt MUST begin with the literal string `/brainstorming`.** This invokes `superpowers:brainstorming` as the first thing the worker sees, before it can skip the design gate. Do NOT embed the directive in prose — the slash command must be the first characters of the prompt. This does not apply to workers executing an already-approved plan or running mechanical tasks.
- When referencing superpowers skills in prompts, use exact current names:
  - `superpowers:brainstorming` (NOT `brainstorm` — deprecated)
  - `superpowers:systematic-debugging` (NOT `debugging`)
  - `superpowers:subagent-driven-development` (full name)
  - `superpowers:writing-plans` / `superpowers:executing-plans`
- After `send_action`, verify the message landed — pasted text may need Enter via tmux:
  `TMUX="" tmux -L agent-dashboard send-keys -t <tmux_session> Enter`
```

- [ ] **Step 2: Replace with the consolidated section**

Replace the block above with:

```markdown
## Launching Sessions

Always create a dedicated worktree per task, then launch with a monitor sidecar — this is the default:

```
create_worktree(branch="feature-name", from_ref="main")
launch_session(
    worktree_id=N,
    prompt="...",
    model="opus",
    permission_mode="default",
    name="feature-name",
    monitor_level="full_auto",
    monitor_permission_allow_list="Read,Grep,Glob,Write,Edit,Bash,NotebookEdit"
)
```

**Monitor options:**
- `monitor_level="full_auto"` — monitor auto-approves permissions AND handles work-direction questions autonomously. Use `"permissions_only"` to only auto-approve permissions (questions escalate to you instead).
- `monitor_permission_allow_list` — the list above covers standard Claude Code tools. Extend for MCP tools: `"...,mcp__agent-dashboard__*"`. Use `"*"` to allow everything (not recommended).
- Omit `monitor_level` entirely for very short mechanical tasks that don't need a monitor.

**Prompt guidelines:**
- Give full context — the session has no prior conversation history
- Escape backticks in prompts (known bug: backticks in double-quoted shell args trigger command substitution)
- **For creative/design work:** prompt must begin with `/brainstorming` as literal first characters
- Use exact skill names: `superpowers:brainstorming`, `superpowers:systematic-debugging`, `superpowers:subagent-driven-development`, `superpowers:writing-plans`, `superpowers:executing-plans`

**Checking monitor health:**
```
get_monitor_status(session_id)        # activation count, escalation count, budget usage
list_sessions(include_monitors=True)  # monitors are hidden from list_sessions by default
```
```

- [ ] **Step 3: Verify the edit landed cleanly**

Read lines 18–55 of the file and confirm:
- The section starts with `## Launching Sessions`
- There is exactly ONE code block showing `launch_session(...)` with `monitor_level` and `monitor_permission_allow_list`
- The `## MCP Tools Quick Reference` section immediately follows (no "Monitor Agents" heading visible yet in this range)

---

### Task 2: Remove the "Monitor Agents" section

**Files:**
- Modify: `plugins/agent-dashboard/skills/manager/SKILL.md:~126-186`

- [ ] **Step 1: Verify the exact block to delete**

Read the file and locate the `## Monitor Agents` heading. Confirm the section runs from that heading through the end of the "Tmux output capture" subsection (the `capture_session_output(session_id)` block). The exact block to delete is:

```markdown
## Monitor Agents

Workers can be launched with an automatic monitor sidecar that handles
interruptions without human intervention.

### Launching with a monitor

```
launch_session(
    worktree_id=N,
    prompt="detailed task context...",
    model="opus",
    permission_mode="default",
    name="feature-auth",
    monitor_level="full_auto"
)
```

### Monitor levels

| Level | Permissions | Work direction questions |
|-------|-------------|------------------------|
| `permissions_only` | Auto-approve via rule engine | Escalate to user |
| `full_auto` | Auto-approve via rule engine | Monitor reads output and answers |

### Permission allow-list

By default, monitors auto-approve standard Claude Code tools (`Read,Grep,Glob,Write,Edit,Bash,NotebookEdit`).
MCP tools are NOT auto-approved by default — add them explicitly if needed:
`monitor_permission_allow_list="Read,Grep,Glob,Write,Edit,Bash,NotebookEdit,mcp__agent-dashboard__*"`.
Supports glob patterns: `"mcp__*"` matches all MCP tools. Use `"*"` to allow everything (not recommended).

### Checking monitor health

```
get_monitor_status(session_id)
```

Returns: activation count, escalation count, rate limit status, budget usage.

### Visibility

Monitors are hidden from `list_sessions` by default.
Use `list_sessions(include_monitors=True)` to see them.

### Tmux output capture

```
capture_session_output(session_id)
```

Returns cleaned terminal output (ANSI stripped, Claude chrome removed).
Useful for reading what a worker session is currently showing.
```

- [ ] **Step 2: Delete the section**

Replace the entire `## Monitor Agents` block (identified above) with an empty string — i.e., delete it with no replacement content.

- [ ] **Step 3: Verify the deletion**

Read the file and confirm:
- The string `## Monitor Agents` does not appear anywhere
- The section that previously followed "Monitor Agents" (`## Recommended Launch Configuration`) now immediately follows `## Monitoring`
- Total line count is approximately 130–135 (down from ~187)

- [ ] **Step 4: Commit**

```bash
git add plugins/agent-dashboard/skills/manager/SKILL.md
git commit -m "feat(manager): make monitored launch the default, remove Monitor Agents section"
```

---

### Task 3: Publish the updated skill

**Files:**
- No file changes — invoke the publish-skills skill

- [ ] **Step 1: Invoke the publish-skills skill**

Use the `optetron:publish-skills` skill to bump the version, tag, and push the `agent-dashboard` plugin.

---

## Self-Review

**Spec coverage:**
- ✅ Single canonical snippet with `full_auto` + `Read,Grep,Glob,Write,Edit,Bash,NotebookEdit` as defaults → Task 1
- ✅ Inline notes for `permissions_only`, extended allow-list, bare launch opt-out → Task 1 Step 2
- ✅ `Monitor Agents` section deleted → Task 2
- ✅ `get_monitor_status` / `list_sessions(include_monitors=True)` preserved in new section → Task 1 Step 2
- ✅ All other sections unchanged (spec explicitly calls them out of scope)

**Placeholder scan:** No TBDs, no "implement later", all steps show exact content.

**Type/name consistency:** No code types — Markdown only. Section names and tool call names are consistent between tasks.
