# Blockme

A macOS website blocker that is **structurally fail-safe**: blocked domains stay blocked, but if anything in the blocker ever fails, your internet keeps working. No "all sites die" failure mode.

Built to be:

- local-only (no cloud, no account, no third-party servers)
- reproducible from source on any Mac
- usable without a paid Apple Developer Team
- persistent across reboots, sleep/wake, and Wi-Fi changes
- append-only by design (the only way to unblock a domain is to uninstall everything)

## How it works in one paragraph

For each domain you block, Blockme writes a tiny file at `/etc/resolver/<domain>` that tells macOS: "for this specific domain (and its subdomains), ask the local NXDOMAIN stub on `127.0.0.1:5454`." The stub answers "does not exist" for every query it receives. **Every domain you do NOT block uses your system's normal DNS path, completely untouched.** That's the safety guarantee: if the stub crashes or the daemon dies, only blocked-domain lookups are affected. Your regular browsing is structurally insulated from any failure in the blocker.

Blockme also writes `/etc/resolver/mask.icloud.com` (Apple's documented way to disable iCloud Private Relay for blocked domains, so Safari falls back to the system resolver and the block applies there too) and keeps a managed section in `/etc/hosts` as belt-and-suspenders.

## Install (foolproof, copy/paste in order)

### Step 1 — install Apple's command line tools

If you've never used Xcode before, run this once. It's a ~1 GB download from Apple.

```bash
xcode-select --install
```

A system dialog will appear. Click "Install." When it finishes, continue.

### Step 2 — clone this repo

```bash
git clone https://github.com/danielclas/blockme.git
cd blockme
```

### Step 3 — run the installer

```bash
./install.sh
```

What this does:

1. Builds `Blockme.app` from source (~15 seconds)
2. Copies it to `~/Applications/Blockme.app`
3. **Prompts you for your macOS admin password** (one time, via a normal macOS authentication dialog)
4. Installs the background daemon, the `blockme` command-line tool, and the per-domain resolver files
5. Opens `Blockme.app`

When it's done you'll see:

```
Install complete.
You can now:
  - open Blockme.app from ~/Applications
  - use 'blockme status' in Terminal
  - use 'sudo blockme add instagram.com' to add a blocked domain from the CLI
```

### Step 4 — verify everything works

Open a new Terminal window and run:

```bash
blockme status
```

You should see something like:

```
installed: yes
stub_listen: 127.0.0.1:5454
private_relay_block: yes
blocked_domains: 0
```

If `installed: yes`, you're done.

## Day-to-day usage

### From the GUI

Open `Blockme.app` from `~/Applications` or your Dock. Click "Add domain," type the domain, click confirm. That's it.

The main view always shows the current blocklist. There is no "remove" button — that's intentional.

### From the CLI

```bash
sudo blockme add instagram.com       # block a domain (and its subdomains)
sudo blockme add x.com youtube.com   # multiple at once
blockme list                          # show what's blocked (needs sudo to see full list)
blockme status                        # show daemon health
sudo blockme uninstall               # remove everything cleanly
```

Adding a domain blocks **all of its subdomains automatically**, e.g. `sudo blockme add instagram.com` blocks `instagram.com`, `www.instagram.com`, `api.instagram.com`, and so on.

## How to verify it's actually working

After adding a block, run:

```bash
sudo blockme add example.com
dscacheutil -q host -a name example.com
```

You should see either no result, or the address `127.0.0.1`. In a browser, `https://example.com` will fail to load.

Try a non-blocked site in the same browser — it should load instantly. That's the design.

## The bail-out

If anything ever feels wrong, run:

```bash
sudo blockme uninstall
```

This:

- stops the daemon
- removes every `/etc/resolver/<domain>` file Blockme created (it never touches resolver files it didn't create)
- removes the managed section from `/etc/hosts`
- deletes the binary

Because Blockme **never touches global DNS settings, never edits `/etc/pf.conf`, and never installs system-wide proxies**, there's nothing to "restore." Your network configuration returns to exactly what it was before install, instantly.

## Important caveat about Chrome

Chrome has a feature called "Use secure DNS" (DNS-over-HTTPS) that bypasses the system resolver entirely. If you use Chrome and want blocking to work there, turn it off:

1. Open `chrome://settings/security` in Chrome
2. Scroll to "Advanced"
3. Turn off "Use secure DNS"

Safari is fully covered out of the box.

Firefox: it also has DoH; same fix applies in `about:preferences#privacy` → "Enable DNS over HTTPS" off.

## What gets installed where

| Path | What it is |
|---|---|
| `~/Applications/Blockme.app` | the GUI |
| `/usr/local/libexec/steadfast/steadfast` | the actual binary the daemon runs |
| `/usr/local/bin/blockme` | symlink so you can type `blockme` in Terminal |
| `/usr/local/bin/steadfast` | alias of the same binary |
| `/Library/LaunchDaemons/com.steadfast.daemon.plist` | tells `launchd` to keep the daemon running |
| `/etc/resolver/<domain>` | one file per blocked domain — this is where the actual blocking happens |
| `/etc/hosts` (managed section) | belt-and-suspenders fallback |
| `/Library/Application Support/Steadfast/` | the blocklist (`blocklist.json`) and daemon state |
| `/Library/Application Support/Blockme/status.json` | what the GUI reads for status |
| `/Library/Logs/Steadfast/daemon.log` | daemon stderr/stdout for debugging |

`sudo blockme uninstall` removes every item in that table.

## Sharing this with a friend

Don't send them a prebuilt `.app`. Send them this repo URL:

```
https://github.com/danielclas/blockme.git
```

They run the same three steps above. The build is reproducible on every Mac.

## System requirements

- macOS 13 (Ventura) or later
- Apple Silicon or Intel (both work)
- Xcode Command Line Tools (Step 1 above)
- Admin password (just for install/add/uninstall)

## Project structure (for the curious)

```
Sources/
├── SteadfastCore/                   ← all the logic, as a Swift library
│   ├── ResolverDirectoryManager.swift   ← writes /etc/resolver/<domain> files
│   ├── NXDomainStub.swift               ← the 1-job UDP server (always NXDOMAIN)
│   ├── HostsManager.swift               ← /etc/hosts fallback
│   ├── BlocklistStore.swift             ← reads/writes the blocklist JSON
│   ├── LaunchdManager.swift             ← install / uninstall / launchd
│   ├── CLI.swift                        ← every subcommand
│   └── ...
├── steadfast/                       ← thin CLI entrypoint
└── blockme/                         ← the SwiftUI GUI app

Tests/
└── SteadfastCoreTests/              ← unit tests (12 of them, all green)

Scripts/
├── sandbox-harness.sh               ← integration test against a fake root prefix
├── install-blockme-app.sh           ← app-only install (used by install.sh)
└── package-blockme-app.sh           ← builds Blockme.app
```

If you want to run the test suite:

```bash
swift test
```

If you want to run the integration test that proves install/sync/stub/uninstall work end-to-end without touching real system files:

```bash
./Scripts/sandbox-harness.sh
```

## Why not NetworkExtension / Little Snitch / Freedom

- **NetworkExtension** is Apple's intended path for real DNS/traffic filtering, but it requires a paid Apple Developer Team and provisioning that's not available on Personal Teams. Blockme is built so you don't need to pay Apple anything.
- **Little Snitch** is a great product but it costs money and isn't open source.
- **Freedom** is app-based, so closing the app stops the blocking; the design here is daemon-based so it persists.

The tradeoff is that Chrome+DoH can route around Blockme (see caveat above). For Safari and most apps, Blockme is fully effective.

## License

Personal/private use. No warranty. If you find a bug, open an issue.
