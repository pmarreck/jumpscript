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

run_rust_fixture() {
	cache_root="$(make_temp_dir)/cache"
	script_dir="$(make_temp_dir)"
	script_path="${script_dir}/hello.rs"
	cp "${repo_root}/tests/fixtures/hello.rs" "${script_path}"

	nix_bin="$(command -v nix || true)"
	if [[ -z "${nix_bin}" ]]; then
		echo "nix command not found; Rust integration test requires nix" >&2
		exit 1
	fi
	nix_dir="$(dirname "${nix_bin}")"
	fake="$(make_temp_dir)"
	cat > "${fake}/rustc" <<'FAKE'
#!/usr/bin/env bash
echo "fake rustc invoked" >&2
exit 128
FAKE
	chmod +x "${fake}/rustc"

	output="$(
		PATH="${fake}:${nix_dir}:/bin" \
		JUMPSCRIPT_CACHE="${cache_root}" \
		"${runner}" run Rust "${script_path}" foo
	)"

	if [[ "${output}" != *"Rust integration OK"* ]]; then
		echo "Expected Rust greeting missing" >&2
		printf "%s\n" "${output}" >&2
		exit 1
	fi

	if [[ "${output}" != *"arg=foo"* ]]; then
		echo "Expected argument output missing" >&2
		printf "%s\n" "${output}" >&2
		exit 1
	fi

	meta_output="$("${repo_root}/plugins/Rust/default/plugin" meta "${script_path}")"
	if grep -q '> source.rs' <<<"${meta_output}"; then
		echo "Rust plugin build command should avoid staging source.rs" >&2
		exit 1
	fi
}

run_rust_fixture

test_rust_rebuilds_when_module_changes() {
	cache_root="$(make_temp_dir)/cache"
	work_dir="$(make_temp_dir)"
	script_path="${work_dir}/hello_with_module.rs"
	helper_path="${work_dir}/hello_helper.rs"

	cp "${repo_root}/tests/fixtures/hello_with_module.rs" "${script_path}"
	cp "${repo_root}/tests/fixtures/hello_helper.rs" "${helper_path}"

	first_output="$(
		JUMPSCRIPT_CACHE="${cache_root}" \
		JUMPSCRIPT_PLUGINS_DIR="${repo_root}/plugins" \
		"${runner}" run Rust "${script_path}"
	)"

	if [[ "${first_output}" != *"Rust module v1"* ]]; then
		printf "Expected first run output to contain 'Rust module v1'\nOutput:\n%s\n" "${first_output}" >&2
		exit 1
	fi

	cat > "${helper_path}" <<'EOF'
pub fn message() -> &'static str {
	"Rust module v2"
}
EOF

	future_epoch="$(($(date +%s) + 5))"
	touch -m -d "@${future_epoch}" "${helper_path}"

	second_output="$(
		JUMPSCRIPT_CACHE="${cache_root}" \
		JUMPSCRIPT_PLUGINS_DIR="${repo_root}/plugins" \
		"${runner}" run Rust "${script_path}"
	)"

	if [[ "${second_output}" != *"Rust module v2"* ]]; then
		printf "Expected second run output to contain 'Rust module v2'\nOutput:\n%s\n" "${second_output}" >&2
		exit 1
	fi
}

test_rust_rebuilds_when_module_changes
