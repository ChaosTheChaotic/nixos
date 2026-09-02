#!/usr/bin/env bash

MODE_MULTIPLE="$1"
MODE_DIR="$2"
MODE_SAVE="$3"
START_PATH="$4"
SAVE_PATH="$5"

# Find a start directory
if [ -d "$START_PATH" ]; then
	START_DIR="$START_PATH"
elif [ -n "$START_PATH" ]; then
	START_DIR="$(dirname "$START_PATH")"
	[ -d "$START_DIR" ] || START_DIR="$HOME"
else
	START_DIR="$HOME"
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

LOCK_FILE="$TMP_DIR/lock"
touch "$LOCK_FILE"

# Ensure scripts can find it
export UTIL_SCRIPT_DIR

# Inject yield command into shell
cat <<'EOF' >"$TMP_DIR/yield"
#!/usr/bin/env bash
source "$UTIL_SCRIPT_DIR/colors.sh"

# Clear the save file to prevent appending to old data if run multiple times
> "$YIELD_SAVE_PATH"
COUNT=0
ERRORS=0

process_path() {
    local target="$1"
    
    # If in open mode (0), target MUST exist
    if [ "$YIELD_MODE_SAVE" = "0" ] && [ ! -e "$target" ]; then
        echo -e "${BRed}Error: '$target' does not exist.${Reset}" >&2
        ERRORS=$((ERRORS + 1))
        return
    fi

    # If in dir mode (1), target must be a directory
    if [ "$YIELD_MODE_DIR" = "1" ] && [ -e "$target" ] && [ ! -d "$target" ]; then
        echo -e "${BRed}Error: '$target' is not a directory. A directory is required.${Reset}" >&2
        ERRORS=$((ERRORS + 1))
        return
    fi

    # Get absolute path (realpath -m resolves even if the file doesnt exist yet for saving)
    local abs_path
    if [ "$YIELD_MODE_SAVE" = "1" ]; then
        abs_path="$(realpath -m "$target")"
    else
        abs_path="$(realpath "$target")"
    fi

    if [ "$COUNT" -eq 0 ]; then
        printf "%s" "$abs_path" >> "$YIELD_SAVE_PATH"
    else
        printf "\n%s" "$abs_path" >> "$YIELD_SAVE_PATH"
    fi

    COUNT=$((COUNT + 1))
}

# Handle positional args
if [ "$#" -gt 0 ]; then
    for arg in "$@"; do
        process_path "$arg"
    done
fi

# Handle piped input
if [ ! -t 0 ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        [ -n "$line" ] && process_path "$line"
    done
fi

if [ "$YIELD_MODE_MULTIPLE" = "0" ] && [ "$COUNT" -gt 1 ]; then
    echo -e "${BRed}Error: Multiple files provided, but only a single selection is allowed.${Reset}" >&2
    ERRORS=$((ERRORS + 1))
fi

# Abort if no valid files were written or rules were broken
if [ "$ERRORS" -gt 0 ] || [ "$COUNT" -eq 0 ]; then
    if [ "$COUNT" -eq 0 ] && [ "$ERRORS" -eq 0 ]; then
        echo -e "${BRed}Error: No valid paths provided.${Reset}" >&2
    fi
    # Clear the save file because the selection was invalid
    > "$YIELD_SAVE_PATH"
    
    # Exits the yield with error, doesnt close terminal
    exit 1
fi

trap '' HUP TERM

rm -f "$YIELD_LOCK_FILE"

SHELL_PID=$(pgrep -P "$YIELD_WRAPPER_PID" | head -n 1)
if [ -n "$SHELL_PID" ]; then
    kill -SIGHUP "$SHELL_PID" 2>/dev/null
fi
EOF
chmod +x "$TMP_DIR/yield"

# Inject the environment wrapper
cat <<'EOF' >"$TMP_DIR/shell_wrapper"
#!/usr/bin/env bash
source "$UTIL_SCRIPT_DIR/colors.sh"
export PATH="$YIELD_TMP_DIR:$PATH"
export YIELD_WRAPPER_PID=$$

trap 'rm -f "$YIELD_LOCK_FILE"' EXIT
trap 'exit 1' HUP TERM INT

ACTION=$([ "$YIELD_MODE_SAVE" = "1" ] && echo "Save" || echo "Open")
TARGET=$([ "$YIELD_MODE_DIR" = "1" ] && echo "Directory" || echo "File")
LIMIT=$([ "$YIELD_MODE_MULTIPLE" = "1" ] && echo "Multiple" || echo "Single")

echo -e "${BCyan}Terminal File Chooser${Reset}"
echo -e "Action: $ACTION | Target: $TARGET | Selection: $LIMIT"
echo -e "Confirm: ${BGreen}yield <path>${Reset}  •  Cancel: ${BRed}exit${Reset} (or Ctrl+D)\n"

"$SHELL"
EOF
chmod +x "$TMP_DIR/shell_wrapper"

export YIELD_MODE_SAVE="$MODE_SAVE"
export YIELD_MODE_MULTIPLE="$MODE_MULTIPLE"
export YIELD_MODE_DIR="$MODE_DIR"
export YIELD_SAVE_PATH="$SAVE_PATH"
export YIELD_LOCK_FILE="$LOCK_FILE"
export YIELD_TMP_DIR="$TMP_DIR"

cd "$START_DIR" || exit 1

xdg-terminal-exec "$TMP_DIR/shell_wrapper" &

if [ -f "$LOCK_FILE" ]; then
	inotifywait -e delete_self -e move_self "$LOCK_FILE" >/dev/null 2>&1
fi

if [ -s "$SAVE_PATH" ]; then
	exit 0
else
	exit 1
fi
