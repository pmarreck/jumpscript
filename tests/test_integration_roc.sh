#!/usr/bin/env bash
# Roc plugin: the double extension picks the backend (name.lua.roc -> LuaJIT,
# name.roc -> native). The compiler is JUMPSCRIPT_ROC or `roc` on PATH; it
# must be a Roc build with the LuaJIT backend for .lua.roc scripts.
set -u

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runner="${repo_root}/bin/jumpscript"
plugin="${repo_root}/plugins/Roc/default/plugin"
failures=0
fail() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }

tmp_root="$(mktemp -d)"
trap 'rm -rf "${tmp_root}"' EXIT

roc_bin="${JUMPSCRIPT_ROC:-$(command -v roc || true)}"
if [[ -z "${roc_bin}" || ! -x "${roc_bin}" ]]; then
	echo "FAIL: Roc integration test needs a Roc compiler (set JUMPSCRIPT_ROC or put roc on PATH)" >&2
	exit 1
fi
stub_roc="${tmp_root}/stub-roc"
printf '#!/usr/bin/env sh\nexit 0\n' > "${stub_roc}"
chmod +x "${stub_roc}"

# Backend classification over a set of script names, including dots in
# directories and names that only look like a double extension.
meta_field() { grep "^$2=" <<<"$1" | head -n 1 | cut -d= -f2-; }
names=(hello.lua.roc hello.roc my.lua/hello.roc a.b.roc lua.roc hello.lua.roc.roc)
kinds=(lua bin bin bin bin bin)
for i in "${!names[@]}"; do
	meta="$(JUMPSCRIPT_ROC="${stub_roc}" "${plugin}" meta "/scripts/${names[$i]}" 2>&1)"
	got="$(meta_field "${meta}" exec_kind)"
	[[ "${got}" == "${kinds[$i]}" ]] || fail "${names[$i]}: exec_kind '${got}', want '${kinds[$i]}' (${meta})"
done
meta="$(JUMPSCRIPT_ROC="${stub_roc}" "${plugin}" meta /scripts/hello.lua.roc)"
[[ "$(meta_field "${meta}" build_cmd)" == *"--target=luajit"* ]] || fail "lua.roc build must target luajit: ${meta}"
meta="$(JUMPSCRIPT_ROC="${stub_roc}" "${plugin}" meta /scripts/hello.roc)"
[[ "$(meta_field "${meta}" build_cmd)" != *"--target="* ]] || fail "native build must not set a target: ${meta}"

# .wasm.roc is reserved for the wasm32 backend, which needs a WASI host for
# headerless apps (roc builds them as an archive); until then it is an error,
# never a silent native build.
err="$(JUMPSCRIPT_ROC="${stub_roc}" "${plugin}" meta /scripts/hello.wasm.roc 2>&1 >/dev/null)"
status=$?
[[ ${status} -ne 0 && "${err}" == *"wasm"* ]] || fail "wasm.roc: status ${status}, stderr '${err}'"

# A missing compiler is a clear error, not a silent default.
err="$(JUMPSCRIPT_ROC="${tmp_root}/no-such-roc" "${plugin}" meta /scripts/hello.roc 2>&1 >/dev/null)"
status=$?
[[ ${status} -ne 0 && "${err}" == *"JUMPSCRIPT_ROC"* ]] || fail "missing compiler: status ${status}, stderr '${err}'"

# Real builds: run, then rerun from the cache with a compiler that would fail.
broken_roc="${tmp_root}/broken-roc"
printf '#!/usr/bin/env sh\necho "roc should not rerun" >&2\nexit 125\n' > "${broken_roc}"
chmod +x "${broken_roc}"
for script in hello.lua.roc hello.roc; do
	dir="${tmp_root}/${script}.d"
	mkdir -p "${dir}"
	cp "${repo_root}/tests/fixtures/${script}" "${dir}/${script}"
	out="$(JUMPSCRIPT_CACHE="${dir}/cache" JUMPSCRIPT_ROC="${roc_bin}" "${runner}" run --no-runtime-deps Roc "${dir}/${script}" a b c 2>"${dir}/err")"
	[[ "${out}" == *"Roc hello 3"* ]] || fail "${script}: output '${out}', stderr $(cat "${dir}/err")"
	out="$(JUMPSCRIPT_CACHE="${dir}/cache" JUMPSCRIPT_ROC="${broken_roc}" "${runner}" run --no-runtime-deps Roc "${dir}/${script}" a 2>"${dir}/err")"
	[[ "${out}" == *"Roc hello 1"* ]] || fail "${script} cached: output '${out}', stderr $(cat "${dir}/err")"
done

# Default runtime: LuaJIT from the plugin flake. PATH has no luajit here.
dir="${tmp_root}/flake.d"
mkdir -p "${dir}"
cp "${repo_root}/tests/fixtures/hello.lua.roc" "${dir}/hello.lua.roc"
out="$(PATH="$(dirname "$(command -v nix)"):$(dirname "$(command -v bash)"):$(dirname "$(command -v mkdir)")" JUMPSCRIPT_CACHE="${dir}/cache" JUMPSCRIPT_ROC="${roc_bin}" "${runner}" run Roc "${dir}/hello.lua.roc" x x 2>"${dir}/err")"
[[ "${out}" == *"Roc hello 2"* ]] || fail "flake luajit: output '${out}', stderr $(cat "${dir}/err")"

if [[ ${failures} -ne 0 ]]; then
	echo "test_integration_roc: ${failures} failed" >&2
	exit 1
fi
echo "test_integration_roc: all passed"
