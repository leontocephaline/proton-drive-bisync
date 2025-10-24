# Configuration Options

Tune the Proton Drive bisync automation to fit your environment. This guide covers common adjustments after the initial install.

## 1. rclone Remote

- **Default**: `protondrive`
- **Change**: Run `rclone config` to add or edit remotes.
- **Automation**: Update systemd units via `scripts/setup-proton-drive.sh --remote <remote-name>`.

## 2. Sync Directories

- **Local sync root**: defaults to `~/Documents/Proton`
- **Backup directory**: created during installation; optional for manual backups
- **Modify**:
```
scripts/setup-proton-drive.sh --sync-dir /path/to/folder
```
- Regenerate units to apply changes.

## 3. Sync Interval

- **Default**: `30min`
- **Supported**: Any `systemd` time span (`15min`, `1h`, `2h30m`, etc.).
- **Change**:
```
scripts/setup-proton-drive.sh --interval 1h
```

## 4. Cache and Logging

- **Location**: `~/.cache/rclone`
- **Customize**:
```
scripts/setup-proton-drive.sh --cache-dir ~/.local/share/proton-bisync
```
- **Log file**: `${CACHE_DIR}/bisync.log`

## 5. Non-Interactive Rendering

For automated deployments:
```
scripts/setup-proton-drive.sh \
  --non-interactive \
  --remote protondrive \
  --sync-dir /srv/proton \
  --interval 15min \
  --cache-dir /var/cache/proton-bisync
```

## 6. Temporarily Disabling Automation

- **Stop timer**: `systemctl --user stop rclone-bisync.timer`
- **Disable restart on login**: `systemctl --user disable rclone-bisync.timer`
- **Re-enable**: `systemctl --user enable --now rclone-bisync.timer`

## 7. Manual Sync

Run the service unit directly:
```
systemctl --user start rclone-bisync.service
```

## 8. Safety Controls

Key `rclone bisync` flags embedded in the service template:

- `--max-delete 10` – aborts if more than 10 deletions detected
- `--conflict-resolve newer` – keeps latest modified file
- `--conflict-loser num` – appends numeric suffix to loser file
- `--create-empty-src-dirs` – preserves directory structure
- `--resilient` – retries transient errors

Adjust these by editing `config/rclone-bisync.service.template` before rerunning the setup script.

## 9. Custom Executable Paths

If `rclone` resides outside `PATH`:
```
scripts/setup-proton-drive.sh --rclone-bin /opt/rclone/rclone
```

## 10. Remote Markers

The installer writes `RCLONE_TEST` locally and remotely to verify connectivity. Delete manually if unnecessary.
