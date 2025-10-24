# Installation Guide

This guide walks through installing the Proton Drive bisync automation from scratch on a Linux workstation.

## 1. Prerequisites

- **Systemd user session** enabled (`systemctl --user status` should work).
- **rclone 1.71.0 or newer**.
- **Proton account** with access to Proton Drive.
- **Bash**, `curl`, and `sed` installed (standard on most distros).

## 2. Clone the Repository

```bash
git clone https://gist.github.com/526cc5cafefdefd264c8422deb897e39.git proton-drive-bisync
cd proton-drive-bisync
```

## 3. Run the Installer

```
chmod +x install.sh uninstall.sh scripts/*.sh
./install.sh
```

The installer performs:

- Dependency checks for `rclone` and `systemd`.
- Remote configuration (`protondrive:` by default).
- Directory setup for sync and backups.
- Optional initial `rclone bisync --resync` dry-run and live run.
- Systemd unit rendering from templates in `config/`.
- Timer activation at the chosen interval.

### Notes

- Run the installer **as a regular user**, not with `sudo`.
- If `rclone` is missing or outdated, you will be prompted to upgrade automatically.
- When `rclone config` launches, select **`Proton Drive (protondrive)`** and follow the prompts to authenticate.
- The default sync directory is `~/Documents/Proton`; override during installation if desired.

## 4. Validate the Setup

After installation, confirm everything is healthy:

```
scripts/validate-setup.sh
```

Look for all checks reporting success (✓). Investigate any warnings before relying on automation.

## 5. Day-to-Day Usage

- `systemctl --user status rclone-bisync.timer` – view timer status.
- `systemctl --user start rclone-bisync.service` – trigger immediate sync.
- `tail -f ~/.cache/rclone/bisync.log` – follow sync logs in real time.

## 6. Uninstallation

To remove systemd automation and optional artifacts:

```
./uninstall.sh
```

You will be prompted before deleting logs or remote marker files.

## 7. Optional Non-Interactive Setup

For scripted environments, use `scripts/setup-proton-drive.sh --non-interactive` with flags such as `--remote`, `--sync-dir`, `--interval`, and `--cache-dir` to render units without prompts.

## 8. Troubleshooting

Consult `docs/TROUBLESHOOTING.md` for common issues and recovery steps.
