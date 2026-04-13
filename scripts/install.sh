#!/usr/bin/env bash
set -euo pipefail

# Install the optetron-skills-marketplace and all its plugins via the native
# Claude Code CLI. Idempotent — safe to re-run.

MARKETPLACE_NAME="optetron-skills-marketplace"
MARKETPLACE_SOURCE="MaxenceBouvier/optetron-skills-marketplace"
PLUGINS=(
  "optetron"
  "optetron-roles"
)

if ! command -v claude > /dev/null 2>&1; then
  echo "error: 'claude' CLI not found. Install Claude Code first: https://claude.com/claude-code" >&2
  exit 1
fi

echo "==> Registering marketplace: $MARKETPLACE_SOURCE"
if claude plugin marketplace list 2> /dev/null | grep -q "$MARKETPLACE_NAME"; then
  echo "    already registered, skipping"
else
  claude plugin marketplace add "$MARKETPLACE_SOURCE"
fi

for plugin in "${PLUGINS[@]}"; do
  echo "==> Installing plugin: $plugin@$MARKETPLACE_NAME"
  if claude plugin list 2> /dev/null | grep -q "$plugin@$MARKETPLACE_NAME"; then
    echo "    already installed, skipping"
  else
    claude plugin install "$plugin@$MARKETPLACE_NAME"
  fi
done

echo
echo "Done. Restart Claude Code to pick up the new skills."
