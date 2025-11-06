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

run_idris_fixture() {
	cache_root="$(make_temp_dir)/cache"
	script_dir="$(make_temp_dir)"
	script_path="${script_dir}/hello.idr"
	cp "${repo_root}/tests/fixtures/hello.idr" "${script_path}"

	nix_bin="$(command -v nix || true)"
	if [[ -z "${nix_bin}" ]]; then
		echo "nix command not found; Idris integration test requires nix" >&2
		exit 1
	fi
	nix_dir="$(dirname "${nix_bin}")"
	fake="$(make_temp_dir)"
	cat > "${fake}/idris2" <<'FAKE'
#!/usr/bin/env bash
echo "fake idris2 invoked" >&2
exit 130
FAKE
	chmod +x "${fake}/idris2"

	output="$(
		PATH="${fake}:${nix_dir}:/bin" \
		JUMPSCRIPT_CACHE="${cache_root}" \
		"${runner}" run Idris "${script_path}" foo
	)"

	if [[ "${output}" != *"Idris integration OK"* ]]; then
		echo "Expected Idris greeting missing" >&2
		printf "%s\n" "${output}" >&2
		exit 1
	fi

	if [[ "${output}" != *"arg=foo"* ]]; then
		echo "Expected argument output missing" >&2
		printf "%s\n" "${output}" >&2
		exit 1
	fi

	meta_output="$("${repo_root}/plugins/Idris/default/plugin" meta "${script_path}")"
	if grep -q 'source.idr' <<<"${meta_output}"; then
		echo "Idris plugin build command should avoid staging source.idr" >&2
		exit 1
	fi
}

run_idris_fixture

test_idris_rebuilds_when_import_changes() {
	cache_root="$(make_temp_dir)/cache"
	work_dir="$(make_temp_dir)"
	script_path="${work_dir}/hello_with_import.idr"
	helper_path="${work_dir}/HelloHelper.idr"

	nix_bin="$(command -v nix || true)"
	if [[ -z "${nix_bin}" ]]; then
		echo "nix command not found; Idris import test requires nix" >&2
		exit 1
	fi

	cp "${repo_root}/tests/fixtures/hello_with_import.idr" "${script_path}"
	cp "${repo_root}/tests/fixtures/hello_helper.idr" "${helper_path}"

	first_output="$(
		JUMPSCRIPT_CACHE="${cache_root}" \
		JUMPSCRIPT_PLUGINS_DIR="${repo_root}/plugins" \
		"${runner}" run Idris "${script_path}" foo
	)"

	if [[ "${first_output}" != *"Idris import v1"* ]]; then
		printf "Expected first run output to contain 'Idris import v1'\nOutput:\n%s\n" "${first_output}" >&2
		exit 1
	fi

	cat > "${helper_path}" <<'EOF'
module HelloHelper

public export
message : String
message = "Idris import v2"
EOF

	future_epoch="$(($(date +%s) + 5))"
	touch -m -d "@${future_epoch}" "${helper_path}"

	second_output="$(
		JUMPSCRIPT_CACHE="${cache_root}" \
		JUMPSCRIPT_PLUGINS_DIR="${repo_root}/plugins" \
		"${runner}" run Idris "${script_path}" foo
	)"

	if [[ "${second_output}" != *"Idris import v2"* ]]; then
		printf "Expected second run output to contain 'Idris import v2'\nOutput:\n%s\n" "${second_output}" >&2
		exit 1
	fi

	if compgen -G "${work_dir}/.jumpscript-" >/dev/null 2>&1; then
		echo "Temporary Idris staging files were not cleaned up" >&2
		compgen -G "${work_dir}/.jumpscript-" >&2 || true
		exit 1
	fi
}

test_idris_rebuilds_when_import_changes
