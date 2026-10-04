# Pure-Bash stand-ins for host tools, sourced by the bundled plugins. Before
# a plugin's flake supplies its tools, the only host tools jumpscript assumes
# are nix and bash (INTENT.md), so plugin code that runs outside `nix develop`
# uses these instead of cat, tail and grep.

# Copies stdin to stdout unchanged (cat), including a missing final newline.
pl_cat() {
	local line
	while IFS= read -r line; do
		printf '%s\n' "${line}"
	done
	[[ -z "${line}" ]] || printf '%s' "${line}"
}

# Reads a heredoc into the variable named $1, without its final newline,
# like VAR="$(cat <<'X' ... X)".
pl_heredoc() {
	IFS= read -r -d '' "$1" || true
	printf -v "$1" '%s' "${!1%$'\n'}"
}

# Prints every match of the extended regex $1 in file $2, one per line, in
# order, skipping the first line (the shebang): tail -n +2 | grep -oE.
pl_matches() {
	local re="$1" line first=1 m
	while IFS= read -r line || [[ -n "${line}" ]]; do
		if (( first )); then
			first=0
			continue
		fi
		while [[ -n "${line}" && "${line}" =~ ${re} ]]; do
			m="${BASH_REMATCH[0]}"
			[[ -n "${m}" ]] || break
			printf '%s\n' "${m}"
			line="${line#*"${m}"}"
		done
	done < "$2"
}

# Prints file $1 without its first line (the shebang): tail -n +2.
pl_body() {
	{
		IFS= read -r _ || return 0
		pl_cat
	} < "$1"
}
