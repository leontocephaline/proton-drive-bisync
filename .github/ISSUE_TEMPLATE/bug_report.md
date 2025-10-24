---
name: Bug report
about: Report an issue with the installer or sync
title: '[BUG] '
labels: bug
assignees: ''
---

**Describe the bug**
A clear and concise description of what the bug is.

**Environment**
- **Distro**: [e.g., Ubuntu 24.04]
- **rclone version**: [run `rclone version`]
- **systemd version**: [run `systemctl --version`]
- **Installation method**: [automated installer / manual setup]

**Steps to reproduce**
1. Run `./install.sh`
2. ...
3. See error

**Expected behavior**
What you expected to happen.

**Actual behavior**
What actually happened.

**Logs**
```
# Paste relevant logs from ~/.cache/rclone/bisync.log
# Or from journalctl --user -u rclone-bisync.service -n 50
```

**Additional context**
Add any other context about the problem here.
