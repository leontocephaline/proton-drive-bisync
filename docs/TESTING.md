# Testing Guide

This document describes how to test the Proton Drive bisync installer across multiple Linux distributions using distrobox.

## What We Test

### Automated Tests (No Credentials Required)
- **Script syntax**: Validate all bash scripts with `bash -n`
- **Help output**: Verify `--help` flags work
- **Systemd unit generation**: Render and validate unit files
- **Template placeholders**: Check config templates are valid
- **Documentation**: Ensure all docs exist

### Manual Tests (Require Proton Account)
- **rclone configuration**: `rclone config` with Proton Drive
- **Initial bisync**: First `--resync` operation
- **Sync operations**: Regular bisync runs
- **Conflict resolution**: Test file conflicts
- **Safety features**: Verify `--max-delete` protection

### Cannot Be Automated
- Proton Drive authentication (2FA, device approval)
- Real file synchronization
- Long-term reliability testing
- Network failure scenarios

## Prerequisites

- **distrobox** installed (`sudo apt install distrobox` on Debian/Ubuntu)
- **podman** or **docker** as container backend
- **git** and **bash**

## Quick Test

Run the automated test suite:

```bash
chmod +x test-distros.sh
./test-distros.sh
```

This will:
1. Create distrobox containers for each major distro family
2. Clone the gist inside each container
3. Install dependencies (git, curl, rclone, systemd)
4. Validate script syntax
5. Test help output
6. Report results

## Tested Distributions

- **Debian-like**: Ubuntu 24.04, Debian 12
- **Fedora-like**: Fedora 40
- **Arch-like**: Arch Linux (rolling)
- **Alpine-like**: Alpine Linux (latest)

## Manual Testing

To test a specific distro manually:

```bash
# Create container
distrobox create --name test-ubuntu --image ubuntu:24.04 --yes

# Enter container
distrobox enter test-ubuntu

# Inside container: install dependencies
sudo apt update && sudo apt install -y git curl

# Clone and test
git clone https://gist.github.com/526cc5cafefdefd264c8422deb897e39.git proton-drive-bisync
cd proton-drive-bisync
chmod +x install.sh uninstall.sh scripts/*.sh

# Run installer (will prompt for rclone install if needed)
./install.sh

# Verify
scripts/validate-setup.sh

# Exit and cleanup
exit
distrobox rm -f test-ubuntu
```

## Test Results

Results are saved to `test-results/` directory with one log file per distro.

## Known Limitations

- **systemd in containers**: Some containers may not have systemd running. The installer will detect this and warn accordingly.
- **Alpine Linux**: Uses OpenRC instead of systemd; automation won't work but scripts should validate syntactically.
- **Interactive prompts**: Automated tests skip interactive steps (rclone config, initial sync).

## CI/CD Integration

For GitHub Actions or similar:

```yaml
name: Test Distros
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install distrobox
        run: sudo apt-get install -y distrobox podman
      - name: Run tests
        run: ./test-distros.sh
```

## Reporting Issues

If a distro fails testing:
1. Check `test-results/<distro>.log` for errors
2. Reproduce manually in distrobox
3. Open an issue with distro version and error output
