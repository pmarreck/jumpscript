#!/usr/bin/env bash
# The runner caches each plugin's meta answer and reuses it only while
# everything the answer may depend on is unchanged. A fake plugin logs every
# meta call, so each case asserts exactly when meta reran.
set -u

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${repo_root}/tests/lib/host.bash"
runner="${repo_root}/bin/jumpscript"
failures=0
fail() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }

tmp_root="$(mktemp -d)"
trap 'rm -rf "${tmp_root}"' EXIT

plugins="${tmp_root}/plugins"
state="${tmp_root}/state"
mkdir -p "${plugins}/Fake/default" "${state}"
# The plugin's answer depends on files the runner cannot see (state/deps,
# state/runtime_path), which is how each invalidation rule gets exercised.
cat > "${plugins}/Fake/default/plugin" <<'EOF'
#!/usr/bin/env bash
state="${FAKE_STATE:?}"
[[ "${1:-}" == meta ]] || exit 1
echo "meta ${JUMPSCRIPT_NO_RUNTIME_DEPS:-0}" >> "${state}/meta_calls"
[[ -f "${state}/fail_meta" ]] && { echo "meta refused" >&2; exit 3; }
echo "out_rel=bin/app"
echo "build_cmd=mkdir -p bin && printf '#!/usr/bin/env bash\necho \"fake %s \$#\"\n' \"\$(cat \"\$JUMPSCRIPT_SCRIPT\")\" > \"\$JUMPSCRIPT_ARTIFACT\" && chmod +x \"\$JUMPSCRIPT_ARTIFACT\" && echo build >> '${state}/builds'"
echo "rebuild_mode=mtime"
if [[ -f "${state}/runtime_path" ]]; then
	echo "exec_kind=text"
	echo "runtime_cmd=$(cat "${state}/runtime_path") {{artifact}}"
else
	echo "exec_kind=bin"
fi
[[ -f "${state}/deps" ]] && echo "deps=$(cat "${state}/deps")"
exit 0
EOF
chmod +x "${plugins}/Fake/default/plugin"

script="${tmp_root}/scripts/hello"
mkdir -p "${tmp_root}/scripts"
echo "v1" > "${script}"

calls() { if [[ -f "${state}/meta_calls" ]]; then wc -l < "${state}/meta_calls" | tr -d ' '; else echo 0; fi; }
builds() { if [[ -f "${state}/builds" ]]; then wc -l < "${state}/builds" | tr -d ' '; else echo 0; fi; }
run() {
	JUMPSCRIPT_PLUGINS_DIR="${plugins}" JUMPSCRIPT_USER_PLUGINS="${tmp_root}/no-user-plugins" \
		JUMPSCRIPT_CACHE="${tmp_root}/cache" FAKE_STATE="${state}" "${runner}" "$@" 2>"${tmp_root}/err"
}
# expect CASE OUTPUT_SUBSTRING META_CALLS BUILDS -- ARGS...
expect() {
	local name="$1" want_out="$2" want_calls="$3" want_builds="$4"
	shift 5
	local out
	out="$(run "$@")"
	local status=$?
	[[ ${status} -eq 0 && "${out}" == *"${want_out}"* ]] || fail "${name}: status ${status}, output '${out}', stderr '$(cat "${tmp_root}/err")'"
	[[ "$(calls)" == "${want_calls}" ]] || fail "${name}: ${want_calls} meta calls expected so far, got $(calls)"
	[[ "$(builds)" == "${want_builds}" ]] || fail "${name}: ${want_builds} builds expected so far, got $(builds)"
}

expect "first run" "fake v1 2" 1 1 -- Fake "${script}" a b
expect "warm run reuses meta and the build" "fake v1 0" 1 1 -- Fake "${script}"
FOO=bar expect "unrelated env leaves meta cached" "fake v1 0" 1 1 -- Fake "${script}"
JUMPSCRIPT_FAKE_SETTING=1 expect "a JUMPSCRIPT_* variable reruns meta" "fake v1 0" 2 1 -- Fake "${script}"
JUMPSCRIPT_FAKE_SETTING=1 expect "the same value is cached again" "fake v1 0" 2 1 -- Fake "${script}"
PATH="${PATH}:/nonexistent-dir" expect "PATH change" "fake v1 0" 3 1 -- Fake "${script}"
expect "--no-runtime-deps is a separate answer" "fake v1 0" 4 1 -- --no-runtime-deps Fake "${script}"
expect "and it is cached too" "fake v1 0" 4 1 -- --no-runtime-deps Fake "${script}"

set_mtime 1700000000 "${plugins}/Fake/default/plugin"
# The plugin files pin the toolchain (flake.nix, flake.lock), so a change
# there also rebuilds into a fresh entry: an artifact from an older pin may
# need store paths that garbage collection has since removed.
expect "a changed plugin file reruns meta and rebuilds" "fake v1 0" 5 2 -- Fake "${script}"
echo "extra" > "${plugins}/Fake/default/flake.nix"
expect "a new file in the plugin directory reruns meta and rebuilds" "fake v1 0" 6 3 -- Fake "${script}"
expect "the rebuilt entry is reused" "fake v1 0" 6 3 -- Fake "${script}"

echo "v2" > "${script}"
set_mtime 1800000000 "${script}"
expect "an edited script reruns meta and rebuilds" "fake v2 0" 7 4 -- Fake "${script}"

echo "helper" > "${tmp_root}/scripts/helper"
set_mtime 1800000000 "${tmp_root}/scripts/helper"
echo "helper" > "${state}/deps"
expect "declared deps are answered by a new meta" "fake v2 0" 7 4 -- Fake "${script}"
set_mtime 1800000001 "${script}"
expect "script touched again" "fake v2 0" 8 5 -- Fake "${script}"
expect "deps cached with the answer" "fake v2 0" 8 5 -- Fake "${script}"
set_mtime 1900000000 "${tmp_root}/scripts/helper"
expect "a changed dependency reruns meta and rebuilds" "fake v2 0" 9 6 -- Fake "${script}"

# A cached absolute runtime path that vanished (say, garbage-collected from
# the Nix store) sends the runner back to the plugin for a fresh answer.
rt1="${tmp_root}/rt1"
printf '#!/usr/bin/env bash\nexec bash "$@"\n' > "${rt1}"
chmod +x "${rt1}"
echo "${rt1}" > "${state}/runtime_path"
set_mtime 1900000001 "${script}"
expect "text runtime" "fake v2 0" 10 7 -- Fake "${script}"
expect "text runtime cached" "fake v2 0" 10 7 -- Fake "${script}"
rt2="${tmp_root}/rt2"
mv "${rt1}" "${rt2}"
echo "${rt2}" > "${state}/runtime_path"
expect "a vanished runtime reruns meta" "fake v2 0" 11 7 -- Fake "${script}"

# A failed meta call is reported and never cached.
touch "${state}/fail_meta"
set_mtime 1900000002 "${script}"
out="$(run Fake "${script}")"
status=$?
[[ ${status} -eq 3 && "$(cat "${tmp_root}/err")" == *"meta refused"* ]] || fail "failed meta: status ${status}, stderr '$(cat "${tmp_root}/err")'"
rm -f "${state}/fail_meta"
expect "after a failure meta runs again" "fake v2 0" 13 8 -- Fake "${script}"

if [[ ${failures} -ne 0 ]]; then
	echo "test_meta_cache: ${failures} failed" >&2
	exit 1
fi
echo "test_meta_cache: all passed"
