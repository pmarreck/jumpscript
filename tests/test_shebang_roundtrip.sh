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
