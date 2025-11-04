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

run_d_fixture() {
	cache_root="$(make_temp_dir)/cache"
	script_dir="$(make_temp_dir)"
	script_path="${script_dir}/hello.d"
	cp "${repo_root}/tests/fixtures/hello.d" "${script_path}"

	nix_bin="$(command -v nix || true)"
	if [[ -z "${nix_bin}" ]]; then
		echo "nix command not found; D integration test requires nix" >&2
		exit 1
	fi
	nix_dir="$(dirname "${nix_bin}")"
	fake="$(make_temp_dir)"
	cat > "${fake}/ldc2" <<'FAKE'
#!/usr/bin/env bash
echo "fake ldc2 invoked" >&2
exit 126
FAKE
	chmod +x "${fake}/ldc2"

	output="$(
		PATH="${fake}:${nix_dir}:/bin" \
		JUMPSCRIPT_CACHE="${cache_root}" \
		"${runner}" run D "${script_path}" foo
	)"

	if [[ "${output}" != *"D integration OK"* ]]; then
		echo "Expected D greeting missing" >&2
		printf "%s\n" "${output}" >&2
		exit 1
	fi

	if [[ "${output}" != *"arg=foo"* ]]; then
		echo "Expected argument output missing" >&2
		printf "%s\n" "${output}" >&2
		exit 1
	fi
}

run_d_fixture

test_d_rebuilds_when_module_changes() {
	cache_root="$(make_temp_dir)/cache"
	script_dir="$(make_temp_dir)"
	script_path="${script_dir}/hello_with_import.d"
	helper_path="${script_dir}/hello_helper.d"

	cp "${repo_root}/tests/fixtures/hello_with_import.d" "${script_path}"
	cp "${repo_root}/tests/fixtures/hello_helper.d" "${helper_path}"

	first_output="$(
		JUMPSCRIPT_CACHE="${cache_root}" \
		"${runner}" run D "${script_path}"
	)"

	if [[ "${first_output}" != *"Helper v1"* ]]; then
		printf "Expected first D module run to emit Helper v1\nOutput:\n%s\n" "${first_output}" >&2
		exit 1
	fi

	cat > "${helper_path}" <<'EOF'
module hello_helper;

string message() {
	return "Helper v2";
}
EOF

	future_epoch="$(($(date +%s) + 5))"
	touch -m -d "@${future_epoch}" "${helper_path}"

	second_output="$(
		JUMPSCRIPT_CACHE="${cache_root}" \
		"${runner}" run D "${script_path}"
	)"

	if [[ "${second_output}" != *"Helper v2"* ]]; then
		printf "Expected D rebuild after module change to emit Helper v2\nOutput:\n%s\n" "${second_output}" >&2
		exit 1
	fi
}

test_d_rebuilds_when_module_changes
