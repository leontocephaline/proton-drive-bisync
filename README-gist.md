# Proton Drive Sync - Manual Setup Guide

> **⚠️ Disclaimer**: This is an independent community project and is **not affiliated with**, endorsed by, or supported by Proton AG or Proton Drive. This is a hobbyist project provided as-is with no warranty. Use at your own risk.

Quick reference for manually configuring Proton Drive bidirectional sync on Linux.

> **⚡ Want an automated installer?**  
> 👉 **Full Project: https://github.com/leontocephaline/proton-drive-bisync**  
> Complete solution with one-command installation, systemd automation, multi-distro support, and comprehensive documentation.


---

## Manual Setup (Advanced Users)

This guide walks you through manually setting up bidirectional sync between your Linux system and Proton Drive using rclone and systemd.

### Prerequisites
- Linux with systemd
- Root/sudo access for rclone installation
- Proton account (free tier works)

---

## Installation Steps

### 1. Install rclone (1.71.0+)

**What this does**: Downloads and installs rclone, the tool that handles syncing with cloud storage.

**Why version 1.71.0+**: The `bisync` feature requires this minimum version for stability and Proton Drive support.

```bash
curl https://rclone.org/install.sh | sudo bash
```

Verify installation:
```bash
rclone version
```

### 2. Configure Proton Drive Remote

**What this does**: Authenticates rclone with your Proton Drive account and stores credentials securely.

**Why needed**: rclone needs permission to access your Proton Drive files. Authentication happens via your browser and requires your Proton password plus 2FA if enabled.

```bash
rclone config
```

Follow these prompts:
- **n** - New remote
- **Name**: `protondrive` (you can use any name, but examples use this)
- **Type**: Choose **Proton Drive (protondrive)**
- Follow authentication steps in your browser
- Approve device in Proton account if prompted

Test connection:
```bash
rclone lsd protondrive:/
```

**Expected output**: List of folders in your Proton Drive root.

### 3. Create Local Sync Directory

**What this does**: Creates the folder where your Proton Drive files will be synced locally.

**Why `~/.cache/rclone`**: rclone stores log files here. We create it explicitly because rclone won't create parent directories automatically.

```bash
mkdir -p ~/Documents/Proton
mkdir -p ~/.cache/rclone
```

**Note**: You can use any directory instead of `~/Documents/Proton` - just update all subsequent commands and the systemd service accordingly.

### 4. Initial Resync

**What this does**: Performs the first sync between your Proton Drive and local folder, establishing a baseline for future bidirectional syncs.

**Why `--resync`**: Required for the first run to build the sync database. Future syncs won't need this flag.

```bash
rclone bisync protondrive:/ ~/Documents/Proton \
  --resync \
  --create-empty-src-dirs \
  --compare size,modtime \
  --max-delete 10 \
  --conflict-resolve newer \
  --conflict-loser num \
  -v
```

**Flag explanations**:
- `--resync`: First-time setup (rebuilds sync database)
- `--create-empty-src-dirs`: Syncs empty folders too
- `--compare size,modtime`: Uses file size and modification time to detect changes
- `--max-delete 10`: **Safety**: Aborts if >10 files would be deleted (prevents accidental data loss)
- `--conflict-resolve newer`: When both sides changed, keeps the newer file
- `--conflict-loser num`: Renames the older conflicting file (e.g., `file.txt.conflict1`)
- `-v`: Verbose output to see what's happening

**Create safety marker** (verifies sync is working):
```bash
touch ~/Documents/Proton/RCLONE_TEST
rclone copy ~/Documents/Proton/RCLONE_TEST protondrive:/
```

**Why**: The `--check-access` flag (used in automated sync) verifies this file exists before syncing. Prevents syncing to wrong/empty locations.

### 5. Create Systemd Service

**What this does**: Defines the sync command that systemd will run periodically.

**Why systemd**: Runs automatically in the background without needing a terminal open. Starts on login and survives reboots.

Create `~/.config/systemd/user/rclone-bisync.service`:

```ini
[Unit]
Description=Rclone Bisync for Proton Drive
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/rclone bisync protondrive:/ %h/Documents/Proton \
  --create-empty-src-dirs \
  --compare size,modtime \
  --check-access \
  --max-delete 10 \
  --conflict-resolve newer \
  --conflict-loser num \
  --resilient \
  --log-file %h/.cache/rclone/bisync.log \
  --log-level INFO

[Install]
WantedBy=default.target
```

**Key settings**:
- `Type=oneshot`: Service runs once per trigger (not a daemon)
- `%h`: Expands to your home directory
- `--check-access`: Aborts if RCLONE_TEST file is missing (safety check)
- `--resilient`: Retries on transient network errors
- `--log-level INFO`: Detailed logs without being too verbose

### 6. Create Systemd Timer

**What this does**: Schedules when the sync service runs automatically.

**Why a timer**: Separates scheduling from execution. Timer triggers the service at defined intervals.

Create `~/.config/systemd/user/rclone-bisync.timer`:

```ini
[Unit]
Description=Run Rclone Bisync for Proton Drive
Requires=rclone-bisync.service

[Timer]
OnBootSec=2min
OnUnitActiveSec=30min
Persistent=true

[Install]
WantedBy=timers.target
```

**Timer settings**:
- `OnBootSec=2min`: Wait 2 minutes after boot before first sync (gives network time to connect)
- `OnUnitActiveSec=30min`: Run every 30 minutes after previous sync completes (balanced interval - not too aggressive)
- `Persistent=true`: If system was off, catch up on missed runs when it starts
- `WantedBy=timers.target`: Timer starts automatically when you log in

**Note**: The timer starts on login. The service itself will NOT run until the timer triggers it.

### 7. Enable and Start Timer

**What this does**: Activates the timer so syncing runs automatically.

```bash
systemctl --user daemon-reload       # Reload systemd to see new units
systemctl --user enable rclone-bisync.timer  # Start timer on login
systemctl --user start rclone-bisync.timer   # Start timer now
```

**Important**: After enabling, the timer will automatically start on future logins. The first sync will happen 2 minutes after you start the timer, then every 30 minutes thereafter.

### 8. Verify Setup

**What this does**: Confirms everything is working correctly.

Check timer status:
```bash
systemctl --user status rclone-bisync.timer
systemctl --user list-timers | grep rclone
```

**What to look for**: Timer should show "active (waiting)" and "Next run" timestamp.

View logs:
```bash
tail -f ~/.cache/rclone/bisync.log
```

**What to look for in logs**:
- ✓ `Bisync successful`: Sync completed without errors
- ✓ `Changes: ...`: Summary of files synced
- ⚠ `NOTICE: ...`: Warnings (usually safe)
- ✗ `ERROR: ...`: Problems that need attention
- ✗ `CRITICAL: Safety abort`: Too many deletes detected (>10 files)

Trigger manual sync to test immediately:
```bash
systemctl --user start rclone-bisync.service
```

Check if it worked:
```bash
journalctl --user -u rclone-bisync.service -n 50
```


---

## Troubleshooting

### Common Issues

#### 1. Authentication Failed / Wrong Password
**Symptom**: Logs show `401 Unauthorized` or `authentication failed`

**Solution**:
```bash
# Reconfigure rclone
rclone config reconnect protondrive:
# Or start fresh
rclone config
```

**Check**: Make sure 2FA is working and device is approved in Proton account settings.

---

#### 2. Too Many Deletes (Safety Abort)
**Symptom**: Logs show `CRITICAL: Safety abort: More than 10 deletes`

**What happened**: rclone detected >10 files would be deleted. This is a safety feature to prevent accidental data loss.

**Solution**:
1. **Investigate why**: Check both Proton Drive and local folder to see what changed
2. **If intentional** (you deleted a folder): Run manual resync
   ```bash
   rclone bisync protondrive:/ ~/Documents/Proton --resync -v
   ```
3. **If unintentional**: Restore files from Proton Drive trash (web interface)
4. **To change threshold**: Edit service file and change `--max-delete 10` to higher number (e.g., `50`)

**Note**: You cannot get a confirmation prompt - rclone always aborts. You must manually investigate and resync.

---

#### 3. Sync Conflicts
**Symptom**: Files named `file.txt.conflict1` appear

**What happened**: Same file was modified on both sides since last sync.

**Solution**: `conflict1` is the older version, keep whichever you need and delete the other.

---

#### 4. Timer Not Running
**Symptom**: `systemctl --user list-timers` doesn't show rclone timer

**Solution**:
```bash
systemctl --user daemon-reload
systemctl --user enable rclone-bisync.timer
systemctl --user start rclone-bisync.timer
```

**Check if systemd user session is enabled**:
```bash
loginctl enable-linger $USER
```

---

#### 5. Permission Denied / systemctl --user Fails
**Symptom**: `Failed to connect to bus` or `systemctl --user` command fails

**Solution**: Some systems don't support user systemd properly. You'll need to either:
- Use system-level systemd (not recommended, requires root)
- Use cron instead: `crontab -e` and add:
  ```
  */30 * * * * /usr/bin/rclone bisync protondrive:/ ~/Documents/Proton --create-empty-src-dirs --compare size,modtime --check-access --max-delete 10 --conflict-resolve newer --conflict-loser num --resilient --log-file ~/.cache/rclone/bisync.log --log-level INFO
  ```

---

#### 6. Network Errors / Connection Timeout
**Symptom**: Logs show `connection reset`, `timeout`, or `temporary failure`

**Solution**: The `--resilient` flag should retry automatically. If persistent:
```bash
# Check internet connection
ping proton.me

# Check rclone can reach Proton
rclone lsd protondrive:/

# If VPN/firewall: ensure rclone isn't blocked
```

---

#### 7. Duplicate Folders / Wrong Mount Point
**Symptom**: Files syncing to wrong location, or duplicate folder structures

**Check paths**:
```bash
# Verify remote path
rclone lsd protondrive:/

# Verify local path
ls -la ~/Documents/Proton
```

**Solution**: Edit service file, update paths, and reload:
```bash
nano ~/.config/systemd/user/rclone-bisync.service
systemctl --user daemon-reload
```

---

### View Logs
```bash
# Live log viewing
tail -f ~/.cache/rclone/bisync.log

# Systemd logs
journalctl --user -u rclone-bisync.service -f

# Last 100 lines
journalctl --user -u rclone-bisync.service -n 100
```

### Manual Sync
```bash
systemctl --user start rclone-bisync.service
```

### Stop Automation
```bash
systemctl --user stop rclone-bisync.timer
systemctl --user disable rclone-bisync.timer
```

---

## What Happens to Deleted Files?

**Short answer**: Deleted files go to **Proton Drive Trash** and can be restored for 30 days.

**How it works**:
- Delete locally → File deleted from Proton Drive → Moved to Proton Trash
- Delete on Proton Drive → File deleted locally → Linux trash (if using file manager)
- **Important**: Command-line `rm` bypasses trash - files are gone locally but recoverable from Proton Drive trash

**To recover**: Visit Proton Drive web interface → Trash → Restore

---

## Safety Features

- **`--max-delete 10`**: Aborts if >10 files would be deleted (prevents accidental mass deletion)
- **`--conflict-resolve newer`**: Keeps most recently modified file when both sides changed
- **`--conflict-loser num`**: Renames the older version (e.g., `file.conflict1.txt`)
- **`--check-access`**: Verifies RCLONE_TEST marker exists before syncing (prevents syncing to wrong location)
- **`--resilient`**: Retries on transient network errors

**Note**: These are conservative defaults. You can adjust `--max-delete` higher if you regularly work with large folders.

---

## Uninstalling

```bash
# Stop and disable timer
systemctl --user stop rclone-bisync.timer
systemctl --user disable rclone-bisync.timer

# Remove unit files
rm ~/.config/systemd/user/rclone-bisync.service
rm ~/.config/systemd/user/rclone-bisync.timer
systemctl --user daemon-reload

# Optional: Remove rclone config
rclone config delete protondrive

# Optional: Remove synced files
rm -rf ~/Documents/Proton
```

---

## Full Documentation & Automated Installer

For a complete automated solution with:
- ✓ One-command installation
- ✓ Interactive setup wizard
- ✓ Multi-distro support
- ✓ Validation scripts
- ✓ Comprehensive documentation

**Visit the GitHub repository:**  
👉 **https://github.com/leontocephaline/proton-drive-bisync**

⭐ **Star the project** if you find it useful!

---

## Contributing

Found an issue or have a suggestion? Please report it:
- **GitHub Issues**: https://github.com/leontocephaline/proton-drive-bisync/issues

---

## License

MIT License - See [LICENSE](https://github.com/leontocephaline/proton-drive-bisync/blob/main/LICENSE)
