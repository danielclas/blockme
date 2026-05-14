# Blockme

A macOS website blocker. Append-only by design. Structurally fail-safe: only blocked domains are ever affected — non-blocked traffic uses the system's normal DNS path, untouched. Runs without a paid Apple Developer Team.

## Install

```bash
xcode-select --install        # one-time, if Command Line Tools are not installed
git clone https://github.com/danielclas/blockme.git
cd blockme
./install.sh
```

The installer builds `Blockme.app`, installs the background daemon and the `blockme` CLI, and prompts once for an admin password.

## Usage

```bash
sudo blockme add instagram.com
sudo blockme add x.com youtube.com
blockme list
blockme status
```

Adding a domain blocks all of its subdomains automatically. The GUI at `~/Applications/Blockme.app` exposes the same add/list functionality.

## Browser caveats

Chrome and Firefox can be configured with DNS-over-HTTPS, which bypasses the system resolver entirely. To ensure blocking applies in those browsers, disable DoH:

- Chrome: `chrome://settings/security` → turn off "Use secure DNS"
- Firefox: `about:preferences#privacy` → uncheck "Enable DNS over HTTPS"

Safari is fully covered without configuration.

## Requirements

- macOS 13 (Ventura) or later
- Xcode Command Line Tools
- Admin password (for install and `blockme add`)

## Project layout

```
.
├── Package.swift           Swift Package Manager manifest
├── install.sh              builds and installs
├── Resources/              icon source
├── Sources/                Swift library, CLI, and SwiftUI GUI
├── Tests/                  unit tests
└── Scripts/                build and test helpers
```

## Development

```bash
swift build                       # build all targets
swift test                        # run unit tests
./Scripts/sandbox-harness.sh      # integration test against a fake root prefix
```

## License

See `LICENSE`.
