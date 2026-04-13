#!/usr/bin/env bash
# release.sh — bump versions for changed plugins, commit, tag, and push
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Ensure we have staged changes or uncommitted changes to process
if git diff --quiet && git diff --cached --quiet; then
  echo "Nothing to release — no changes detected."
  exit 0
fi

# Stage everything if nothing is staged yet
if git diff --cached --quiet; then
  git add -A
fi

# Identify which plugins have changes
changed_plugins=()
while IFS= read -r file; do
  if [[ "$file" == plugins/*/skills/* || "$file" == plugins/*/.claude-plugin/plugin.json ]]; then
    plugin=$(echo "$file" | cut -d/ -f2)
    if [[ ! " ${changed_plugins[*]} " == *" ${plugin} "* ]]; then
      changed_plugins+=("$plugin")
    fi
  fi
done < <(git diff --cached --name-only)

if [[ ${#changed_plugins[@]} -eq 0 ]]; then
  echo "No plugin skill changes detected in staged files."
  echo "Staged files:"
  git diff --cached --name-only
  exit 1
fi

echo "Changed plugins: ${changed_plugins[*]}"

# Bump patch version for each changed plugin
bump_version() {
  local version="$1"
  local major minor patch
  IFS='.' read -r major minor patch <<< "$version"
  echo "${major}.${minor}.$((patch + 1))"
}

declare -A new_versions
for plugin in "${changed_plugins[@]}"; do
  plugin_json="plugins/$plugin/.claude-plugin/plugin.json"
  current=$(python3 -c "import json; print(json.load(open('$plugin_json'))['version'])")
  new_ver=$(bump_version "$current")
  new_versions[$plugin]="$new_ver"

  # Update plugin.json version
  python3 -c "
import json
f = open('$plugin_json')
d = json.load(f)
f.close()
d['version'] = '$new_ver'
open('$plugin_json', 'w').write(json.dumps(d, indent=2) + '\n')
"
  git add "$plugin_json"
  echo "  $plugin: $current -> $new_ver"
done

# Build commit message
plugins_summary=$(for p in "${!new_versions[@]}"; do echo "$p@${new_versions[$p]}"; done | sort | tr '\n' ' ')
git commit -m "release: bump ${plugins_summary% }"

# Tag each plugin
for plugin in "${!new_versions[@]}"; do
  tag="${plugin}-v${new_versions[$plugin]}"
  git tag "$tag"
  echo "  Tagged: $tag"
done

# Push commit and tags
git push origin HEAD
git push origin --tags

echo ""
echo "Published successfully:"
for plugin in "${!new_versions[@]}"; do
  echo "  $plugin v${new_versions[$plugin]}"
done
