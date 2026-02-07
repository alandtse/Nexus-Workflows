# AI Agent Instructions for Nexus Workflows

This project is optimized for AI assistance. These instructions are shared across various agent formats (.cursorrules, .claude/CLAUDE.md, etc.) via symlinks.

## General Principles

- **No Emojis**: Do not use emojis in commit messages, logs, or workflow files.
- **Conventional Commits**: Always follow the Conventional Commits specification (e.g., `feat:`, `fix:`, `chore:`, `docs:`).
- **Security**: Never log sensitive values. Use `::add-mask::` when working with secrets that might be printed.
- **Automation**: Prefer using the GitHub CLI (`gh`) for setup and management tasks.

## Setup Tasks for Agents

### 1. Configure Repository Secrets

To help the user set up secrets programmatically:

```bash
# Required Secrets:
# UNEX_NEXUSMODS_SESSION_COOKIE
# UNEX_APIKEY
# GH_PAT_TOKEN (with 'repo' scope)

echo "VALUE" | gh secret set SECRET_NAME --repo <your-username>/nexus-workflows
```

### 2. Trigger Discovery & Distribution

```bash
gh workflow run distribute-secrets.yml --repo <your-username>/nexus-workflows
```

### 3. Verify Workflow Status

```bash
gh run list --workflow distribute-secrets.yml --limit 1 --repo <your-username>/nexus-workflows
```

## Maintenance Guidelines

- When updating workflows, ensure any new `gh` commands use standard input for secret values.
- Maintain the auto-discovery logic; do not hardcode repository lists unless explicitly requested.
- Always update `CHANGELOG.md` via the automated semantic-release process.
