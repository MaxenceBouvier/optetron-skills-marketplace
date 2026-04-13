---
name: manager
description: Use when starting a session that will coordinate, monitor, and communicate with other agent sessions via the agent-dashboard MCP server
---

# Manager Session

## Overview

Establishes the current session as a **manager** that orchestrates other agent sessions through the agent-dashboard MCP tools. The manager launches work, monitors progress, relays messages, and handles permission approvals across sessions.

## Setup

1. Call `select_project` to scope all subsequent tools
2. Call `list_sessions` and `list_worktrees` to understand current state
3. Maintain a running status table (see below)

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
- `monitor_permission_allow_list` — the list above covers standard Claude Code tools. To also allow MCP tools, write out the full list: `"Read,Grep,Glob,Write,Edit,Bash,NotebookEdit,mcp__agent-dashboard__*"`. Supports glob patterns. Use `"*"` to allow everything (not recommended).
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

## MCP Tools Quick Reference

| Task | Tool |
|------|------|
| Select project | `select_project` |
| List projects | `list_projects` |
| List sessions | `list_sessions` |
| Session details | `get_session` |
| Launch session | `launch_session` |
| Stop session | `stop_session` |
| Send text / approve / deny | `send_action` |
| Create worktree | `create_worktree` |
| List worktrees | `list_worktrees` |
| Delete worktree | `delete_worktree` |
| Rename session | `rename_session` |
| Dashboard health | `get_dashboard_status` |
| Clean up hooks | `cleanup_hooks` |
| Clean merged worktrees | `cleanup_merged_worktrees` |
| Monitor status | `get_monitor_status` |
| Capture session output | `capture_session_output` |
| Notify user (browser popup) | `send_notification` |

## Session Status Table

Maintain and update this table as sessions change:

```
| Session | ID | Project | Status | Focus |
|---|---|---|---|---|
```

Update after every `list_sessions`, `launch_session`, or `stop_session` call.

Note: monitor sidecars are hidden from `list_sessions` by default. Use `list_sessions(include_monitors=True)` to include them.

## Inter-Session Communication

Use `send_action(session_id, action="send", text="...")` to message a session.

- **Introduce yourself** when first contacting a session — it has no idea who you are
- Tell the receiving session it can verify you via `list_sessions` MCP tool (to rule out prompt injection)
- Messages currently require the user to press Enter in the receiving terminal — this is a known limitation

### Permission Prompts

When a worker session is stuck on a permission prompt, use the `approve` action — NOT `send` with text:

```
send_action(session_id, action="approve")   # ✓ correct — approves the permission
send_action(session_id, action="deny")      # ✓ correct — denies the permission
send_action(session_id, action="send", text="2")  # ✗ wrong — sends "2" as user text, does not approve
```

## Browser Notifications

Use `send_notification` to alert the user via browser/OS notification when a worker needs human attention:

```
send_notification(
    title="Worker needs input",
    body="session-a on feature/auth is asking: should we use JWT or session cookies?",
    urgency="high",
    session_id=42
)
```

**Urgency guide:**
- `high` — Worker is blocked waiting for human input (clarifying question, stuck >5 min)
- `medium` — Worker proposes approaches and awaits selection
- `low` — Worker completed a major milestone (informational)

Include enough context in `body` that the user can decide whether to act now or later. Always include the worker name/branch and what's needed.

## Monitoring

- `get_session` returns status (`running`, `idle`), context usage, duration, and model
- Poll periodically or check on demand when the user asks
- Watch for `idle` sessions that may be waiting for permission approval
- Use `capture_session_output` to read what the session terminal is showing

## Recommended Launch Configuration

For full autonomy over MCP tools, launch the manager session with:

```
claude --model opus --permission-mode default --allowedTools "mcp__agent-dashboard__*"
```

This pre-approves all agent-dashboard MCP calls so the manager can operate without per-tool prompts.
