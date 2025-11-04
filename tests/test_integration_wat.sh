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

test_wat_roundtrip() {
	cache_root="$(make_temp_dir)/cache"
	script_dir="$(make_temp_dir)"
	script_path="${script_dir}/hello.wat"

		cp "${repo_root}/tests/fixtures/hello.wat" "${script_path}"

	nix_bin="$(command -v nix || true)"
	if [[ -z "${nix_bin}" ]]; then
		echo "nix command not found; WAT integration test requires nix" >&2
		exit 1
	fi

	nix_dir="$(dirname "${nix_bin}")"
	fake_tools="$(make_temp_dir)"
	cat > "${fake_tools}/wat2wasm" <<'EOF_STUB'
#!/usr/bin/env bash
echo "fake wat2wasm invoked" >&2
exit 122
EOF_STUB
	chmod +x "${fake_tools}/wat2wasm"

	output="$(
		PATH="${fake_tools}:${nix_dir}:/bin" \
		JUMPSCRIPT_CACHE="${cache_root}" \
		"${runner}" run Wat "${script_path}"
	)"

	if [[ "${output}" != *"WAT hello"* ]]; then
		echo "Expected WAT runtime output not found" >&2
		printf "%s\n" "${output}" >&2
		exit 1
	fi

	cat > "${fake_tools}/wat2wasm" <<'EOF_STUB_FAIL'
#!/usr/bin/env bash
echo "wat2wasm should not rerun" >&2
exit 125
EOF_STUB_FAIL
	chmod +x "${fake_tools}/wat2wasm"

	second_output="$(
		PATH="${fake_tools}:${nix_dir}:/bin" \
		JUMPSCRIPT_CACHE="${cache_root}" \
		"${runner}" run Wat "${script_path}"
	)"

	if [[ "${second_output}" != *"WAT hello"* ]]; then
		echo "Expected cached WAT run to succeed" >&2
		printf "%s\n" "${second_output}" >&2
		exit 1
	fi
}

test_wat_roundtrip
