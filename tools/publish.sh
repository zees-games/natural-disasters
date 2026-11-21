#!/bin/bash
# Publishes this addon to the gs-cloud CDN. Linked addons and the demo-only Kenney art stay out.
#   tools/publish.sh VERSION [extra publish_pack.sh flags, e.g. --token-file F --dry-run]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
V=${1:?usage: tools/publish.sh VERSION [flags]}; shift
exec "$HERE/../gs-cloud/tools/publish_pack.sh" publish --source "$HERE" --id natural-disasters --version "$V" \
    --exclude-dir gs_core --exclude-dir gs_server --exclude-dir examples --exclude-dir tools --exclude-dir assets --exclude-dir ci --exclude-dir docs \
    --lock "$HERE/content.lock.json" "$@"
