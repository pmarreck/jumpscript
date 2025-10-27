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

run_lean_fixture() {
	cache_root="$(make_temp_dir)/cache"
	script_dir="$(make_temp_dir)"
	script_path="${script_dir}/hello.lean"
	cp "${repo_root}/tests/fixtures/hello.lean" "${script_path}"

	nix_bin="$(command -v nix || true)"
	if [[ -z "${nix_bin}" ]]; then
		echo "nix command not found; Lean integration test requires nix" >&2
		exit 1
	fi
	nix_dir="$(dirname "${nix_bin}")"
	fake="$(make_temp_dir)"
	cat > "${fake}/lean" <<'FAKE'
#!/usr/bin/env bash
echo "fake lean invoked" >&2
exit 131
FAKE
	chmod +x "${fake}/lean"

	output="$(
		PATH="${fake}:${nix_dir}:/bin" \
		JUMPSCRIPT_CACHE="${cache_root}" \
		"${runner}" run Lean "${script_path}" foo
	)"

	entry_dir="$(find "${cache_root}/Lean/default" -mindepth 1 -maxdepth 1 -type d | head -n 1 || true)"
	if [[ -z "${entry_dir}" ]]; then
		echo "Lean cache entry not created" >&2
		exit 1
	fi

	expected_artifact="${entry_dir}/bin/hello"
	if [[ ! -x "${expected_artifact}" ]]; then
		echo "Lean artifact missing or not executable: ${expected_artifact}" >&2
		ls -R "${entry_dir}" >&2
		exit 1
	fi

	if [[ "${output}" != *"Lean integration OK"* ]]; then
		echo "Expected Lean greeting missing" >&2
		printf "%s\n" "${output}" >&2
		exit 1
	fi

	if [[ "${output}" != *"arg=foo"* ]]; then
		echo "Expected argument output missing" >&2
		printf "%s\n" "${output}" >&2
		exit 1
	fi
}

run_lean_fixture
