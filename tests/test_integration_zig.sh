#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}" )/.." && pwd)"
runner="${repo_root}/bin/jumpscript"

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

	meta_output="$("${repo_root}/plugins/Zig/default/plugin" meta "${script_path}")"
	if grep -q '> source.zig' <<<"${meta_output}"; then
		echo "Zig plugin build command should avoid staging source.zig" >&2
		exit 1
	fi
}

run_zig_fixture

test_zig_rebuilds_when_module_changes() {
	cache_root="$(make_temp_dir)/cache"
	script_dir="$(make_temp_dir)"
	script_path="${script_dir}/hello_with_import.zig"
	helper_path="${script_dir}/hello_helper.zig"

	cp "${repo_root}/tests/fixtures/hello_with_import.zig" "${script_path}"
	cp "${repo_root}/tests/fixtures/hello_helper.zig" "${helper_path}"

	first_output="$(
		JUMPSCRIPT_CACHE="${cache_root}" \
		"${runner}" run Zig "${script_path}"
	)"

	if [[ "${first_output}" != *"Helper v1"* ]]; then
		printf "Expected first Zig module run to emit Helper v1\nOutput:\n%s\n" "${first_output}" >&2
		exit 1
	fi

	cat > "${helper_path}" <<'EOF'
pub fn message() []const u8 {
	return "Helper v2";
}
EOF

	future_epoch="$(($(date +%s) + 5))"
	touch -m -d "@${future_epoch}" "${helper_path}"

	second_output="$(
		JUMPSCRIPT_CACHE="${cache_root}" \
		"${runner}" run Zig "${script_path}"
	)"

	if [[ "${second_output}" != *"Helper v2"* ]]; then
		printf "Expected Zig rebuild after module change to emit Helper v2\nOutput:\n%s\n" "${second_output}" >&2
		exit 1
	fi

	if compgen -G "${script_dir}/.jumpscript-" >/dev/null 2>&1; then
		echo "Temporary Zig staging files were not cleaned up" >&2
		compgen -G "${script_dir}/.jumpscript-" >&2 || true
		exit 1
	fi
}

test_zig_rebuilds_when_module_changes
