#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}" )/.." && pwd)"
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

run_zig_fixture() {
	cache_root="$(make_temp_dir)/cache"
	script_dir="$(make_temp_dir)"
	script_path="${script_dir}/hello.zig"
	cp "${repo_root}/tests/fixtures/hello.zig" "${script_path}"

	nix_bin="$(command -v nix || true)"
	if [[ -z "${nix_bin}" ]]; then
		echo "nix command not found; Zig integration test requires nix" >&2
		exit 1
	fi
	nix_dir="$(dirname "${nix_bin}")"
	fake="$(make_temp_dir)"
	cat > "${fake}/zig" <<'FAKE'
#!/usr/bin/env bash
echo "fake zig invoked" >&2
exit 129
FAKE
	chmod +x "${fake}/zig"

	output="$(
		PATH="${fake}:${nix_dir}:/bin" \
		JUMPSCRIPT_CACHE="${cache_root}" \
		"${runner}" run Zig "${script_path}" foo
	)"

	if [[ "${output}" != *"Zig integration OK"* ]]; then
		echo "Expected Zig greeting missing" >&2
		printf "%s\n" "${output}" >&2
		exit 1
	fi

	if [[ "${output}" != *"arg=foo"* ]]; then
		echo "Expected argument output missing" >&2
		printf "%s\n" "${output}" >&2
		exit 1
	fi
}

run_zig_fixture
