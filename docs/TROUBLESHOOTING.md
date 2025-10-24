# Troubleshooting

This guide covers common issues when running Proton Drive bisync automation.

## 1. Installation Failures

- **`rclone not found`**
  - Install with the prompt in `install.sh` or follow [rclone downloads](https://rclone.org/downloads/).
  - Ensure `rclone` is in `PATH` before rerunning.
- **`systemd user instance is not active`**
  - Start it with `systemctl --user status` (auto-starts on most desktops).
  - On headless servers, enable lingering: `loginctl enable-linger $USER`.
- **`Unable to access Proton Drive via rclone`**
  - Run `rclone config reconnect protondrive:` and complete 2FA/device approval.
  - Confirm Proton's web dashboard lists the device as authorized.

## 2. Sync Errors

- **`--max-delete` aborts job**
  - Investigate large deletions before increasing the limit.
  - Run `rclone bisync protondrive:/ ~/Documents/Proton --check-access --dry-run` to preview.
- **Conflicts due to simultaneous edits**
  - Conflicting files receive suffixes (e.g., `_conflict`).
  - Resolve manually, then rerun `rclone bisync`.
- **Permission denied**
  - Ensure the sync directory is owned by your user.
  - Avoid running services as root.

## 3. Systemd Timer Issues

- **Timer inactive**
  - Start manually: `systemctl --user start rclone-bisync.timer`.
  - If it stops immediately, run `journalctl --user -u rclone-bisync.service -n 50`.
- **Timer not listed**
  - Re-render units: `scripts/setup-proton-drive.sh`.
  - Reload user daemon: `systemctl --user daemon-reload`.

## 4. Connectivity Problems

- **Proton Drive API errors**
  - Check [Proton status](https://status.proton.me/).
  - Retry later; `--resilient` handles transient outages.
- **Network drops mid-sync**
  - Timer retries on next interval; consider shorter intervals for quicker recovery.

## 5. Log Diagnostics

- **Tail logs**: `tail -f ~/.cache/rclone/bisync.log`
- **Journal**: `journalctl --user -u rclone-bisync.service`
- **Validate**: `scripts/validate-setup.sh`

## 6. Reconfiguring After Changes

- Edit templates in `config/` (e.g., update flags).
- Run `scripts/setup-proton-drive.sh` to regenerate units.
- Restart timer: `systemctl --user restart rclone-bisync.timer`.

## 7. Full Reset

1. Stop automation: `./uninstall.sh`
2. Remove cache directory if desired: `rm -rf ~/.cache/rclone`
3. Delete local sync directory (optional).
4. Re-run `install.sh`.

## 8. Getting Help

- Use `rclone` forums or Proton communities.
- Capture logs with `--log-level DEBUG` by editing the service template temporarily.
