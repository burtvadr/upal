#!/bin/sh
# update_script.sh — update a proof-of-concept script from the generic template
# Preserves set variables, adds new variables from the template
# Usage: ./update_script.sh <target_script>

set -eu

SCRIPT_DIR=$(cd -P -- "$(dirname -- "$0")" && command pwd -P)
TEMPLATE="$SCRIPT_DIR/posix_variables"

[ $# -eq 1 ] || { echo "Usage: $0 <target_script>" >&2; exit 1; }
TARGET=$1

[ -f "$TARGET" ] || { echo "Error: '$TARGET' not found" >&2; exit 1; }
[ -f "$TEMPLATE" ] || { echo "Error: template '$TEMPLATE' not found" >&2; exit 1; }

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

# Merge: old variable values take precedence over template
# New variables from the template are added automatically
awk '
    NR==FNR {
        # Old target: collect variable assignments
        if (match($0, /^[A-Za-z_][A-Za-z0-9_]*=/)) {
            var = substr($0, 1, index($0, "=") - 1)
            old[var] = $0
        }
        next
    }
    {
        # Template: replace variable lines with old values if they exist
        if (match($0, /^[A-Za-z_][A-Za-z0-9_]*=/)) {
            var = substr($0, 1, index($0, "=") - 1)
            if (var in old) {
                print old[var]
                next
            }
        }
        print
    }
' "$TARGET" "$TEMPLATE" > "$TMP"

mv "$TMP" "$TARGET"
