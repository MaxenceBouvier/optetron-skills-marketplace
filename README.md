# optetron-skills-marketplace

Claude Code skill packs for agent orchestration, brainstorming workflows, and organizational roles.

## Plugins

| Plugin | Skills | Description |
|--------|--------|-------------|
| `agent-dashboard` | `smart-brainstorming`, `manager`, `manage-brainstorming` | Agent orchestration via the agent-dashboard MCP server |
| `optetron-roles` | `role-ceo`, `role-cto`, `role-swe`, `role-pm`, `role-cmo`, `role-legal`, `role-sales`, `role-secops` | Organizational role skills for multi-agent systems |
| `marketplace-tools` | `publish-skills` | Publish skill updates to GitHub |

## Installation

### 1. Register the marketplace

```bash
cd ~/.claude/plugins && python3 -c "
import json, pathlib
f = pathlib.Path('known_marketplaces.json')
d = json.loads(f.read_text())
d['optetron-skills-marketplace'] = {
  'source': {'source': 'git', 'url': 'https://github.com/MaxenceBouvier/optetron-skills-marketplace.git'},
  'installLocation': str(pathlib.Path.home() / '.claude/plugins/marketplaces/optetron-skills-marketplace'),
  'autoUpdate': True
}
f.write_text(json.dumps(d, indent=2))
print('Marketplace registered. Restart Claude Code to discover plugins.')
"
```

### 2. Enable plugins

In `~/.claude/settings.json`, add to `enabledPlugins`:

```json
{
  "enabledPlugins": {
    "agent-dashboard@optetron-skills-marketplace": true,
    "optetron-roles@optetron-skills-marketplace": true,
    "marketplace-tools@optetron-skills-marketplace": true
  }
}
```

### 3. Restart Claude Code

Skills will appear in the system-reminder skills list on next session start.

## Auto-Update

With `autoUpdate: true`, Claude Code fetches the latest commits on each session start. No manual pulls needed after initial registration.

## Publishing Changes

After editing skills, invoke `/publish-skills` in any Claude Code session (requires `marketplace-tools` plugin enabled). Or run directly:

```bash
cd ~/proj/optetron-skills-marketplace
git add -A
./scripts/release.sh
```
