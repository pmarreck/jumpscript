#!/usr/bin/env bash
# plugins/_lib/plugin_lib.bash replaces host tools in plugins with Bash
# builtins. Each helper is checked against the tool it replaces (grep -oE,
# cat), used here as an independent oracle over a set of inputs.
set -u

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${repo_root}/plugins/_lib/plugin_lib.bash"
failures=0
fail() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }

tmp_root="$(mktemp -d)"
trap 'rm -rf "${tmp_root}"' EXIT

# pl_matches ERE FILE == tail -n +2 FILE | grep -oE ERE, over files that mix
# matches with lines that only look similar.
patterns=(
	'#include "[^"]+"'
	'@import\("[^"]+"\)'
	'require "\./[^"]+"'
	'include "[^"]+"'
)
cat > "${tmp_root}/source" <<'EOF'
#include "first-line-is-skipped.h"
#include "a.h"
#include <stdio.h>
  #include "b.h" #include "c.h"
const x = @import("std"); const y = @import("./y.zig");
require "./lib/helper" ; require "json"
include "inc.nim"
#include "unterminated
no newline at end: @import("last.zig")
EOF
printf 'tail without newline #include "z.h"' >> "${tmp_root}/source"
printf '#!/x\n' > "${tmp_root}/only_shebang"
: > "${tmp_root}/empty"
for file in source only_shebang empty; do
	for re in "${patterns[@]}"; do
		want="$(tail -n +2 "${tmp_root}/${file}" | grep -oE "${re}")"
		got="$(pl_matches "${re}" "${tmp_root}/${file}")"
		[[ "${got}" == "${want}" ]] || fail "pl_matches '${re}' ${file}: got '${got}', want '${want}'"
	done
done

# pl_body FILE == tail -n +2 FILE (the script without its shebang line).
for file in source only_shebang empty; do
	want="$(tail -n +2 "${tmp_root}/${file}"; echo .)"
	got="$(pl_body "${tmp_root}/${file}"; echo .)"
	[[ "${got}" == "${want}" ]] || fail "pl_body ${file}: got '${got}', want '${want}'"
done

# pl_cat == cat for stdin, including a missing final newline and blank lines.
for input in $'a\nb\n' $'a\n\n\nb' '' $'x' $'tab\there  spaced  \n'; do
	want="$(printf '%s' "${input}" | cat; echo .)"
	got="$(printf '%s' "${input}" | pl_cat; echo .)"
	[[ "${got}" == "${want}" ]] || fail "pl_cat: got '${got}', want '${want}'"
done

# pl_heredoc VAR == "$(cat <<'X' ... X)": the text without its final newline.
pl_heredoc got <<'CMD'
nix develop __PLUGIN__#build --command bash -lc 'echo "$x" | tr a b'
second line
CMD
want="$(cat <<'CMD'
nix develop __PLUGIN__#build --command bash -lc 'echo "$x" | tr a b'
second line
CMD
)"
[[ "${got}" == "${want}" ]] || fail "pl_heredoc: got '${got}', want '${want}'"

if [[ ${failures} -ne 0 ]]; then
	echo "test_plugin_lib: ${failures} failed" >&2
	exit 1
fi
echo "test_plugin_lib: all passed"
