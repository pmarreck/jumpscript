#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}" )/.." && pwd)"

status=0
for stray in source.idr source.zig; do
	if [[ -e "${repo_root}/${stray}" ]]; then
		echo "found stray build artifact: ${stray}" >&2
		status=1
	fi
done

exit "${status}"
