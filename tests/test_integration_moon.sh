#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runner="${repo_root}/jumpscript"

tmp_dirs=()
cleanup() {
	for dir in "${tmp_dirs[@]}"; do
		rm -rf "${dir}"
	done
}
trap cleanup EXIT

make_temp_dir() {
	local dir
	dir="$(mktemp -d)"
	tmp_dirs+=("${dir}")
	echo "${dir}"
}

test_moonscript_roundtrip() {
	cache_root="$(make_temp_dir)/cache"
	script_dir="$(make_temp_dir)"
	script_path="${script_dir}/hello.moon"

	cp "${repo_root}/tests/fixtures/hello.moon" "${script_path}"

	nix_bin="$(command -v nix || true)"
	if [[ -z "${nix_bin}" ]]; then
		echo "nix command not found; Moon integration test requires nix" >&2
		exit 1
	fi

	nix_dir="$(dirname "${nix_bin}")"
	fake_moon="$(make_temp_dir)"
	cat > "${fake_moon}/moonc" <<'EOF'
#!/usr/bin/env bash
echo "fake moonc should not be used" >&2
exit 121
EOF
	chmod +x "${fake_moon}/moonc"

	output="$(
		PATH="${fake_moon}:${nix_dir}:/bin" \
		JUMPSCRIPT_CACHE="${cache_root}" \
		"${runner}" run Moon "${script_path}" beep
	)"

	if [[ "${output}" != *"Moon integration OK"* ]]; then
		echo "Expected Moon output not found" >&2
		printf "%s\n" "${output}" >&2
		exit 1
	fi

	if [[ "${output}" != *"arg=beep"* ]]; then
		echo "Expected Moon arg output not found" >&2
		printf "%s\n" "${output}" >&2
		exit 1
	fi
}

test_moonscript_roundtrip
