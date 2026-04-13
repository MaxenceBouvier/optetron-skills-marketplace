# Design: Manager Skill — Monitored Launch as Default

**Date:** 2026-04-13  
**Status:** Approved

## Problem

Managers reading the MCP tool schema see `monitor_level` and `monitor_permission_allow_list` as parameter names but have no idea what values to pass. The current skill documents those values in a separate "Monitor Agents" section far from the launch snippet. Managers also confuse `role="monitor"` (standalone monitor session) with `monitor_level="..."` (auto-attached sidecar), going down the wrong path.

## Goal

Make monitored session launch the obvious, copy-pasteable default — with inline notes for variations — so a manager never has to hunt for enum values.

## Design

### What changes

**Remove:**
- Current "Launching Sessions" block (the two separate snippets — bare then + `monitor_level`)
- Entire "Monitor Agents" section (lines 126–186 in current skill), which duplicates the snippet and adds a level table

**Replace with:** A single consolidated "Launching Sessions" section containing:

1. One canonical snippet with `monitor_level="full_auto"` and `monitor_permission_allow_list="Read,Grep,Glob,Write,Edit,Bash,NotebookEdit"` as defaults
2. Three inline bullet points explaining monitor option variants (no table):
   - `full_auto` vs `permissions_only` in one sentence each
   - How to extend the allow-list for MCP tools
   - How to omit the monitor entirely for mechanical tasks
3. Prompt guidelines (moved from current launching section, unchanged)
4. Two `get_monitor_status` / `list_sessions(include_monitors=True)` one-liners at the bottom of the section

**Keep unchanged:**
- Setup section
- MCP Tools Quick Reference table
- Session Status Table
- Inter-Session Communication section (including permission approve/deny)
- Browser Notifications section
- Monitoring section
- Recommended Launch Configuration section (about launching the manager itself, separate topic)

### Default allow-list rationale

`Read,Grep,Glob,Write,Edit,Bash,NotebookEdit` — standard Claude Code tools. MCP tools excluded by default (they affect external systems); managers add them explicitly via glob pattern if needed.

## Out of Scope

- Changes to `manage-brainstorming` skill
- Adding new bash scripting tools (no gap identified beyond what's already there)
- Changing the `role` parameter documentation
