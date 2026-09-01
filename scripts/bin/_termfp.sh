#!/usr/bin/env bash

SAVE_PATH="$1"
START_DIR="$2"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

LOCK_FILE="$TMP_DIR/lock"
touch "$LOCK_FILE"

# Inject yield command into shell
cat <<'EOF' >"$TMP_DIR/yield"
#!/usr/bin/env bash

# Clear the save file to prevent appending to old data if run multiple times
> "$YIELD_SAVE_PATH"

# Check and append absolute paths
save_path() {
    if [ -e "$1" ]; then
        realpath "$1" >> "$YIELD_SAVE_PATH"
    else
        echo "Warning: '$1' does not exist, skipping." >&2
    fi
}

# Handle positional args
if [ "$#" -gt 0 ]; then
    for arg in "$@"; do
        save_path "$arg"
    done
fi

# Handle piped input
if [ ! -t 0 ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        save_path "$line"
    done
fi

# Abort if no valid files were written
if [ ! -s "$YIELD_SAVE_PATH" ]; then
    echo "Error: No valid files provided." >&2
    exit 1
fi

rm -f "$YIELD_LOCK_FILE"
kill -HUP $PPID
EOF
chmod +x "$TMP_DIR/yield"

# Inject the path and detect exits
cat <<'EOF' >"$TMP_DIR/shell_wrapper"
#!/usr/bin/env bash
export PATH="$YIELD_TMP_DIR:$PATH"
"$SHELL"
# Release the lock if the user exits without picking a file
rm -f "$YIELD_LOCK_FILE"
EOF
chmod +x "$TMP_DIR/shell_wrapper"

export YIELD_SAVE_PATH="$SAVE_PATH"
export YIELD_LOCK_FILE="$LOCK_FILE"
export YIELD_TMP_DIR="$TMP_DIR"

cd "$START_DIR" || exit 1

xdg-terminal-exec "$TMP_DIR/shell_wrapper"

# Portal should not close until lockfile is gone
if [ -f "$LOCK_FILE" ]; then
	inotifywait -e delete_self -e move_self "$LOCK_FILE" >/dev/null 2>&1
fi
