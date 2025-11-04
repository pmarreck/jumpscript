#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runner="${repo_root}/jumpscript"

tmp_dirs=()
cleanup() {
	for dir in "${tmp_dirs[@]}"; do
		rm -rf "${dir}"
	done
}
trap cleanup EXIT

make_temp_dir() {
	local dir
	dir="$(mktemp -d)"
	tmp_dirs+=("${dir}")
	echo "${dir}"
}

test_wat_roundtrip() {
	cache_root="$(make_temp_dir)/cache"
	script_dir="$(make_temp_dir)"
	script_path="${script_dir}/hello.wat"

		cp "${repo_root}/tests/fixtures/hello.wat" "${script_path}"

	nix_bin="$(command -v nix || true)"
	if [[ -z "${nix_bin}" ]]; then
		echo "nix command not found; WAT integration test requires nix" >&2
		exit 1
	fi

	nix_dir="$(dirname "${nix_bin}")"
	fake_tools="$(make_temp_dir)"
	cat > "${fake_tools}/wat2wasm" <<'EOF_STUB'
#!/usr/bin/env bash
echo "fake wat2wasm invoked" >&2
exit 122
EOF_STUB
	chmod +x "${fake_tools}/wat2wasm"

	output="$(
		PATH="${fake_tools}:${nix_dir}:/bin" \
		JUMPSCRIPT_CACHE="${cache_root}" \
		"${runner}" run Wat "${script_path}"
	)"

	if [[ "${output}" != *"WAT hello"* ]]; then
		echo "Expected WAT runtime output not found" >&2
		printf "%s\n" "${output}" >&2
		exit 1
	fi

	cat > "${fake_tools}/wat2wasm" <<'EOF_STUB_FAIL'
#!/usr/bin/env bash
echo "wat2wasm should not rerun" >&2
exit 125
EOF_STUB_FAIL
	chmod +x "${fake_tools}/wat2wasm"

	second_output="$(
		PATH="${fake_tools}:${nix_dir}:/bin" \
		JUMPSCRIPT_CACHE="${cache_root}" \
		"${runner}" run Wat "${script_path}"
	)"

	if [[ "${second_output}" != *"WAT hello"* ]]; then
		echo "Expected cached WAT run to succeed" >&2
		printf "%s\n" "${second_output}" >&2
		exit 1
	fi
}

test_wat_roundtrip

test_wat_no_deps_shortcuts() {
	cache_root="$(make_temp_dir)/cache"
	script_dir="$(make_temp_dir)"
	script_path="${script_dir}/hello_no_deps.wat"

	cp "${repo_root}/tests/fixtures/hello.wat" "${script_path}"

	stub_dir="$(make_temp_dir)"
cat > "${stub_dir}/wat2wasm" <<'EOF_WAT2WASM'
#!/usr/bin/env sh
touch "$(dirname "$0")/wat2wasm-invoked"
out=""
prev=""
for arg in "$@"; do
	if [ "${prev}" = "-o" ]; then
		out="${arg}"
		break
	fi
	if [ "${arg}" = "-o" ]; then
		prev="-o"
	else
		prev="${arg}"
	fi
done
if [ -z "${out}" ]; then
	out="$3"
fi
printf '\0\0\0\0' > "${out}"
EOF_WAT2WASM
chmod +x "${stub_dir}/wat2wasm"

cat > "${stub_dir}/wazero" <<'EOF_WAZERO'
#!/usr/bin/env sh
echo "host wazero"
EOF_WAZERO
chmod +x "${stub_dir}/wazero"

	bash_dir="$(dirname "$(command -v bash)")"
	output="$(
		PATH="${stub_dir}:${bash_dir}" \
		JUMPSCRIPT_CACHE="${cache_root}" \
		"${runner}" run --no-deps Wat "${script_path}"
	)"

	if [[ "${output}" != *"host wazero"* ]]; then
		echo "Expected host wazero output" >&2
		printf "%s\n" "${output}" >&2
		exit 1
	fi

	if [[ ! -f "${stub_dir}/wat2wasm-invoked" ]]; then
		echo "wat2wasm stub was not invoked for --no-deps build" >&2
		exit 1
	fi
}

test_wat_no_deps_shortcuts
