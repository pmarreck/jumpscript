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

# .wasm.roc scripts build against a WASI copy of basic-cli 0.23.0 (a
# directory holding its main.roc), named by JUMPSCRIPT_ROC_WASI_PLATFORM.
wasi_platform="${JUMPSCRIPT_ROC_WASI_PLATFORM:-}"
if [[ -z "${wasi_platform}" || ! -f "${wasi_platform}/main.roc" ]]; then
	echo "FAIL: Roc integration test needs a WASI basic-cli platform directory in JUMPSCRIPT_ROC_WASI_PLATFORM (got '${wasi_platform}')" >&2
	exit 1
fi
stub_platform="${tmp_root}/stub-platform"
mkdir -p "${stub_platform}"
: > "${stub_platform}/main.roc"

# Backend classification over a set of script names, including dots in
# directories and names that only look like a double extension.
meta_field() { grep "^$2=" <<<"$1" | head -n 1 | cut -d= -f2-; }
names=(hello.lua.roc hello.roc my.lua/hello.roc a.b.roc lua.roc hello.lua.roc.roc hello.wasm.roc my.wasm/hello.roc wasm.roc hello.wasm.roc.roc hello.lua.wasm.roc)
kinds=(lua bin bin bin bin bin wasm bin bin bin wasm)
for i in "${!names[@]}"; do
	meta="$(JUMPSCRIPT_ROC="${stub_roc}" JUMPSCRIPT_ROC_WASI_PLATFORM="${stub_platform}" "${plugin}" meta "/scripts/${names[$i]}" 2>&1)"
	got="$(meta_field "${meta}" exec_kind)"
	[[ "${got}" == "${kinds[$i]}" ]] || fail "${names[$i]}: exec_kind '${got}', want '${kinds[$i]}' (${meta})"
done
meta="$(JUMPSCRIPT_ROC="${stub_roc}" "${plugin}" meta /scripts/hello.lua.roc)"
[[ "$(meta_field "${meta}" build_cmd)" == *"--target=luajit"* ]] || fail "lua.roc build must target luajit: ${meta}"
meta="$(JUMPSCRIPT_ROC="${stub_roc}" "${plugin}" meta /scripts/hello.roc)"
[[ "$(meta_field "${meta}" build_cmd)" != *"--target="* ]] || fail "native build must not set a target: ${meta}"

basic_cli_url="https://github.com/roc-lang/basic-cli/releases/download/0.23.0/GNN5tt2gKdX4dhawg4915C4YB193woHFdcCkz31fhGxv.tar.zst"
meta="$(JUMPSCRIPT_ROC="${stub_roc}" JUMPSCRIPT_ROC_WASI_PLATFORM="${stub_platform}" "${plugin}" meta /scripts/hello.wasm.roc)"
build_cmd="$(meta_field "${meta}" build_cmd)"
[[ "${build_cmd}" == *"--target=wasm32"* ]] || fail "wasm.roc build must target wasm32: ${meta}"
[[ "${build_cmd}" == *"--replace-dep ${basic_cli_url} '${stub_platform}/main.roc'"* ]] || fail "wasm.roc build must replace basic-cli with the WASI platform: ${meta}"
[[ "$(meta_field "${meta}" out_rel)" == "wasm/hello.wasm" ]] || fail "wasm.roc out_rel: ${meta}"
[[ "$(meta_field "${meta}" runtime_cmd)" == *"wasmtime run -S inherit-env=y --dir=/ {{artifact}}" ]] || fail "wasm.roc runtime: ${meta}"

# Without a WASI platform, .wasm.roc is a clear error, never a native build.
for platform in "" "${tmp_root}/no-such-platform"; do
	err="$(JUMPSCRIPT_ROC="${stub_roc}" JUMPSCRIPT_ROC_WASI_PLATFORM="${platform}" "${plugin}" meta /scripts/hello.wasm.roc 2>&1 >/dev/null)"
	status=$?
	[[ ${status} -ne 0 && "${err}" == *"JUMPSCRIPT_ROC_WASI_PLATFORM"* ]] || fail "wasm.roc without platform '${platform}': status ${status}, stderr '${err}'"
done

# A missing compiler is a clear error, not a silent default.
err="$(JUMPSCRIPT_ROC="${tmp_root}/no-such-roc" "${plugin}" meta /scripts/hello.roc 2>&1 >/dev/null)"
status=$?
[[ ${status} -ne 0 && "${err}" == *"JUMPSCRIPT_ROC"* ]] || fail "missing compiler: status ${status}, stderr '${err}'"

# Real builds: run, then rerun from the cache with a compiler that would fail.
broken_roc="${tmp_root}/broken-roc"
printf '#!/usr/bin/env sh\necho "roc should not rerun" >&2\nexit 125\n' > "${broken_roc}"
chmod +x "${broken_roc}"
for script in hello.lua.roc hello.roc hello.wasm.roc; do
	dir="${tmp_root}/${script}.d"
	mkdir -p "${dir}"
	cp "${repo_root}/tests/fixtures/${script}" "${dir}/${script}"
	out="$(JUMPSCRIPT_CACHE="${dir}/cache" JUMPSCRIPT_ROC="${roc_bin}" JUMPSCRIPT_ROC_WASI_PLATFORM="${wasi_platform}" "${runner}" run --no-runtime-deps Roc "${dir}/${script}" a b c 2>"${dir}/err")"
	[[ "${out}" == *"Roc hello 3"* ]] || fail "${script}: output '${out}', stderr $(cat "${dir}/err")"
	out="$(JUMPSCRIPT_CACHE="${dir}/cache" JUMPSCRIPT_ROC="${broken_roc}" JUMPSCRIPT_ROC_WASI_PLATFORM="${wasi_platform}" "${runner}" run --no-runtime-deps Roc "${dir}/${script}" a 2>"${dir}/err")"
	[[ "${out}" == *"Roc hello 1"* ]] || fail "${script} cached: output '${out}', stderr $(cat "${dir}/err")"
done

# Default runtimes come from the plugin flake (a store path), never from PATH,
# which may well hold its own luajit or wasmtime.
for spec in "hello.lua.roc:luajit" "hello.wasm.roc:wasmtime"; do
	script="${spec%%:*}"
	tool="${spec##*:}"
	meta="$(JUMPSCRIPT_ROC="${stub_roc}" JUMPSCRIPT_ROC_WASI_PLATFORM="${stub_platform}" "${plugin}" meta "/scripts/${script}" 2>&1)"
	[[ "$(meta_field "${meta}" runtime_cmd)" == /nix/store/*"/bin/${tool} "* ]] || fail "${script}: default runtime must be the flake ${tool}: ${meta}"
	dir="${tmp_root}/flake-${script}.d"
	mkdir -p "${dir}"
	cp "${repo_root}/tests/fixtures/${script}" "${dir}/${script}"
	out="$(JUMPSCRIPT_CACHE="${dir}/cache" JUMPSCRIPT_ROC="${roc_bin}" JUMPSCRIPT_ROC_WASI_PLATFORM="${wasi_platform}" "${runner}" run Roc "${dir}/${script}" x x 2>"${dir}/err")"
	[[ "${out}" == *"Roc hello 2"* ]] || fail "flake ${tool}: output '${out}', stderr $(cat "${dir}/err")"
done

if [[ ${failures} -ne 0 ]]; then
	echo "test_integration_roc: ${failures} failed" >&2
	exit 1
fi
echo "test_integration_roc: all passed"
