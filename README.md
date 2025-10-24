# Proton Drive Bisync for Linux

Automated, bidirectional file synchronization between your Linux system and Proton Drive using `rclone bisync` and systemd user services.

## Features

- **Two-way sync**: Changes sync in both directions automatically
- **Safe defaults**: Protection against accidental mass deletion
- **Systemd automation**: Runs every 30 minutes in the background
- **Minimal dependencies**: Just bash and rclone
- **Health tooling**: Built-in validation and monitoring scripts
- **Production-ready logging**: Track sync operations and troubleshoot issues

## Requirements

- **Linux with systemd user sessions enabled**
- **Network access to install dependencies** (installer fetches `rclone` if missing)
- **Proton account** (free tier works)

## Quick Start

```bash
# Clone the repository
git clone https://github.com/leontocephaline/proton-drive-bisync.git
cd proton-drive-bisync

# Make scripts executable
chmod +x install.sh uninstall.sh scripts/*.sh

# Run installer
./install.sh

# Verify setup
scripts/validate-setup.sh
```

## Repository Layout

- **`install.sh`** – End-to-end automated installer
- **`uninstall.sh`** – Removes automation cleanly
- **`config/`** – Systemd unit templates
- **`scripts/`** – Helper utilities (`setup-proton-drive.sh`, `validate-setup.sh`, `health-check.sh`)
- **`docs/`** – Deep-dive guides

## Documentation

- **[Installation Guide](docs/INSTALLATION.md)**
- **[Configuration Options](docs/CONFIGURATION.md)**
- **[Troubleshooting](docs/TROUBLESHOOTING.md)**
- **[Testing Guide](docs/TESTING.md)**

## Manual Setup

Prefer to set it up yourself? See the [**manual setup guide**](https://gist.github.com/leontocephaline/526cc5cafefdefd264c8422deb897e39).

## How It Works

```
[Local Filesystem] ⇆ rclone bisync ⇆ [Proton Drive]
          ▲                │
          │         systemd timers
          └────── logging + safety
```

1. **Install rclone** and configure Proton Drive remote
2. **Create systemd service** that runs `rclone bisync` with safety flags
3. **Create systemd timer** to trigger sync every 30 minutes
4. **Monitor via logs** and systemd status commands

## Safety Features

- **`--max-delete 10`**: Aborts if >10 files would be deleted
- **`--conflict-resolve newer`**: Keeps most recently modified file
- **`--conflict-loser num`**: Renames conflicting files with suffix
- **`--check-access`**: Verifies marker file exists before syncing
- **`--resilient`**: Retries on transient errors

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

- **Report bugs**: [GitHub Issues](https://github.com/leontocephaline/proton-drive-bisync/issues)
- **Suggest features**: [GitHub Issues](https://github.com/leontocephaline/proton-drive-bisync/issues)
- **Submit PRs**: Fork, create feature branch, test, and submit

## Support

- **Issues**: [GitHub Issues](https://github.com/leontocephaline/proton-drive-bisync/issues)
- **Discussions**: [GitHub Discussions](https://github.com/leontocephaline/proton-drive-bisync/discussions)

## License

MIT License - See [LICENSE](LICENSE)

---

⭐ **Star this project** if you find it useful!
