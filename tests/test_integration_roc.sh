#!/usr/bin/env bash
# Roc plugin: the shebang token or the double extension picks the backend
# (native, LuaJIT, wasm). The compiler (Roc with the LuaJIT backend) and the
# WASI basic-cli platform come from the plugin's flake; JUMPSCRIPT_ROC and
# JUMPSCRIPT_ROC_WASI_PLATFORM override them. Real runs use a PATH holding
# only nix and bash, so nothing Roc-related may come from the host.
set -u

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${repo_root}/tests/lib/host.bash"
runner="${repo_root}/bin/jumpscript"
plugin="${repo_root}/plugins/Roc/default/plugin"
failures=0
fail() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }

tmp_root="$(mktemp -d)"
trap 'rm -rf "${tmp_root}"' EXIT

unset JUMPSCRIPT_ROC JUMPSCRIPT_ROC_WASI_PLATFORM
host_dir="$(minimal_host_dir "${tmp_root}" "$(command -v nix)")"
stub_roc="${tmp_root}/stub-roc"
printf '#!/usr/bin/env bash\nexit 0\n' > "${stub_roc}"
chmod +x "${stub_roc}"

basic_cli_url="https://github.com/roc-lang/basic-cli/releases/download/0.23.0/GNN5tt2gKdX4dhawg4915C4YB193woHFdcCkz31fhGxv.tar.zst"
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

# Extensionless scripts name the backend in the shebang (jumpscript Roc,
# Roc-luajit, Roc-wasm: plugins/Roc/<variant>). Classified over the cross
# product of variants and names: a named backend overrides plain names, plain
# Roc defers to a double extension, and a contradiction is an error ("!").
variants=(default luajit wasm)
v_names=(hello hello.roc hello.lua.roc hello.wasm.roc my.lua/hello my.wasm/hello.roc)
v_kinds_default=(bin bin lua wasm bin bin)
v_kinds_luajit=(lua lua lua '!' lua lua)
v_kinds_wasm=(wasm wasm '!' wasm wasm wasm)
for variant in "${variants[@]}"; do
	variant_plugin="${repo_root}/plugins/Roc/${variant}/plugin"
	kinds_var="v_kinds_${variant}[@]"
	want_kinds=("${!kinds_var}")
	for i in "${!v_names[@]}"; do
		name="${v_names[$i]}"
		want="${want_kinds[$i]}"
		meta="$(JUMPSCRIPT_ROC="${stub_roc}" JUMPSCRIPT_ROC_WASI_PLATFORM="${stub_platform}" "${variant_plugin}" meta "/scripts/${name}" 2>"${tmp_root}/variant.err")"
		status=$?
		err="$(cat "${tmp_root}/variant.err")"
		if [[ "${want}" == "!" ]]; then
			[[ ${status} -ne 0 && "${err}" == *"Roc-${variant}"* && "${err}" == *"${name}"* ]] || fail "Roc-${variant} ${name}: want a conflict error, got status ${status}, stderr '${err}', meta '${meta}'"
		else
			got="$(meta_field "${meta}" exec_kind)"
			[[ ${status} -eq 0 && "${got}" == "${want}" ]] || fail "Roc-${variant} ${name}: exec_kind '${got}', want '${want}' (status ${status}, stderr '${err}')"
		fi
	done
done
# Artifact names drop whichever Roc suffix the script has, if any.
for spec in "default:hello:bin/hello" "luajit:hello:lua/hello.lua" "luajit:hello.roc:lua/hello.lua" "wasm:hello:wasm/hello.wasm" "wasm:hello.roc:wasm/hello.wasm"; do
	IFS=: read -r variant name want <<<"${spec}"
	meta="$(JUMPSCRIPT_ROC="${stub_roc}" JUMPSCRIPT_ROC_WASI_PLATFORM="${stub_platform}" "${repo_root}/plugins/Roc/${variant}/plugin" meta "/scripts/${name}" 2>&1)"
	[[ "$(meta_field "${meta}" out_rel)" == "${want}" ]] || fail "Roc-${variant} ${name}: out_rel want '${want}': ${meta}"
done

meta="$(JUMPSCRIPT_ROC="${stub_roc}" JUMPSCRIPT_ROC_WASI_PLATFORM="${stub_platform}" "${plugin}" meta /scripts/hello.wasm.roc)"
build_cmd="$(meta_field "${meta}" build_cmd)"
[[ "${build_cmd}" == *"--target=wasm32"* ]] || fail "wasm.roc build must target wasm32: ${meta}"
[[ "${build_cmd}" == *"--replace-dep ${basic_cli_url} '${stub_platform}/main.roc'"* ]] || fail "wasm.roc build must replace basic-cli with the WASI platform: ${meta}"
[[ "$(meta_field "${meta}" out_rel)" == "wasm/hello.wasm" ]] || fail "wasm.roc out_rel: ${meta}"
[[ "$(meta_field "${meta}" runtime_cmd)" == *"wasmtime run -S inherit-env=y --dir=/ {{artifact}}" ]] || fail "wasm.roc runtime: ${meta}"

# By default the compiler and the WASI platform are the flake's (store paths).
meta="$(PATH="${host_dir}" "${plugin}" meta /scripts/hello.wasm.roc 2>"${tmp_root}/flake.err")"
build_cmd="$(meta_field "${meta}" build_cmd)"
[[ "${build_cmd}" == "'/nix/store/"*"/bin/roc' build --target=wasm32"* ]] || fail "default compiler must be the flake's roc: '${build_cmd}' ($(cat "${tmp_root}/flake.err"))"
[[ "${build_cmd}" == *"--replace-dep ${basic_cli_url} '/nix/store/"*"wasi-basic-cli"*"/main.roc'"* ]] || fail "default WASI platform must be the flake's: '${build_cmd}'"

# An override that does not exist is a clear error, never a fallback.
err="$(JUMPSCRIPT_ROC="${stub_roc}" JUMPSCRIPT_ROC_WASI_PLATFORM="${tmp_root}/no-such-platform" "${plugin}" meta /scripts/hello.wasm.roc 2>&1 >/dev/null)"
status=$?
[[ ${status} -ne 0 && "${err}" == *"JUMPSCRIPT_ROC_WASI_PLATFORM"* ]] || fail "missing platform override: status ${status}, stderr '${err}'"
err="$(JUMPSCRIPT_ROC="${tmp_root}/no-such-roc" "${plugin}" meta /scripts/hello.roc 2>&1 >/dev/null)"
status=$?
[[ ${status} -ne 0 && "${err}" == *"JUMPSCRIPT_ROC"* ]] || fail "missing compiler override: status ${status}, stderr '${err}'"
# --no-build-deps means the host's roc; without one on PATH that is an error.
err="$(PATH="${host_dir}" JUMPSCRIPT_NO_BUILD_DEPS=1 "${plugin}" meta /scripts/hello.roc 2>&1 >/dev/null)"
status=$?
[[ ${status} -ne 0 && "${err}" == *"roc"* && "${err}" == *"--no-build-deps"* ]] || fail "no-build-deps without host roc: status ${status}, stderr '${err}'"

# Real builds: run, then rerun from the cache. A rerun must not write any
# cache file except meta.env (rewritten on every run): same files, same inodes.
# (Swapping in a failing compiler would not prove reuse: a different compiler
# is a different toolchain and rightly rebuilds.)
cache_files() { find "$1" -type f ! -name meta.env -exec ls -i {} + | sort; }
for script in hello.lua.roc hello.roc hello.wasm.roc; do
	dir="${tmp_root}/${script}.d"
	mkdir -p "${dir}"
	cp "${repo_root}/tests/fixtures/${script}" "${dir}/${script}"
	out="$(PATH="${host_dir}" JUMPSCRIPT_CACHE="${dir}/cache" "${runner}" run Roc "${dir}/${script}" a b c 2>"${dir}/err")"
	[[ "${out}" == *"Roc hello 3"* ]] || fail "${script}: output '${out}', stderr $(cat "${dir}/err")"
	before="$(cache_files "${dir}/cache")"
	out="$(PATH="${host_dir}" JUMPSCRIPT_CACHE="${dir}/cache" "${runner}" run Roc "${dir}/${script}" a 2>"${dir}/err")"
	[[ "${out}" == *"Roc hello 1"* ]] || fail "${script} cached: output '${out}', stderr $(cat "${dir}/err")"
	[[ "$(cache_files "${dir}/cache")" == "${before}" ]] || fail "${script} cached: the rerun rewrote cache files"
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
	out="$(PATH="${host_dir}" JUMPSCRIPT_CACHE="${dir}/cache" "${runner}" run Roc "${dir}/${script}" x x 2>"${dir}/err")"
	[[ "${out}" == *"Roc hello 2"* ]] || fail "flake ${tool}: output '${out}', stderr $(cat "${dir}/err")"
done

# Extensionless executables run directly through their shebang, one per
# backend, with jumpscript found on PATH.
for spec in "hello.roc:Roc" "hello.lua.roc:Roc-luajit" "hello.wasm.roc:Roc-wasm"; do
	fixture="${spec%%:*}"
	token="${spec##*:}"
	dir="${tmp_root}/shebang-${token}.d"
	mkdir -p "${dir}"
	{
		printf '#!/usr/bin/env -S jumpscript %s\n' "${token}"
		tail -n +2 "${repo_root}/tests/fixtures/${fixture}"
	} > "${dir}/hello"
	chmod +x "${dir}/hello"
	out="$(PATH="${repo_root}/bin:${host_dir}" JUMPSCRIPT_CACHE="${dir}/cache" "${dir}/hello" p q r s 2>"${dir}/err")"
	[[ "${out}" == *"Roc hello 4"* ]] || fail "extensionless ${token}: output '${out}', stderr $(cat "${dir}/err")"
done

if [[ ${failures} -ne 0 ]]; then
	echo "test_integration_roc: ${failures} failed" >&2
	exit 1
fi
echo "test_integration_roc: all passed"
