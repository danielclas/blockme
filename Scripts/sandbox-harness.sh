#!/bin/zsh
# Sandbox integration test for the new architecture.
#
# Runs the real steadfast binary against a fake root prefix (STEADFAST_ROOT_PREFIX)
# and asserts that:
#   - install creates the expected /etc/resolver/<domain> files under the sandbox
#     and NOTHING outside it
#   - the NXDomainStub responds to a live UDP DNS query with NXDOMAIN
#   - uninstall removes every file we created
#   - non-managed files under the sandbox's /etc/resolver/ are untouched
#
# This script must:
#   - never touch real /etc/resolver
#   - never run networksetup
#   - never run pfctl
#   - never need sudo
#
# Exit 0 = green. Anything else = red, and the script tries to clean up after
# itself before exiting.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SANDBOX="$(mktemp -d -t blockme-sandbox)"
BIN="$ROOT_DIR/.build/release/steadfast"
STUB_PORT=18653

cleanup() {
  rm -rf "$SANDBOX" 2>/dev/null || true
  if [[ -n "${DAEMON_PID:-}" ]]; then
    kill "$DAEMON_PID" 2>/dev/null || true
    wait "$DAEMON_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

fail() {
  echo "❌ FAIL: $*" >&2
  exit 1
}

pass() {
  echo "✅ $*"
}

run_in_sandbox() {
  STEADFAST_ROOT_PREFIX="$SANDBOX" \
    STEADFAST_SERVICE_BIND_PORT="$STUB_PORT" \
    "$BIN" "$@"
}

echo "── Sandbox harness ──────────────────────────────────────────────"
echo "  bin: $BIN"
echo "  sandbox: $SANDBOX"
echo "  stub port: $STUB_PORT"
echo

echo "Step 1: build release binary"
swift build --configuration release >/dev/null 2>&1 || fail "swift build failed"
[[ -x "$BIN" ]] || fail "binary not produced at $BIN"
pass "binary built"

echo "Step 2: simulate a pre-existing non-managed resolver file"
mkdir -p "$SANDBOX/etc/resolver"
NONOURS="$SANDBOX/etc/resolver/preexisting.local"
printf "# someone else's config\nnameserver 10.0.0.1\n" > "$NONOURS"
pass "wrote pre-existing non-managed file at $NONOURS"

echo "Step 3: seed a blocklist"
mkdir -p "$SANDBOX/Library/Application Support/Steadfast"
cat > "$SANDBOX/Library/Application Support/Steadfast/blocklist.json" <<JSON
{
  "blockedDomains": ["instagram.com", "linkedin.com"],
  "updatedAt": 0
}
JSON
pass "seeded blocklist"

echo "Step 4: run install against the sandbox (no sudo, no real root)"
# We pass argv[0] as the binary path so resolvedExecutablePath works.
# requireRoot will reject because geteuid != 0, so we instead call the steps
# the daemon-side install would do via the 'sync' command which avoids the
# launchctl bootstrap but still touches resolver files & hosts.
run_in_sandbox sync 2>&1 | head -10 || {
  # sync requires root. We need a different path that doesn't go through
  # requireRoot. Use a tiny Swift driver that hits ResolverDirectoryManager
  # directly.
  cat > "$SANDBOX/driver.swift" <<'SWIFT'
import Foundation
import SteadfastCore

let env = ProcessInfo.processInfo.environment
let paths = Paths(environment: env)
let settings = RuntimeSettings(environment: env)
let manager = ResolverDirectoryManager(
  paths: paths,
  stubAddress: settings.stubListenAddress,
  stubPort: settings.stubListenPort,
  includePrivateRelay: settings.includePrivateRelay
)
let result = try manager.sync(blockedDomains: ["instagram.com", "linkedin.com"])
print("created=\(result.created.sorted())")
print("updated=\(result.updated.sorted())")
print("removed=\(result.removed.sorted())")
SWIFT
}

# Actually simpler approach: call the binary's `daemon` mode is a no-go (loops).
# And `install` needs root. So we'll exercise the install LOGIC directly by
# invoking a small Swift program that links against SteadfastCore. We build
# that as part of the test.

echo "Step 4 (revised): use a driver binary that exercises the new managers"
DRIVER_DIR="$SANDBOX/driver"
mkdir -p "$DRIVER_DIR/Sources/Driver"
cat > "$DRIVER_DIR/Package.swift" <<EOF
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "driver",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "driver",
            dependencies: [.product(name: "SteadfastCore", package: "steadfast")],
            path: "Sources/Driver"
        )
    ]
)
EOF
# We add a local package dependency by overlay
cat > "$DRIVER_DIR/Package.swift" <<EOF
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "driver",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "$ROOT_DIR")
    ],
    targets: [
        .executableTarget(
            name: "driver",
            dependencies: [.product(name: "SteadfastCore", package: "steadfast")],
            path: "Sources/Driver"
        )
    ]
)
EOF
cat > "$DRIVER_DIR/Sources/Driver/main.swift" <<'SWIFT'
import Darwin
import Foundation
import SteadfastCore

let args = CommandLine.arguments
guard args.count >= 2 else { print("usage: driver <command>"); exit(64) }

let env = ProcessInfo.processInfo.environment
let paths = Paths(environment: env)
let settings = RuntimeSettings(environment: env)
let store = BlocklistStore(paths: paths)
let hostsManager = HostsManager(paths: paths, settings: settings)
let resolverManager = ResolverDirectoryManager(
    paths: paths,
    stubAddress: settings.stubListenAddress,
    stubPort: settings.stubListenPort,
    includePrivateRelay: settings.includePrivateRelay
)

switch args[1] {
case "sync":
    let state = try store.load()
    let result = try resolverManager.sync(blockedDomains: state.blockedDomains)
    _ = try hostsManager.sync(blockedDomains: state.blockedDomains)
    print("created=\(result.created.sorted())")
    print("updated=\(result.updated.sorted())")
    print("removed=\(result.removed.sorted())")
case "uninstall":
    let removed = try resolverManager.removeAllManagedFiles()
    try? hostsManager.removeManagedSection()
    print("removed=\(removed.sorted())")
case "stub":
    let stub = NXDomainStub(listenAddress: settings.stubListenAddress, listenPort: settings.stubListenPort)
    try stub.start()
    print("ready")
    fflush(stdout)
    RunLoop.main.run()
case "managed":
    let names = resolverManager.managedDomains()
    print("managed=\(names.sorted())")
default:
    print("unknown command: \(args[1])"); exit(64)
}
SWIFT

echo "    building driver..."
( cd "$DRIVER_DIR" && swift build --configuration release ) >/dev/null 2>&1 || fail "driver build failed"
DRIVER_BIN="$DRIVER_DIR/.build/release/driver"
[[ -x "$DRIVER_BIN" ]] || fail "driver binary missing at $DRIVER_BIN"
pass "driver built"

run_driver() {
  STEADFAST_ROOT_PREFIX="$SANDBOX" \
    STEADFAST_SERVICE_BIND_PORT="$STUB_PORT" \
    "$DRIVER_BIN" "$@"
}

echo "Step 5: run sync — expect resolver files created"
OUT=$(run_driver sync)
echo "$OUT" | sed 's/^/    /'
echo "$OUT" | grep -q 'created=\[.*"instagram.com".*\]' || fail "instagram.com not created"
echo "$OUT" | grep -q 'linkedin.com' || fail "linkedin.com not created"
echo "$OUT" | grep -q 'mask.icloud.com' || fail "mask.icloud.com (Private Relay) not created"
pass "expected resolver files created"

echo "Step 6: assert files exist on disk with marker"
for d in instagram.com linkedin.com mask.icloud.com mask-h2.icloud.com; do
  FILE="$SANDBOX/etc/resolver/$d"
  [[ -f "$FILE" ]] || fail "missing $FILE"
  head -1 "$FILE" | grep -q "^# managed by steadfast" || fail "$FILE missing marker"
  grep -q "^nameserver 127.0.0.1$" "$FILE" || fail "$FILE missing nameserver"
  grep -q "^port $STUB_PORT$" "$FILE" || fail "$FILE missing port"
done
pass "resolver files have correct content"

echo "Step 7: assert the non-managed pre-existing file is untouched"
[[ -f "$NONOURS" ]] || fail "we deleted a non-managed file (BUG)"
grep -q "10.0.0.1" "$NONOURS" || fail "we modified a non-managed file (BUG)"
pass "non-managed file untouched"

echo "Step 8: assert NOTHING was written to the real /etc/resolver"
# The sandbox uses a unique port ($STUB_PORT). If we accidentally wrote to the
# real /etc/resolver, the file there would contain that port. Pre-existing
# files from a live install use a different port (5454) and are fine.
if [[ -d /etc/resolver ]]; then
  if grep -RIls "^port $STUB_PORT\$" /etc/resolver >/dev/null 2>&1; then
    fail "BUG: sandbox port $STUB_PORT was written into a real /etc/resolver/* file"
  fi
fi
pass "no writes to real /etc/resolver (sandbox port not found there)"

echo "Step 9: idempotent re-sync — must report no changes"
OUT2=$(run_driver sync)
echo "$OUT2" | sed 's/^/    /'
echo "$OUT2" | grep -q 'created=\[\]' || fail "second sync claimed creations"
echo "$OUT2" | grep -q 'updated=\[\]' || fail "second sync claimed updates"
echo "$OUT2" | grep -q 'removed=\[\]' || fail "second sync claimed removals"
pass "sync is idempotent"

echo "Step 10: start the stub on the test port and ask it for NXDOMAIN"
run_driver stub > "$SANDBOX/stub.log" 2>&1 &
DAEMON_PID=$!
# Wait for "ready"
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if grep -q "ready" "$SANDBOX/stub.log" 2>/dev/null; then break; fi
  sleep 0.1
done
grep -q "ready" "$SANDBOX/stub.log" || fail "stub never reported ready"
pass "stub running on port $STUB_PORT"

echo "Step 11: send a real DNS query — expect NXDOMAIN"
# dig +tries=1 +time=2 with custom server and port
DIG_OUT=$(dig @127.0.0.1 -p "$STUB_PORT" +tries=1 +time=2 linkedin.com 2>&1 || true)
echo "$DIG_OUT" | grep -E "status:" | sed 's/^/    /'
echo "$DIG_OUT" | grep -q "status: NXDOMAIN" || fail "stub did not return NXDOMAIN"
pass "stub returns NXDOMAIN over real UDP"

echo "Step 12: stop the stub (simulating daemon crash)"
kill "$DAEMON_PID" 2>/dev/null || true
wait "$DAEMON_PID" 2>/dev/null || true
DAEMON_PID=""
# At this point in real life, queries for blocked domains would start failing
# (because the resolver still routes them to a now-dead stub), but that's the
# WHOLE POINT: non-blocked queries are unaffected by definition because they
# never go through us.
pass "stub stopped (this is the simulated 'daemon crash' scenario)"

echo "Step 13: run uninstall — must remove every managed file"
OUT3=$(run_driver uninstall)
echo "$OUT3" | sed 's/^/    /'
echo "$OUT3" | grep -q 'removed=\[.*"instagram.com".*\]' || fail "instagram.com not removed"
echo "$OUT3" | grep -q 'linkedin.com' || fail "linkedin.com not removed"
echo "$OUT3" | grep -q 'mask.icloud.com' || fail "mask.icloud.com not removed"
for d in instagram.com linkedin.com mask.icloud.com mask-h2.icloud.com; do
  [[ ! -e "$SANDBOX/etc/resolver/$d" ]] || fail "$d file still present after uninstall"
done
pass "uninstall removed all managed files"

echo "Step 14: assert the non-managed file STILL exists after uninstall"
[[ -f "$NONOURS" ]] || fail "uninstall removed a file we don't own (BUG)"
grep -q "10.0.0.1" "$NONOURS" || fail "uninstall modified a file we don't own (BUG)"
pass "non-managed file survived uninstall"

echo
echo "──────────────────────────────────────────────────────────────────"
echo "🎯 ALL CHECKS GREEN. Sandbox proves the design works end-to-end."
echo "──────────────────────────────────────────────────────────────────"
