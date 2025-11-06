#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}" )/.." && pwd)"
runner="${repo_root}/bin/jumpscript"

tmp_root="$(mktemp -d)"
trap 'rm -rf "${tmp_root}"' EXIT

fixture="${tmp_root}/hello.c"
cp "${repo_root}/tests/fixtures/hello.c" "${fixture}"
chmod +x "${fixture}"

cache_dir="${tmp_root}/cache"

( cd "${HOME}" && JUMPSCRIPT_CACHE="${cache_dir}" "${runner}" run C "${fixture}" >/tmp/abs_run.out )

if ! grep -q "C integration OK" /tmp/abs_run.out; then
	echo "Absolute path run failed" >&2
	cat /tmp/abs_run.out >&2
	exit 1
fi
