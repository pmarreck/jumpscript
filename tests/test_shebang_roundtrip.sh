#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}" )/.." && pwd)"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

run_fixture_via_shebang() {
	local fixture="$1"
	local expect_snippet="$2"
	local arg="$3"

	local script_path="${tmp_dir}/$(basename "${fixture}")"
	cp "${repo_root}/${fixture}" "${script_path}"
	chmod +x "${script_path}"

	local output
	output="$(
		PATH="${repo_root}:${PATH}" \
			"${script_path}" "${arg}"
	)"

	if [[ "${output}" != *"${expect_snippet}"* ]]; then
		echo "Expected output to contain '${expect_snippet}'" >&2
		echo "Got:" >&2
		echo "${output}" >&2
		exit 1
	fi
}

run_fixture_via_shebang "tests/fixtures/hello.cpp" "C++ integration OK" "foo"

# Ensure original fixtures execute via relative path from repo root.
relative_output="$(
	cd "${repo_root}"
	PATH="${repo_root}:${PATH}" \
		tests/fixtures/hello.d bar
)"

if [[ "${relative_output}" != *"D integration OK"* ]]; then
	echo "Expected relative shebang execution to produce 'D integration OK'" >&2
	echo "Output:" >&2
	echo "${relative_output}" >&2
	exit 1
fi

# Running fixtures directly from a non-repo directory should succeed.
tmp_exec_dir="$(mktemp -d)"
cp "${repo_root}/tests/fixtures/hello.c" "${tmp_exec_dir}/hello.c"
chmod +x "${tmp_exec_dir}/hello.c"

pushd "${tmp_exec_dir}" >/dev/null
output_text="$(PATH="${repo_root}:${PATH}" ./hello.c rant 2>&1)"
status=$?
popd >/dev/null
rm -rf "${tmp_exec_dir}"

if [[ "${status}" -ne 0 ]]; then
	echo "C fixture failed when executed from temp directory (exit ${status})" >&2
	echo "${output_text}" >&2
	exit 1
fi

if [[ "${output_text}" != *"C integration OK"* ]]; then
	echo "Expected remote shebang execution to produce 'C integration OK'" >&2
	echo "Output:" >&2
	echo "${output_text}" >&2
	exit 1
fi
