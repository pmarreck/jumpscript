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

test_c_plugin_builds_and_runs() {
	cache_root="$(make_temp_dir)/cache"
	script_path="$(make_temp_dir)/hello.c"
	cp "${repo_root}/tests/fixtures/hello.c" "${script_path}"

	run_with_env() {
		local path_override="$1"

		set +e
		output="$(PATH="${path_override}" JUMPSCRIPT_CACHE="${cache_root}" "${runner}" run C "${script_path}" beep 2>&1)"
		status=$?
		set -e

		if [[ "${status}" -ne 0 ]]; then
			printf 'Expected C plugin to build and run successfully, exit=0; got %d\nPATH=%s\nOutput:\n%s\n' "${status}" "${path_override}" "${output}" >&2
			exit 1
		fi

		if [[ "${output}" != *"C integration OK"* ]]; then
			printf "Expected output to contain 'C integration OK'\nPATH=%s\nOutput:\n%s\n" "${path_override}" "${output}" >&2
			exit 1
		fi

		if [[ "${output}" != *"arg=beep"* ]]; then
			printf "Expected output to contain 'arg=beep'\nPATH=%s\nOutput:\n%s\n" "${path_override}" "${output}" >&2
			exit 1
		fi
	}

	run_with_env "${PATH}"

	entry_dir="$(find "${cache_root}/C/default" -mindepth 1 -maxdepth 1 -type d | head -n 1 || true)"
	if [[ -z "${entry_dir}" ]]; then
		echo "C cache entry not created" >&2
		exit 1
	fi

	if find "${entry_dir}" -maxdepth 1 -name 'source.c' | grep -q '.'; then
		echo "unexpected source.c staged in cache entry" >&2
		exit 1
	fi

	meta_output="$("${repo_root}/plugins/C/default/plugin" meta "${script_path}")"
	if grep -q '> source.c' <<<"${meta_output}"; then
		echo "C plugin build command should avoid staging source.c" >&2
		exit 1
	fi

	nix_bin="$(command -v nix || true)"
	if [[ -z "${nix_bin}" ]]; then
		echo "nix command not found; C integration test requires nix" >&2
		exit 1
	fi
	nix_dir="$(dirname "${nix_bin}")"
	fake_cc_dir="$(make_temp_dir)"
	cat > "${fake_cc_dir}/cc" <<'EOF'
#!/usr/bin/env bash
echo "fake cc invoked" >&2
exit 120
EOF
chmod +x "${fake_cc_dir}/cc"

# Force rebuild by modifying source
echo "// tweak" >> "${script_path}"

run_with_env "${fake_cc_dir}:${nix_dir}:/bin"
}

test_c_plugin_rebuilds_when_header_changes() {
	cache_root="$(make_temp_dir)/cache"
	work_dir="$(make_temp_dir)"
	script_path="${work_dir}/hello_with_header.c"
	header_path="${work_dir}/hello_header.h"
	cp "${repo_root}/tests/fixtures/hello_with_header.c" "${script_path}"
	cp "${repo_root}/tests/fixtures/hello_header.h" "${header_path}"

	first_output="$(
		JUMPSCRIPT_CACHE="${cache_root}" \
		JUMPSCRIPT_PLUGINS_DIR="${repo_root}/plugins" \
		"${runner}" run C "${script_path}"
	)"

	if [[ "${first_output}" != *"Header v1"* ]]; then
		printf "Expected first run output to contain 'Header v1'\nOutput:\n%s\n" "${first_output}" >&2
		exit 1
	fi

	cat > "${header_path}" <<'EOF'
/* Header used to exercise include rebuild behavior */
#pragma once

#define HEADER_MESSAGE "Header v2"
EOF

	future_epoch="$(($(date +%s) + 5))"
	touch -m -d "@${future_epoch}" "${header_path}"

	second_output="$(
		JUMPSCRIPT_CACHE="${cache_root}" \
		JUMPSCRIPT_PLUGINS_DIR="${repo_root}/plugins" \
		"${runner}" run C "${script_path}"
	)"

	if [[ "${second_output}" != *"Header v2"* ]]; then
		printf "Expected second run output to contain 'Header v2'\nOutput:\n%s\n" "${second_output}" >&2
		exit 1
	fi
}

test_c_plugin_builds_and_runs
test_c_plugin_rebuilds_when_header_changes
