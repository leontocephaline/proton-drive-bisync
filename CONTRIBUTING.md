# Contributing to Proton Drive Bisync

Thank you for your interest in contributing! This project welcomes contributions from the community.

## How to Contribute

### Reporting Issues

- **Search first**: Check if your issue already exists
- **Use templates**: Fill out the bug report or feature request template
- **Be specific**: Include your distro, rclone version, and logs
- **One issue per report**: Don't combine multiple bugs/features

### Submitting Pull Requests

1. **Fork** the repository
2. **Create a branch**: `git checkout -b feature/your-feature-name`
3. **Make changes**: Follow the coding style below
4. **Test**: Run `./test-syntax.sh` at minimum
5. **Test on multiple distros** if possible (use `./test-distros.sh`)
6. **Update docs**: If you change behavior, update relevant docs
7. **Commit**: Write clear commit messages
8. **Push**: `git push origin feature/your-feature-name`
9. **Create PR**: Submit via GitHub with clear description

### Testing

Run the syntax validator before submitting:
```bash
chmod +x test-syntax.sh
./test-syntax.sh
```

For comprehensive testing (optional, requires distrobox):
```bash
chmod +x test-distros.sh
./test-distros.sh
```

## Code Style

### Bash Scripts

- Use `set -euo pipefail` at the top of scripts
- Use `"${variable}"` quotes for all variable expansions
- Add comments for complex logic
- Use functions for reusable code
- Follow existing naming conventions (snake_case for functions/variables)

### Documentation

- Keep markdown files clear and concise
- Use code blocks with language specification
- Update relevant docs when changing behavior
- Check for broken links

## Project Structure

```
proton-drive-bisync/
├── install.sh              # Main installer
├── uninstall.sh            # Removal script
├── config/                 # Systemd templates
├── scripts/                # Helper utilities
├── docs/                   # Documentation
└── test-*.sh               # Testing scripts
```

## Questions?

- **Issues**: For bugs and features
- **Discussions**: For questions and general discussion

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
