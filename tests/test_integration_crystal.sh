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

run_crystal_fixture() {
	cache_root="$(make_temp_dir)/cache"
	script_dir="$(make_temp_dir)"
	script_path="${script_dir}/hello.cr"
	cp "${repo_root}/tests/fixtures/hello.cr" "${script_path}"

	nix_bin="$(command -v nix || true)"
	if [[ -z "${nix_bin}" ]]; then
		echo "nix command not found; Crystal integration test requires nix" >&2
		exit 1
	fi
	nix_dir="$(dirname "${nix_bin}")"
	fake="$(make_temp_dir)"
	cat > "${fake}/crystal" <<'FAKE'
#!/usr/bin/env bash
echo "fake crystal invoked" >&2
exit 124
FAKE
	chmod +x "${fake}/crystal"

	output="$(
		PATH="${fake}:${nix_dir}:/bin" \
		JUMPSCRIPT_CACHE="${cache_root}" \
		"${runner}" run Crystal "${script_path}" foo
	)"

	if [[ "${output}" != *"Crystal integration OK"* ]]; then
		echo "Expected Crystal greeting missing" >&2
		printf "%s\n" "${output}" >&2
		exit 1
	fi

	if [[ "${output}" != *"arg=foo"* ]]; then
		echo "Expected argument output missing" >&2
		printf "%s\n" "${output}" >&2
		exit 1
	fi

	meta_output="$("${repo_root}/plugins/Crystal/default/plugin" meta "${script_path}")"
	if grep -q '> source.cr' <<<"${meta_output}"; then
		echo "Crystal plugin build command should avoid staging source.cr" >&2
		exit 1
	fi
}

run_crystal_fixture

test_crystal_rebuilds_when_require_changes() {
	cache_root="$(make_temp_dir)/cache"
	work_dir="$(make_temp_dir)"
	script_path="${work_dir}/hello_with_require.cr"
	helper_path="${work_dir}/hello_helper.cr"

	nix_bin="$(command -v nix || true)"
	if [[ -z "${nix_bin}" ]]; then
		echo "nix command not found; Crystal include test requires nix" >&2
		exit 1
	fi
	nix_dir="$(dirname "${nix_bin}")"

	cp "${repo_root}/tests/fixtures/hello_with_require.cr" "${script_path}"
	cp "${repo_root}/tests/fixtures/hello_helper.cr" "${helper_path}"

	first_output="$(
		JUMPSCRIPT_CACHE="${cache_root}" \
		JUMPSCRIPT_PLUGINS_DIR="${repo_root}/plugins" \
		"${runner}" run Crystal "${script_path}"
	)"

	if [[ "${first_output}" != *"Crystal require v1"* ]]; then
		printf "Expected first run output to contain 'Crystal require v1'\nOutput:\n%s\n" "${first_output}" >&2
		exit 1
	fi

	cat > "${helper_path}" <<'EOF'
module HelloHelper
	extend self

	def message
		"Crystal require v2"
	end
end
EOF

	future_epoch="$(($(date +%s) + 5))"
	touch -m -d "@${future_epoch}" "${helper_path}"

	second_output="$(
		JUMPSCRIPT_CACHE="${cache_root}" \
		JUMPSCRIPT_PLUGINS_DIR="${repo_root}/plugins" \
		"${runner}" run Crystal "${script_path}"
	)"

	if [[ "${second_output}" != *"Crystal require v2"* ]]; then
		printf "Expected second run output to contain 'Crystal require v2'\nOutput:\n%s\n" "${second_output}" >&2
		exit 1
	fi
}

test_crystal_rebuilds_when_require_changes
