#!/usr/bin/env bash
# The Zig runner's pure core: unit tests in ReleaseFast and Debug.
set -u
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}" || exit 1
status=0
for mode in ReleaseFast Debug; do
	if ! out="$(nix develop "${repo_root}" -c zig build test -Doptimize="${mode}" 2>&1)"; then
		printf '%s\n' "${out}" >&2
		echo "FAIL: zig core tests (${mode})" >&2
		status=1
	fi
done
[[ ${status} -eq 0 ]] && echo "test_zig_core: all passed"
exit "${status}"
