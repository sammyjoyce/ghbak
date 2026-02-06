# ghbak

Per-owner daily backups for **all repositories in a GitHub organization** (GitHub Cloud).

This is designed for situations where policy requires **each org owner** to keep an **independent** daily backup on their personal desktop.

## What it backs up
- **Git history + all refs** for every repo in the org (via `git clone --mirror`)
- **Git LFS objects** (via `git lfs fetch --all`, stored separately)
- Optional: **wikis** (`repo.wiki.git`)
- Optional: **daily snapshots with retention** using `restic` (recommended)

Not included: issues/PRs/comments, secrets, Actions artifacts.

## Directory layout
By default backups go to:

- `~/Backups/github/<org>/mirrors/<repo>.git` (bare mirror)
- `~/Backups/github/<org>/lfs/<repo>/` (LFS object store)
- `~/Backups/github/<org>/wikis/<repo>.wiki.git` (optional)

## Prerequisites (per owner)
1. **GitHub CLI auth** (used for repo discovery):
   ```bash
   gh auth login
   ```
2. **SSH access to GitHub** (used for cloning/fetching):
   ```bash
   ssh -T git@github.com
   ```
   For unattended runs (systemd timer), ensure your SSH key is available non-interactively (ssh-agent running with the key loaded, or a dedicated key without a passphrase).

   If you prefer HTTPS cloning instead of SSH, set `GIT_PROTOCOL=https` and run:
   ```bash
   gh auth setup-git
   ```
3. `git`, `git-lfs` (required unless you set `LFS_MODE=never`), optionally `restic`.

If you use the Nix flake below, dependencies are provided.

## Install / run (Nix)
From this repo:

```bash
nix run . -- run --org example-org
```

Or install into your user profile:

```bash
nix profile install .
```

Then:

```bash
ghbak run --org example-org
```

## Optional config via environment file (systemd)
Copy the example:

```bash
mkdir -p ~/.config/ghbak
cp config/env.example ~/.config/ghbak/env
$EDITOR ~/.config/ghbak/env
```

Minimum required:

```ini
ORG=example-org
```

Enable wiki backups:

```ini
INCLUDE_WIKI=1
```

Enable restic snapshots:

```ini
SNAPSHOT_MODE=restic
# Defaults used if not set:
# RESTIC_REPOSITORY=$HOME/Backups/restic/github-<org>
# RESTIC_PASSWORD_FILE=$HOME/.config/restic/github-<org>.pass
```

### Restic one-time setup
Create a password file:

```bash
mkdir -p ~/.config/restic
umask 077
openssl rand -base64 48 > ~/.config/restic/github-example-org.pass
```

Init the repo:

```bash
mkdir -p ~/Backups/restic/github-example-org
restic -r ~/Backups/restic/github-example-org init \
  --password-file ~/.config/restic/github-example-org.pass
```

## Daily automation (systemd user timer)
Copy unit files:

```bash
mkdir -p ~/.config/systemd/user
cp systemd/user/ghbak.service ~/.config/systemd/user/
cp systemd/user/ghbak.timer ~/.config/systemd/user/

systemctl --user daemon-reload
systemctl --user enable --now ghbak.timer
systemctl --user list-timers | grep ghbak
```

View logs:

```bash
journalctl --user -u ghbak.service -n 200 --no-pager
```

## Proof of daily backup (for policy / audit)
After each run, `ghbak` writes small state files you can point to:

- `~/Backups/github/<org>/state/last_run` (always updated)
- `~/Backups/github/<org>/state/last_summary` (result summary)
- `~/Backups/github/<org>/state/last_success` (only updated on a fully successful run)
- `~/Backups/github/<org>/state/repos.tsv` (repo discovery output used for the run)

## Restore runbook
### Restore git history
Create a new empty repo on GitHub, then:

```bash
git -C ~/Backups/github/<org>/mirrors/<repo>.git \
  push --mirror git@github.com:<org>/<repo>.git
```

### Restore LFS objects (if used)
After restoring the git repo, push LFS objects:

```bash
git clone git@github.com:<org>/<repo>.git /tmp/<repo>
cd /tmp/<repo>

# Point git-lfs at your backup object store
git config lfs.storage "$HOME/Backups/github/<org>/lfs/<repo>"

git lfs push --all origin
```

## Notes on “backup semantics”
- The mirror fetch does **not prune** deleted branches by default, and `gc.auto` is disabled in the mirror.
- If you enable `restic`, you get true point-in-time daily restore points.

## License
MIT (see `LICENSE`).
