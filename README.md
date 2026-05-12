# Blockme

A macOS website blocker that is **structurally fail-safe**: blocked domains stay blocked, but if anything in the blocker ever fails, your internet keeps working. No "all sites die" failure mode.

Built to be:

- local-only (no cloud, no account, no third-party servers)
- reproducible from source on any Mac
- usable without a paid Apple Developer Team
- persistent across reboots, sleep/wake, and Wi-Fi changes
- append-only by design (the only way to unblock a domain is to uninstall everything)

## How it works in one paragraph

Blockme uses macOS's own DNS facilities to make blocked domains (and all of their subdomains) fail to resolve — `dig`, `curl`, Safari, and most apps will see them as "host does not exist." **Every domain you do NOT block uses your system's normal DNS path, completely untouched.** That structural separation is the safety guarantee: if the blocker process crashes for any reason, only blocked-domain lookups are affected. Your regular browsing keeps working. Safari with iCloud Private Relay is covered automatically.

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
4. Installs the background daemon and the `blockme` command-line tool, and activates any domains you previously added
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
blocked_domains: 0
...
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

You should see no result. In a browser, `https://example.com` will fail to load.

Try a non-blocked site in the same browser — it should load instantly. That's the design.

## The bail-out

If anything ever feels wrong, run:

```bash
sudo blockme uninstall
```

This stops the daemon, removes everything Blockme installed, and deactivates blocking. Blockme **never touches your global DNS settings, `/etc/pf.conf`, or any system-wide proxy**, so there is no configuration to "restore" — your network returns to exactly its pre-install state, instantly.

## Important caveat about Chrome

Chrome has a feature called "Use secure DNS" (DNS-over-HTTPS) that bypasses the system resolver entirely. If you use Chrome and want blocking to work there, turn it off:

1. Open `chrome://settings/security` in Chrome
2. Scroll to "Advanced"
3. Turn off "Use secure DNS"

Safari is fully covered out of the box.

Firefox: it also has DoH; same fix applies in `about:preferences#privacy` → "Enable DNS over HTTPS" off.

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

## Project layout

```
.
├── Package.swift, install.sh, README.md, LICENSE
├── Resources/      ← icon source
├── Sources/        ← Swift library, CLI, and SwiftUI GUI
├── Tests/          ← unit tests
└── Scripts/        ← build + test helpers
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
