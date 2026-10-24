#!/bin/bash
# Checks that the built app links no networking framework and imports no socket/HTTP symbols.
# Usage: scripts/check-no-network.sh [path to .app, default build/ScrollSplit.app]
set -euo pipefail
cd "$(dirname "$0")/.."
APP=${1:-build/ScrollSplit.app}
BIN="$APP/Contents/MacOS/ScrollSplit"

echo "Linked libraries:"
otool -L "$BIN" | tail -n +2 | sort -u
FAIL=0
if otool -L "$BIN" | grep -Eiq 'Network.framework|CFNetwork|libcurl|WebKit'; then
    echo "FAIL: a networking framework is linked"; FAIL=1
fi
# Undefined (imported) symbols that open connections. Foundation is linked for UserDefaults,
# so this looks at what the binary actually calls, not at what the frameworks contain.
HITS=$(nm -u "$BIN" | grep -E '_socket$|_connect$|_sendto$|_getaddrinfo$|URLSession|NSURLConnection|CFSocket|CFStream|nw_|NWConnection' || true)
if [ -n "$HITS" ]; then
    echo "FAIL: network symbols imported:"; echo "$HITS"; FAIL=1
fi
[ "$FAIL" = 0 ] && echo "OK: no networking framework or socket/HTTP symbols"
exit $FAIL
