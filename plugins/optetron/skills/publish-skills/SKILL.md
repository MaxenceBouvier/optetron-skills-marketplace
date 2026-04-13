---
name: publish-skills
description: Use when you want to publish skill changes to the optetron-skills-marketplace on GitHub — stages changes, bumps versions, commits, tags, and pushes
---

# Publish Skills

Publish pending skill edits from the optetron-skills-marketplace repo to GitHub so they become available to all Claude Code sessions on next session start.

## Steps

1. **Show what changed** — run `git diff --name-only` and `git status` to identify modified skills
2. **Stage changes** — `git add -A`
3. **Run release script** — `./scripts/release.sh`
   - Detects which plugins have changed files
   - Bumps patch version in each affected `plugin.json`
   - Creates a conventional commit (`release: bump <plugin> to <version>`)
   - Tags the release (`<plugin>-v<version>`)
   - Pushes commit + tags to origin
4. **Report** — summarize what was published: which plugins were bumped, what versions, what skills changed

## Notes

- The release script handles everything after staging. Just make sure changes are staged before running it.
- If only one plugin changed, only that plugin gets a version bump.
- Auto-update picks up the new commit on next Claude Code session start (no manual pull needed).
- The marketplace repo is at `~/proj/optetron-skills-marketplace`.
