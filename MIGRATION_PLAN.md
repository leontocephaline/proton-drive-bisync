# Migration Plan: Gist → GitHub Repo

## Current State
- Comprehensive project living in a gist
- 12+ files across multiple directories
- Full documentation suite
- Testing infrastructure

## Target State
- **Full GitHub repo**: `github.com/leontocephaline/proton-drive-bisync`
- **Simplified gist**: Manual setup guide + link to repo

---

## Step 1: Create GitHub Repository

```bash
# On GitHub website
1. Go to github.com/new
2. Repository name: proton-drive-bisync
3. Description: "Automated bidirectional sync for Proton Drive on Linux using rclone and systemd"
4. Public repository
5. Do NOT initialize with README (we'll push ours)
6. Create repository
```

## Step 2: Initialize Local Repo

```bash
cd /home/ps/Documents/Proton/ProtonDriveSetup/proton-drive-bisync

# Initialize git
git init
git branch -M main

# Create .gitignore
cat > .gitignore << 'EOF'
# Test results
test-results/
*.log

# Temporary files
*.tmp
.DS_Store
*~

# Editor files
.vscode/
.idea/
*.swp
EOF

# Add all files
git add .
git commit -m "Initial commit: Proton Drive bisync automation

- Complete installer with systemd automation
- Helper scripts for setup and validation
- Comprehensive documentation
- Testing infrastructure for multiple distros
- Flatpak packaging documentation"

# Add remote and push
git remote add origin git@github.com:leontocephaline/proton-drive-bisync.git
git push -u origin main
```

## Step 3: Enhance Repository

### Add GitHub-specific Files

**`.github/ISSUE_TEMPLATE/bug_report.md`:**
```markdown
---
name: Bug report
about: Report an issue with the installer or sync
---

**Describe the bug**
A clear description of what's wrong.

**Environment**
- Distro: [e.g., Ubuntu 24.04]
- rclone version: [run `rclone version`]
- systemd version: [run `systemctl --version`]

**Steps to reproduce**
1. Run `./install.sh`
2. ...

**Expected behavior**
What should happen?

**Actual behavior**
What actually happens?

**Logs**
```
# Paste relevant logs from ~/.cache/rclone/bisync.log
```
```

**`.github/ISSUE_TEMPLATE/feature_request.md`:**
```markdown
---
name: Feature request
about: Suggest an enhancement
---

**Feature description**
What would you like to see added?

**Use case**
Why would this be useful?

**Alternatives considered**
Other ways you've thought about solving this.
```

**`CONTRIBUTING.md`:**
```markdown
# Contributing

Thanks for your interest in contributing!

## Reporting Issues
- Check existing issues first
- Include distro, rclone version, and logs
- Use issue templates

## Pull Requests
1. Fork the repository
2. Create a feature branch
3. Test on at least 2 distros
4. Run `./test-syntax.sh` to validate
5. Update documentation if needed
6. Submit PR with clear description

## Testing
Run the test suite:
```bash
./test-syntax.sh
./test-distros.sh  # Optional, requires distrobox
```

## Code Style
- Use `set -euo pipefail` in all bash scripts
- Add comments for complex logic
- Follow existing naming conventions
```

### Update README for GitHub

**Changes to make:**
```markdown
# Add badges at top:
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/leontocephaline/proton-drive-bisync)](https://github.com/leontocephaline/proton-drive-bisync/stargazers)

# Update clone command:
```bash
git clone https://github.com/leontocephaline/proton-drive-bisync.git
cd proton-drive-bisync
chmod +x install.sh uninstall.sh scripts/*.sh
./install.sh
```

# Add sections:
## Contributing
See [CONTRIBUTING.md](CONTRIBUTING.md)

## Support
- **Issues**: [GitHub Issues](https://github.com/leontocephaline/proton-drive-bisync/issues)
- **Discussions**: [GitHub Discussions](https://github.com/leontocephaline/proton-drive-bisync/discussions)

## Star History
If you find this useful, consider starring the project!
```

## Step 4: Create First Release

```bash
# Tag version 1.0.0
git tag -a v1.0.0 -m "Initial release

Features:
- Automated installer for Proton Drive bisync
- Systemd timer automation
- Cross-distro support (Debian, Fedora, Arch, Alpine)
- Comprehensive documentation
- Testing infrastructure"

git push origin v1.0.0
```

On GitHub:
1. Go to Releases → "Draft a new release"
2. Choose tag `v1.0.0`
3. Title: "v1.0.0 - Initial Release"
4. Description: Copy from tag message
5. Publish release

## Step 5: Update Gist to Simple Guide

Replace gist content with:

**`proton-drive-manual-setup.md`** (single file):
```markdown
# Proton Drive Sync - Manual Setup Guide

Quick reference for manually configuring Proton Drive bidirectional sync on Linux.

> **Want an automated installer?**  
> 👉 **https://github.com/leontocephaline/proton-drive-bisync**  
> Complete solution with one-command installation, systemd automation, and multi-distro support.

---

## Manual Setup (Advanced Users)

### 1. Install rclone (1.71.0+)
```bash
curl https://rclone.org/install.sh | sudo bash
```

### 2. Configure Proton Drive
```bash
rclone config
# Select: "n" for new remote
# Name: protondrive
# Type: Choose "Proton Drive (protondrive)"
# Follow authentication steps (2FA, device approval)
```

### 3. Initial Sync
```bash
mkdir -p ~/Documents/Proton
rclone bisync protondrive:/ ~/Documents/Proton \
  --resync \
  --create-empty-src-dirs \
  --compare size,modtime
```

### 4. Create Systemd Service
`~/.config/systemd/user/rclone-bisync.service`:
```ini
[Unit]
Description=Rclone Bisync for Proton Drive
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/rclone bisync protondrive:/ %h/Documents/Proton \
  --create-empty-src-dirs \
  --compare size,modtime \
  --max-delete 10 \
  --conflict-resolve newer \
  --conflict-loser num \
  --log-file %h/.cache/rclone/bisync.log

[Install]
WantedBy=default.target
```

### 5. Create Timer
`~/.config/systemd/user/rclone-bisync.timer`:
```ini
[Unit]
Description=Run Rclone Bisync every 30 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=30min
Persistent=true

[Install]
WantedBy=timers.target
```

### 6. Enable and Start
```bash
systemctl --user daemon-reload
systemctl --user enable --now rclone-bisync.timer
```

### 7. Verify
```bash
systemctl --user status rclone-bisync.timer
systemctl --user list-timers
```

---

## Troubleshooting

- **Logs**: `tail -f ~/.cache/rclone/bisync.log`
- **Manual sync**: `systemctl --user start rclone-bisync.service`
- **Stop automation**: `systemctl --user stop rclone-bisync.timer`

## Full Documentation

For advanced features, testing, and troubleshooting:
👉 **https://github.com/leontocephaline/proton-drive-bisync**
```

## Step 6: Promote Repository

**Update Reddit Post:**
```markdown
[Update] I've moved the project to a full GitHub repository!

**GitHub**: https://github.com/leontocephaline/proton-drive-bisync  
**Quick Guide**: https://gist.github.com/leontocephaline/526cc5cafefdefd264c8422deb897e39

The repo includes:
- One-command automated installer
- Full documentation
- Multi-distro testing
- Issue tracking for bugs/features

⭐ Star the project if you find it useful!
```

---

## Benefits of This Approach

### Repository Benefits
✓ **Issue tracking** for bugs and feature requests  
✓ **Pull requests** from contributors  
✓ **GitHub Actions** for automated testing  
✓ **Release tags** for version management  
✓ **Better analytics** (stars, forks, traffic)  
✓ **GitHub Discussions** for community Q&A  
✓ **More discoverable** in GitHub search  

### Gist Benefits
✓ **Simple reference** for manual setup  
✓ **No git required** for quick copy-paste  
✓ **Acts as funnel** to full project  
✓ **Lower barrier** for learning how it works  

---

## Timeline

**Today:**
1. Create GitHub repository (15 min)
2. Push initial commit (5 min)
3. Add GitHub-specific files (30 min)
4. Create first release (10 min)

**This Week:**
1. Update gist with simplified guide
2. Post to Reddit/forums with repo link
3. Enable GitHub Discussions
4. Watch for issues/stars

**Next Month:**
1. Address any issues
2. Consider additional features based on feedback
3. If 100+ stars → start Flatpak work
