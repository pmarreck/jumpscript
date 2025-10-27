#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}" )/.." && pwd)"

if [[ ! -f "${repo_root}/.envrc" ]]; then
	echo "Expected .envrc at repo root" >&2
	exit 1
fi

direnv_path_output="$(
	(
		set -e
		cd "${repo_root}"
		# strip repo from PATH to ensure .envrc re-adds it
		export PATH="/usr/bin"
		source ./.envrc
		command -v jumpscript || true
	)
)"

if [[ "${direnv_path_output}" != "${repo_root}/jumpscript" ]]; then
	echo "Expected jumpscript on PATH after sourcing .envrc" >&2
	echo "got: ${direnv_path_output}" >&2
	exit 1
fi
