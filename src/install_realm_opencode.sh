#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "help" ]; then
    exec "$SCRIPT_DIR/realm_opencode.sh" --help
fi
exec "$SCRIPT_DIR/realm_opencode.sh" install "$@"
