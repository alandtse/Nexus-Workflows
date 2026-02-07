# Nexus Workflows

> Centralized Nexus Mods secret management and workflow distribution

This repository automatically manages and distributes Nexus Mods credentials across all mod repositories. Update your cookie once here, and all mods stay synchronized.

## Purpose

- **Centralized Management**: One place to update your Nexus session cookie and API key for all your mods.
- **Auto-Discovery**: Automatically finds and updates your mod repositories.
- **Reusable Workflows**: Standardized upload process for all your projects.

## Usage Modes

Choose the setup that best fits your needs:

### 1. Centralized Management (Private Controller) - **Best Practice**

- **What it is**: You create a separate **Private** repository to act as your "Secret Controller".
- **Why**: It hides your high-privilege PAT, mod repository list, and distribution logs from the public. This repository **will not run** the distribution workflow by default, preventing accidental leaks.
- **How**: Use the provided setup script to create your private controller in one command.
- **Secrets needed here**: `UNEX_NEXUSMODS_SESSION_COOKIE`, `UNEX_APIKEY`, and `GH_PAT_TOKEN`.

### 2. Standard Fork (Public Controller)

- **What it is**: You fork this repository publicly.
- **Note**: To enable secret distribution, you must **manually move** `.github/templates/distribute-secrets.yml` to `.github/workflows/distribute-secrets.yml`.
- **Security**: **Must** enable "Required Reviewers" for the `Production` environment.

### 3. Reusable Workflow Only (Direct Reference)

- **What it is**: You use the workflows in this repository directly from your mod projects.
- **Note**: No `GH_PAT_TOKEN` is required, but you must manually manage secrets in every mod repository.

## Quick Start

### 1. Initialize your Controller

Choose one of the following options to create your management repository:

#### Option A: Private Controller (Recommended)

Run this command in a terminal within your local copy of this repository:

```bash
# Automatically creates a private repo named "Nexus-Secrets" (default)
# and manages it in the local "controller/" directory:
pwsh ./scripts/setup-private-controller.ps1

# Or specify a custom name:
pwsh ./scripts/setup-private-controller.ps1 -RepoName "my-custom-secrets"

# Preview changes without making them:
pwsh ./scripts/setup-private-controller.ps1 -DryRun
```

#### Option B: Standard Fork

```bash
# Replace <your-username> with your actual GitHub username
gh repo create <your-username>/nexus-workflows --public --source=. --remote=origin --push
```

### 2. Add Secrets

- `UNEX_NEXUSMODS_SESSION_COOKIE`: Your `nexusmods_session` cookie.
  - **How to find it**:
    1.  Go to [Nexus Mods](https://www.nexusmods.com) and log in.
    2.  Press `F12` to open Developer Tools.
    3.  Go to the **Application** (Chrome/Edge) or **Storage** (Firefox) tab.
    4.  Expand **Cookies** in the left sidebar and select `https://www.nexusmods.com`.
    5.  Find the row named `nexusmods_session` and copy its **Value**.
- `UNEX_APIKEY`: Your [Nexus Personal API key](https://www.nexusmods.com/settings/api-keys).
- `GH_PAT_TOKEN`: A Personal Access Token used to update secrets in your other repositories.
  - **Recommendation**: Use a [**Fine-Grained PAT**](https://github.com/settings/personal-access-tokens).
    - **Repository access**: "All repositories" (owned by you).
    - **Permissions**:
      - `Actions` (Read-only)
      - `Metadata` (Read-only)
      - `Secrets` (Read and Write)
      - `Workflows` (Read and Write)
  - **Alternative**: A [Personal Access Token (Classic)](https://github.com/settings/tokens) with `repo` and `workflow` scopes.

3. **Test it:**
   - Go to Actions in your new private repository.
   - Run the **"Validate Access Rights"** workflow to confirm your PAT permissions are correct.
   - Run the **"Auto-Discover and Distribute"** workflow with `dry_run` checked.
   - Verify it discovers your mod repositories.

4. **Go live:**
   - Run again without dry_run
   - Secrets distributed to all mods!

### Excluding or Including Repositories

- **Exclude (Controller Repo)**: Add a variable or secret named `UNEX_EXCLUDE_REPOS` with a comma-separated list of repos (e.g., `alandtse/my-special-mod,alandtse/other-mod`).
- **Include (Controller Repo)**: Add a variable or secret named `UNEX_INCLUDE_REPOS` with a comma-separated list of repos to forcibly include, even if they aren't discovered by search (e.g. `alandtse/manual-repo`).
- **Decentralized (Mod Repo)**: Add a secret named `UNEX_SKIP` (with any value) to the mod repository itself. The controller will see this and skip distribution.

### Daily Usage

**When cookie expires:**

1. Get new cookie from https://www.nexusmods.com
2. Update `UNEX_NEXUSMODS_SESSION_COOKIE` secret here
3. Run "Auto-Discover and Distribute" workflow
4. Done - all mods updated!

## Using in Mod Repos

Update `.github/workflows/build.yml` in your mod repository:

```yaml
jobs:
  # ... existing build job

  upload-to-nexus:
    needs: build
    if: needs.build.outputs.new_release_version != ''
    uses: <your-username>/nexus-workflows/.github/workflows/upload-nexus.yml@v1
    with:
      nexus_game_id: skyrimspecialedition # or fallout4, etc.
      nexus_mod_id: "12345" # Your mod ID
      artifact_name: ModName_${{ needs.build.outputs.new_release_version }}
      # OR use tag_name for existing releases:
      # tag_name: v${{ needs.build.outputs.new_release_version }}
      mod_version: ${{ needs.build.outputs.new_release_version }}
      changelog: ${{ needs.build.outputs.new_release_notes }}
    secrets:
      UNEX_NEXUSMODS_SESSION_COOKIE: ${{ secrets.UNEX_NEXUSMODS_SESSION_COOKIE }}
      UNEX_APIKEY: ${{ secrets.UNEX_APIKEY }}
```

## Maintenance & Updates

### Updating the Private Controller

To pull the latest workflow logic and security fixes from the upstream template into your private controller:

```bash
# In this repository (the public template), run the setup script again:
pwsh ./scripts/setup-private-controller.ps1
```

The script will automatically detect your existing `controller/` directory and push the latest logic to your private repository.

### Updating Mod Repositories

If you pin your mod repositories to a specific **commit hash**, you should periodically check this repository for updates and move the hash forward in your mod CI files.

## How It Works

1. **Auto-Discovery**: Scans your repositories for `UNEX_NEXUSMODS_SESSION_COOKIE` usage.
2. **Refresh Cookie**: Tests and refreshes the Nexus session every 5 days.
3. **Distribute**: Pushes updated cookie to all discovered mod repositories.
4. **Alert**: Notifies if manual update is needed.

## Available Workflows

### distribute-secrets.yml

Main workflow - discovers and updates all mod repositories.

- **Schedule**: Every 5 days
- **Manual**: Can trigger anytime
- **Dry run**: Test without updating (identifies repositories without pushing)

### upload-nexus.yml

Reusable workflow for uploading mods.

- **Inputs**: game_id, mod_id, version, changelog, etc.
- **check_existing**: (Optional) Check Nexus API and skip if version exists (default: false)
- **artifact_name**: (Optional) Name of the GitHub artifact to download
- **tag_name**: (Optional) GitHub Release tag to download from (if artifact_name is empty)
- **Automatic**: Refreshes cookie before upload
- **Smart**: Finds archive files automatically

## Available Actions

### check-nexus

Validates Nexus Mods credentials without refreshing them. Useful for testing credentials before running uploads.

**Inputs:**

- `nexus-session-cookie`: Your Nexus Mods session cookie (required)
- `nexus-api-key`: Your Nexus Mods API key (required)

**Example usage:**

```yaml
- name: Validate Nexus credentials
  uses: <your-username>/nexus-workflows/.github/actions/check-nexus@v1
  with:
    nexus-session-cookie: ${{ secrets.UNEX_NEXUSMODS_SESSION_COOKIE }}
    nexus-api-key: ${{ secrets.UNEX_APIKEY }}
```

**When to use:**

- Pre-flight validation before attempting uploads
- Testing new credentials after rotation
- Debugging authentication issues

## For Organizations

This setup is highly flexible for organizations:

1. **Native Org Secrets**: If your repositories are in a GitHub Organization, you can skip this tool and use **Organization Secrets** instead.
2. **Hybrid Approach**: Use this tool if you have many repositories and want the **Auto-Discovery** benefit without manually managing the repository list in Organization settings.
3. **Disable Distribution**: Simply disable or delete `distribute-secrets.yml` and use the central repository only for the **Reusable Workflows**.

## Security & PAT Scope

> [!WARNING]
> **High Privilege Token**: The `GH_PAT_TOKEN` requires `repo` and `workflow` scopes to discover and update secrets across your repositories. Treat this token with the same care as your primary GitHub password.

### Security Best Practices

1. **Review Upstream Changes**: Before pulling or merging new changes from this repository into your fork, **always review the code**. A malicious update to the distribution workflow could exfiltrate your secrets.
2. **Environment Approvals (Critical)**:
   - This repository is configured to use the `Production` environment for secret distribution.
   - **Action Required**: Go to `Settings -> Environments -> Production` in your fork.
   - Enable **Required reviewers** and add yourself.
   - This ensures no secrets can be distributed without your manual approval for each run.
3. **Pinning Workflow Versions**:
   - For maximum security in your mod repositories, pin the reusable workflow to a specific **commit hash** instead of a version tag.
   - **Example**: `uses: alandtse/nexus-workflows/.github/workflows/upload-nexus.yml@a1b2c3d4...`
   - This prevents your mod project from automatically using new (and potentially compromised) versions of the workflow until you manually update the hash.
4. **Leak Protection**: GitHub Actions **DO NOT** pass secrets to workflows triggered by Pull Requests from forks.

- **Idempotency**: Discovery and distribution are safe to re-run; they will only update the values you provide.

## Instructions for AI Agents

Detailed guidelines for AI assistants (Droid, Cursor, Copilot, Gemini, etc.) are available in [AI_INSTRUCTIONS.md](AI_INSTRUCTIONS.md).

## License

[GNU Affero General Public License v3.0](COPYING)

## Credits

- [BUTR.NexusUploader](https://github.com/BUTR/BUTR.NexusUploader)
- [BUTR Workflows](https://github.com/BUTR/workflows)
