# Sourced by tests. A PATH directory holding only what jumpscript assumes a
# host provides (INTENT.md): nix and a bash. A plugin that needs any other
# host tool before its flake supplies it fails under this PATH on every OS.
# Usage: minimal_host_dir DIR NIX_BIN  (prints DIR/host-bin)
minimal_host_dir() {
	local dir="$1/host-bin"
	mkdir -p "${dir}"
	ln -sf "$2" "${dir}/nix"
	ln -sf "$(command -v bash)" "${dir}/bash"
	printf '%s\n' "${dir}"
}
