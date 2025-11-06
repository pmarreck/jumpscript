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

run_nim_fixture() {
	cache_root="$(make_temp_dir)/cache"
	script_dir="$(make_temp_dir)"
	script_path="${script_dir}/hello.nim"
	cp "${repo_root}/tests/fixtures/hello.nim" "${script_path}"

	nix_bin="$(command -v nix || true)"
	if [[ -z "${nix_bin}" ]]; then
		echo "nix command not found; Nim integration test requires nix" >&2
		exit 1
	fi
	nix_dir="$(dirname "${nix_bin}")"
	fake="$(make_temp_dir)"
	cat > "${fake}/nim" <<'FAKE'
#!/usr/bin/env bash
echo "fake nim invoked" >&2
exit 127
FAKE
	chmod +x "${fake}/nim"

	output="$(
		PATH="${fake}:${nix_dir}:/bin" \
		JUMPSCRIPT_CACHE="${cache_root}" \
		"${runner}" run Nim "${script_path}" foo
	)"

	if [[ "${output}" != *"Nim integration OK"* ]]; then
		echo "Expected Nim greeting missing" >&2
		printf "%s\n" "${output}" >&2
		exit 1
	fi

	if [[ "${output}" != *"arg=foo"* ]]; then
		echo "Expected argument output missing" >&2
		printf "%s\n" "${output}" >&2
		exit 1
	fi

	meta_output="$("${repo_root}/plugins/Nim/default/plugin" meta "${script_path}")"
	if grep -q '> source.nim' <<<"${meta_output}"; then
		echo "Nim plugin build command should avoid staging source.nim" >&2
		exit 1
	fi
}

run_nim_fixture

test_nim_rebuilds_when_include_changes() {
	cache_root="$(make_temp_dir)/cache"
	work_dir="$(make_temp_dir)"
	script_path="${work_dir}/hello_with_include.nim"
	helper_path="${work_dir}/hello_include_helper.nim"

	cp "${repo_root}/tests/fixtures/hello_with_include.nim" "${script_path}"
	cp "${repo_root}/tests/fixtures/hello_include_helper.nim" "${helper_path}"

	first_output="$(
		JUMPSCRIPT_CACHE="${cache_root}" \
		JUMPSCRIPT_PLUGINS_DIR="${repo_root}/plugins" \
		"${runner}" run Nim "${script_path}"
	)"

	if [[ "${first_output}" != *"Nim include v1"* ]]; then
		printf "Expected first run output to contain 'Nim include v1'\nOutput:\n%s\n" "${first_output}" >&2
		exit 1
	fi

cat > "${helper_path}" <<'EOF'
# Nim helper module used for include rebuild coverage

proc helperMessage(): string =
  "Nim include v2"
EOF

	future_epoch="$(($(date +%s) + 5))"
	touch -m -d "@${future_epoch}" "${helper_path}"

	second_output="$(
		JUMPSCRIPT_CACHE="${cache_root}" \
		JUMPSCRIPT_PLUGINS_DIR="${repo_root}/plugins" \
		"${runner}" run Nim "${script_path}"
	)"

	if [[ "${second_output}" != *"Nim include v2"* ]]; then
		printf "Expected second run output to contain 'Nim include v2'\nOutput:\n%s\n" "${second_output}" >&2
		exit 1
	fi
}

test_nim_rebuilds_when_include_changes
