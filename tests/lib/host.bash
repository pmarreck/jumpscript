# Portable helpers sourced by tests.
#
# minimal_host_dir: a PATH directory holding only what jumpscript assumes a
# host provides (INTENT.md), nix and a bash. A plugin that needs any other
# host tool before its flake supplies it fails under this PATH on every OS.
# Usage: minimal_host_dir DIR NIX_BIN  (prints DIR/host-bin)
minimal_host_dir() {
	local dir="$1/host-bin"
	mkdir -p "${dir}"
	ln -sf "$2" "${dir}/nix"
	ln -sf "$(command -v bash)" "${dir}/bash"
	printf '%s\n' "${dir}"
}

# Sets a file's mtime to an epoch second with POSIX touch -t. The time is
# formatted by GNU date (-d @N) or BSD date (-r N), whichever this date is;
# a machine can mix GNU date with BSD touch.
set_mtime() {
	local stamp
	stamp="$(date -d "@$1" +%Y%m%d%H%M.%S 2>/dev/null || date -r "$1" +%Y%m%d%H%M.%S)"
	touch -t "${stamp}" "$2"
}
