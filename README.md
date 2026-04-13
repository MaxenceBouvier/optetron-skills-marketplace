# optetron-skills-marketplace

Claude Code skill packs for agent orchestration, brainstorming workflows, and organizational roles.

## Plugins

| Plugin | Skills | Description |
|--------|--------|-------------|
| `agent-dashboard` | `manager`, `manage-brainstorming` | Agent orchestration via the agent-dashboard MCP server |
| `optetron-roles` | `role-ceo`, `role-cto`, `role-swe`, `role-pm`, `role-cmo`, `role-legal`, `role-sales`, `role-secops` | Organizational role skills for multi-agent systems |
| `marketplace-tools` | `publish-skills` | Publish skill updates to GitHub |

## Installation

Requires Claude Code v2.1 or later.

### Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/MaxenceBouvier/optetron-skills-marketplace/main/scripts/install.sh | bash
```

Or clone and run:

```bash
git clone https://github.com/MaxenceBouvier/optetron-skills-marketplace.git
cd optetron-skills-marketplace && ./scripts/install.sh
```

### Manual install

```bash
claude plugin marketplace add MaxenceBouvier/optetron-skills-marketplace
claude plugin install agent-dashboard@optetron-skills-marketplace
claude plugin install optetron-roles@optetron-skills-marketplace
claude plugin install marketplace-tools@optetron-skills-marketplace
```

Restart Claude Code. Skills appear in the system-reminder skills list on next session start.

## Updating

Marketplace refresh is automatic on session start. To force-refresh:

```bash
claude plugin marketplace update optetron-skills-marketplace
```

## Publishing Changes

After editing skills, invoke `/publish-skills` in any Claude Code session (requires `marketplace-tools` plugin enabled). Or run directly:

```bash
cd ~/proj/optetron-skills-marketplace
git add -A
./scripts/release.sh
```
