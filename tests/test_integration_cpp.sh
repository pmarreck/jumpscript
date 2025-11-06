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

run_cpp_fixture() {
	cache_root="$(make_temp_dir)/cache"
	script_dir="$(make_temp_dir)"
	script_path="${script_dir}/hello.cpp"
	cp "${repo_root}/tests/fixtures/hello.cpp" "${script_path}"

	nix_bin="$(command -v nix || true)"
	if [[ -z "${nix_bin}" ]]; then
		echo "nix command not found; C++ integration test requires nix" >&2
		exit 1
	fi
	nix_dir="$(dirname "${nix_bin}")"
	fake_compilers="$(make_temp_dir)"
	cat > "${fake_compilers}/g++" <<'FAKE'
#!/usr/bin/env bash
echo "fake g++ invoked" >&2
exit 125
FAKE
	chmod +x "${fake_compilers}/g++"

	output="$(
		PATH="${fake_compilers}:${nix_dir}:/bin" \
		JUMPSCRIPT_CACHE="${cache_root}" \
		"${runner}" run C++ "${script_path}" foo bar
	)"

	if [[ "${output}" != *"C++ integration OK"* ]]; then
		echo "Expected C++ greeting missing" >&2
		printf "%s\n" "${output}" >&2
		exit 1
	fi

	if [[ "${output}" != *"arg=foo"* ]]; then
		echo "Expected argument output missing" >&2
		printf "%s\n" "${output}" >&2
		exit 1
	fi

	meta_output="$("${repo_root}/plugins/C++/default/plugin" meta "${script_path}")"
	if grep -q '> source.cpp' <<<"${meta_output}"; then
		echo "C++ plugin build command should avoid staging source.cpp" >&2
		exit 1
	fi
}

run_cpp_fixture
