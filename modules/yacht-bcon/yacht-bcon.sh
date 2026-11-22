# Feed bcons clipboard into yacht
#
# bcon rewrites $XDG_RUNTIME_DIR/bcon_clipboard_<pid> (or /tmp/bcon_clipboard_<pid>
# when it runs as root without XDG_RUNTIME_DIR) on every selection copy, URL copy and OSC 52 write
me=$(id -u)
dirs=(/tmp)
if [ -n "${XDG_RUNTIME_DIR:-}" ]; then dirs+=("$XDG_RUNTIME_DIR"); fi

inotifywait -m -q -e close_write -e moved_to --format '%w|%f' "${dirs[@]}" |
	while IFS='|' read -r dir name; do
		case $name in bcon_clipboard_*) ;; *) continue ;; esac
		f=${dir%/}/$name
		# /tmp is shared: only regular files owned by us or root, never symlinks
		if [ -L "$f" ] || [ ! -f "$f" ]; then continue; fi
		owner=$(stat -c %u -- "$f") || continue
		if [ "$owner" != "$me" ] && [ "$owner" != 0 ]; then continue; fi
		yacht copy --mime 'text/plain;charset=utf-8' --source bcon <"$f" || true
	done
