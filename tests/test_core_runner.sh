#!/usr/bin/env bash
set -eo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runner="${repo_root}/bin/jumpscript"

fail() {
	echo "FAIL: $1" >&2
	exit 1
}

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

test_missing_script_path() {
	missing="${repo_root}/tests/fixtures/does_not_exist.c"

	set +e
	output="$("${runner}" run C "${missing}" 2>&1)"
	status=$?
	set -e

	expected_msg="Error: script '${missing}' not found"

	if [[ "${status}" -eq 0 ]]; then
		fail "expected non-zero exit status for missing script"
	fi

	if [[ "${output}" != *"${expected_msg}"* ]]; then
		printf 'Expected error message containing:\n%s\nGot:\n%s\n' "${expected_msg}" "${output}" >&2
		exit 1
	fi
}

test_missing_plugin_error_message() {
	if [[ ! -x "${runner}" ]]; then
		echo "NOTE: ${runner} not found or not executable; expected failure path will differ." >&2
	fi

	tmp_plugins="$(make_temp_dir)"
	cache_root="$(make_temp_dir)/cache"

	set +e
	output="$(JUMPSCRIPT_PLUGINS_DIR="${tmp_plugins}" JUMPSCRIPT_CACHE="${cache_root}" "${runner}" run C "${repo_root}/tests/fixtures/hello.c" 2>&1)"
	status=$?
	set -e

	default_user_plugins="${XDG_DATA_HOME:-${HOME}/.local/share}/jumpscript/plugins"
	expected_msg="Error: plugin not found for language 'C' version 'default' (searched: ${default_user_plugins},${tmp_plugins})"

	if [[ "${status}" -eq 0 ]]; then
		fail "expected non-zero exit status when plugin directory is missing"
	fi

	if [[ "${output}" != *"${expected_msg}"* ]]; then
		printf 'Expected error message containing:\n%s\nGot:\n%s\n' "${expected_msg}" "${output}" >&2
		exit 1
	fi
}

test_missing_plugin_executable() {
	tmp_plugins="$(make_temp_dir)"
	mkdir -p "${tmp_plugins}/C/default"

	set +e
	output="$(JUMPSCRIPT_PLUGINS_DIR="${tmp_plugins}" "${runner}" run C "${repo_root}/tests/fixtures/hello.c" 2>&1)"
	status=$?
	set -e

	expected_exec="${tmp_plugins}/C/default/plugin"
	expected_msg="Error: plugin executable not found at ${expected_exec}"

	if [[ "${status}" -eq 0 ]]; then
		fail "expected non-zero exit status when plugin executable is missing"
	fi

	if [[ "${output}" != *"${expected_msg}"* ]]; then
		printf 'Expected error message containing:\n%s\nGot:\n%s\n' "${expected_msg}" "${output}" >&2
		exit 1
	fi
}

test_plugin_meta_failure() {
	tmp_plugins="$(make_temp_dir)"
	mkdir -p "${tmp_plugins}/C/default"

	cat > "${tmp_plugins}/C/default/plugin" <<'EOF'
#!/usr/bin/env bash
set -eo pipefail

case "${1:-}" in
	meta)
		echo "meta failure" >&2
		exit 5
		;;
	*)
		echo "unsupported" >&2
		exit 1
		;;
esac
EOF
	chmod +x "${tmp_plugins}/C/default/plugin"

	set +e
	output="$(JUMPSCRIPT_PLUGINS_DIR="${tmp_plugins}" "${runner}" run C "${repo_root}/tests/fixtures/hello.c" 2>&1)"
	status=$?
	set -e

	expected_msg="Error: plugin 'C' meta command failed with exit code 5"

	if [[ "${status}" -ne 5 ]]; then
		fail "expected exit status 5 when plugin meta fails, got ${status}"
	fi

	if [[ "${output}" != *"${expected_msg}"* ]]; then
		printf 'Expected error message containing:\n%s\nGot:\n%s\n' "${expected_msg}" "${output}" >&2
		exit 1
	fi
}

test_plugin_meta_missing_field() {
	tmp_plugins="$(make_temp_dir)"
	mkdir -p "${tmp_plugins}/C/default"

	cat > "${tmp_plugins}/C/default/plugin" <<'EOF'
#!/usr/bin/env bash
set -eo pipefail

case "${1:-}" in
		meta)
			cat <<'META'
build_cmd=echo build
rebuild_mode=mtime
exec_kind=bin
META
		exit 0
		;;
	*)
		echo "unsupported" >&2
		exit 1
		;;
esac
EOF
	chmod +x "${tmp_plugins}/C/default/plugin"

	set +e
	output="$(JUMPSCRIPT_PLUGINS_DIR="${tmp_plugins}" "${runner}" run C "${repo_root}/tests/fixtures/hello.c" 2>&1)"
	status=$?
	set -e

	expected_status=1
	expected_msg="Error: plugin 'C' meta output missing required field 'out_rel'"

	if [[ "${status}" -ne "${expected_status}" ]]; then
		fail "expected exit status ${expected_status} when meta missing field, got ${status}"
	fi

	if [[ "${output}" != *"${expected_msg}"* ]]; then
		printf 'Expected error message containing:\n%s\nGot:\n%s\n' "${expected_msg}" "${output}" >&2
		exit 1
	fi
}

test_plugin_meta_unsupported_rebuild_mode() {
	tmp_plugins="$(make_temp_dir)"
	mkdir -p "${tmp_plugins}/C/default"

	cat > "${tmp_plugins}/C/default/plugin" <<'EOF'
#!/usr/bin/env bash
set -eo pipefail

case "${1:-}" in
		meta)
			cat <<'META'
out_rel=hello
build_cmd=echo build
rebuild_mode=hash
exec_kind=bin
META
		exit 0
		;;
	*)
		echo "unsupported" >&2
		exit 1
		;;
esac
EOF
	chmod +x "${tmp_plugins}/C/default/plugin"

	set +e
	output="$(JUMPSCRIPT_PLUGINS_DIR="${tmp_plugins}" "${runner}" run C "${repo_root}/tests/fixtures/hello.c" 2>&1)"
	status=$?
	set -e

	expected_status=1
	expected_msg="Error: plugin 'C' requested unsupported rebuild_mode 'hash'"

	if [[ "${status}" -ne "${expected_status}" ]]; then
		fail "expected exit status ${expected_status} for unsupported rebuild mode, got ${status}"
	fi

	if [[ "${output}" != *"${expected_msg}"* ]]; then
		printf 'Expected error message containing:\n%s\nGot:\n%s\n' "${expected_msg}" "${output}" >&2
		exit 1
	fi
}

test_plugin_meta_unsupported_exec_kind() {
	tmp_plugins="$(make_temp_dir)"
	mkdir -p "${tmp_plugins}/C/default"

	cat > "${tmp_plugins}/C/default/plugin" <<'EOF'
#!/usr/bin/env bash
set -eo pipefail

case "${1:-}" in
	meta)
		cat <<'META'
out_rel=hello
build_cmd=echo build
rebuild_mode=mtime
exec_kind=unknown
META
		exit 0
		;;
	*)
		echo "unsupported" >&2
		exit 1
		;;
esac
EOF
	chmod +x "${tmp_plugins}/C/default/plugin"

	set +e
	output="$(JUMPSCRIPT_PLUGINS_DIR="${tmp_plugins}" "${runner}" run C "${repo_root}/tests/fixtures/hello.c" 2>&1)"
	status=$?
	set -e

	expected_msg="Error: plugin 'C' reported unsupported exec_kind 'unknown'"

	if [[ "${status}" -eq 0 ]]; then
		fail "expected failure for unsupported exec_kind"
	fi

	if [[ "${output}" != *"${expected_msg}"* ]]; then
		printf 'Expected error message containing:\n%s\nGot:\n%s\n' "${expected_msg}" "${output}" >&2
		exit 1
	fi
}

test_cache_root_created_with_secure_perms() {
	tmp_plugins="$(make_temp_dir)"
	mkdir -p "${tmp_plugins}/C/default"

cat > "${tmp_plugins}/C/default/plugin" <<'EOF'
#!/usr/bin/env bash
set -eo pipefail

case "${1:-}" in
	meta)
		cat <<'META'
out_rel=hello
build_cmd=printf '%s\n' '#!/usr/bin/env bash' 'exit 0' '# built marker' > "$JUMPSCRIPT_ARTIFACT"; chmod +x "$JUMPSCRIPT_ARTIFACT"
rebuild_mode=mtime
exec_kind=bin
META
		exit 0
		;;
	*)
		echo "unsupported" >&2
		exit 1
		;;
esac
EOF
	chmod +x "${tmp_plugins}/C/default/plugin"

	tmp_cache_parent="$(make_temp_dir)"
	cache_root="${tmp_cache_parent}/cache"
	rm -f "${cache_root}"

	set +e
	JUMPSCRIPT_PLUGINS_DIR="${tmp_plugins}" \
	JUMPSCRIPT_CACHE="${cache_root}" \
	"${runner}" run C "${repo_root}/tests/fixtures/hello.c" >/dev/null 2>&1
	status=$?
	set -e

	if [[ "${status}" -ne 0 ]]; then
		fail "expected runner to succeed when creating cache root; got ${status}"
	fi

	if [[ ! -d "${cache_root}" ]]; then
		fail "expected cache root ${cache_root} to be created"
	fi

	perm=""
	if perm=$(stat -c %a "${cache_root}" 2>/dev/null); then
		:
	elif perm=$(stat -f %Lp "${cache_root}" 2>/dev/null); then
		:
	else
		fail "could not determine permissions for ${cache_root}"
	fi

	if [[ "${perm}" != "700" ]]; then
		fail "expected cache root permissions 700, got ${perm}"
	fi
}

test_cache_lang_version_directory_created() {
	tmp_plugins="$(make_temp_dir)"
	mkdir -p "${tmp_plugins}/C/default"

	cat > "${tmp_plugins}/C/default/plugin" <<'EOF'
#!/usr/bin/env bash
set -eo pipefail

case "${1:-}" in
	meta)
		cat <<'META'
out_rel=hello
build_cmd=printf '%s\n' '#!/usr/bin/env bash' 'exit 0' '# built marker' > "$JUMPSCRIPT_ARTIFACT"; chmod +x "$JUMPSCRIPT_ARTIFACT"
rebuild_mode=mtime
exec_kind=bin
META
		exit 0
		;;
	*)
		echo "unsupported" >&2
		exit 1
		;;
esac
EOF
	chmod +x "${tmp_plugins}/C/default/plugin"

	cache_root="$(make_temp_dir)/cache"

	set +e
	JUMPSCRIPT_PLUGINS_DIR="${tmp_plugins}" \
	JUMPSCRIPT_CACHE="${cache_root}" \
	"${runner}" run C "${repo_root}/tests/fixtures/hello.c" >/dev/null 2>&1
	status=$?
	set -e

	if [[ "${status}" -ne 0 ]]; then
		fail "runner should succeed when creating language/version directory"
	fi

	if [[ ! -d "${cache_root}/C/default" ]]; then
		fail "expected ${cache_root}/C/default directory to be created"
	fi
}

test_cache_entry_directory_created() {
	tmp_plugins="$(make_temp_dir)"
	mkdir -p "${tmp_plugins}/C/default"

	cat > "${tmp_plugins}/C/default/plugin" <<'EOF'
#!/usr/bin/env bash
set -eo pipefail

case "${1:-}" in
	meta)
		cat <<'META'
out_rel=hello
build_cmd=printf '%s\n' '#!/usr/bin/env bash' 'exit 0' '# built marker' > "$JUMPSCRIPT_ARTIFACT"; chmod +x "$JUMPSCRIPT_ARTIFACT"
rebuild_mode=mtime
exec_kind=bin
META
		exit 0
		;;
	*)
		echo "unsupported" >&2
		exit 1
		;;
esac
EOF
	chmod +x "${tmp_plugins}/C/default/plugin"

	cache_root="$(make_temp_dir)/cache"

	set +e
	JUMPSCRIPT_PLUGINS_DIR="${tmp_plugins}" \
	JUMPSCRIPT_CACHE="${cache_root}" \
	"${runner}" run C "${repo_root}/tests/fixtures/hello.c" >/dev/null 2>&1
	status=$?
	set -e

	if [[ "${status}" -ne 0 ]]; then
		fail "runner should succeed when creating entry directory"
	fi

	version_dir="${cache_root}/C/default"
	mapfile -t entries < <(find "${version_dir}" -mindepth 1 -maxdepth 1 -type d)

	if [[ "${#entries[@]}" -ne 1 ]]; then
		fail "expected exactly one cache entry directory, found ${#entries[@]}"
	fi
}

test_meta_file_written() {
	tmp_plugins="$(make_temp_dir)"
	mkdir -p "${tmp_plugins}/C/default"

	cat > "${tmp_plugins}/C/default/plugin" <<'EOF'
#!/usr/bin/env bash
set -eo pipefail

case "${1:-}" in
	meta)
		cat <<'META'
out_rel=hello
build_cmd=printf '%s\n' '#!/usr/bin/env bash' 'exit 0' '# built marker' > "$JUMPSCRIPT_ARTIFACT"; chmod +x "$JUMPSCRIPT_ARTIFACT"
rebuild_mode=mtime
exec_kind=bin
META
		exit 0
		;;
	*)
		echo "unsupported" >&2
		exit 1
		;;
esac
EOF
	chmod +x "${tmp_plugins}/C/default/plugin"

	cache_root="$(make_temp_dir)/cache"

	set +e
	JUMPSCRIPT_PLUGINS_DIR="${tmp_plugins}" \
	JUMPSCRIPT_CACHE="${cache_root}" \
	"${runner}" run C "${repo_root}/tests/fixtures/hello.c" >/dev/null 2>&1
	status=$?
	set -e

	if [[ "${status}" -ne 0 ]]; then
		fail "runner should succeed when writing meta file"
	fi

	version_dir="${cache_root}/C/default"
	mapfile -t entries < <(find "${version_dir}" -mindepth 1 -maxdepth 1 -type d)
	if [[ "${#entries[@]}" -ne 1 ]]; then
		fail "expected exactly one cache entry directory, found ${#entries[@]}"
	fi

	meta_path="${entries[0]}/meta.env"

	if [[ ! -f "${meta_path}" ]]; then
		fail "expected meta file ${meta_path} to exist"
	fi

	if ! grep -q '^out_rel=hello$' "${meta_path}"; then
		fail "meta file missing expected out_rel entry"
	fi
}

test_out_rel_must_stay_within_entry() {
	tmp_plugins="$(make_temp_dir)"
	mkdir -p "${tmp_plugins}/C/default"

	cat > "${tmp_plugins}/C/default/plugin" <<'EOF'
#!/usr/bin/env bash
set -eo pipefail

case "${1:-}" in
	meta)
		cat <<'META'
out_rel=../evil
build_cmd=echo build
rebuild_mode=mtime
exec_kind=bin
META
		exit 0
		;;
	*)
		echo "unsupported" >&2
		exit 1
		;;
esac
EOF
	chmod +x "${tmp_plugins}/C/default/plugin"

	cache_root="$(make_temp_dir)/cache"

	set +e
	output="$(JUMPSCRIPT_PLUGINS_DIR="${tmp_plugins}" JUMPSCRIPT_CACHE="${cache_root}" "${runner}" run C "${repo_root}/tests/fixtures/hello.c" 2>&1)"
	status=$?
	set -e

	expected_msg="Error: plugin 'C' out_rel '../evil' escapes cache entry"

	if [[ "${status}" -eq 0 ]]; then
		fail "expected failure when out_rel escapes entry"
	fi

	if [[ "${output}" != *"${expected_msg}"* ]]; then
		printf 'Expected error message containing:\n%s\nGot:\n%s\n' "${expected_msg}" "${output}" >&2
		exit 1
	fi
}

test_build_command_runs_when_artifact_missing() {
	tmp_plugins="$(make_temp_dir)"
	mkdir -p "${tmp_plugins}/C/default"

	cat > "${tmp_plugins}/C/default/plugin" <<'EOF'
#!/usr/bin/env bash
set -eo pipefail

case "${1:-}" in
	meta)
		cat <<'META'
out_rel=hello
build_cmd=printf '%s\n' '#!/usr/bin/env bash' '# built marker' 'exit 0' > "$JUMPSCRIPT_ARTIFACT"; chmod +x "$JUMPSCRIPT_ARTIFACT"
rebuild_mode=mtime
exec_kind=bin
META
		exit 0
		;;
	*)
		echo "unsupported" >&2
		exit 1
		;;
esac
EOF
	chmod +x "${tmp_plugins}/C/default/plugin"

	cache_root="$(make_temp_dir)/cache"

	set +e
	JUMPSCRIPT_PLUGINS_DIR="${tmp_plugins}" \
	JUMPSCRIPT_CACHE="${cache_root}" \
	"${runner}" run C "${repo_root}/tests/fixtures/hello.c" >/dev/null 2>&1
	status=$?
	set -e

	if [[ "${status}" -ne 0 ]]; then
		fail "runner should succeed when building missing artifact"
	fi

	version_dir="${cache_root}/C/default"
	mapfile -t entries < <(find "${version_dir}" -mindepth 1 -maxdepth 1 -type d)
	if [[ "${#entries[@]}" -ne 1 ]]; then
		fail "expected exactly one cache entry directory, found ${#entries[@]}"
	fi

	artifact_path="${entries[0]}/hello"

	if [[ ! -f "${artifact_path}" ]]; then
		fail "expected artifact ${artifact_path} to exist"
	fi

	if ! grep -q '# built marker' "${artifact_path}"; then
		fail "expected artifact to contain built marker"
	fi

	artifact_mtime=""
	if artifact_mtime=$(stat -c %Y "${artifact_path}" 2>/dev/null); then
		:
	elif artifact_mtime=$(stat -f %m "${artifact_path}" 2>/dev/null); then
		:
	else
		fail "unable to get artifact mtime"
	fi

	script_mtime=""
	if script_mtime=$(stat -c %Y "${repo_root}/tests/fixtures/hello.c" 2>/dev/null); then
		:
	elif script_mtime=$(stat -f %m "${repo_root}/tests/fixtures/hello.c" 2>/dev/null); then
		:
	else
		fail "unable to get script mtime"
	fi

	if [[ "${artifact_mtime}" != "${script_mtime}" ]]; then
		fail "expected artifact mtime ${artifact_mtime} to match script mtime ${script_mtime}"
	fi
}

test_build_skipped_when_artifact_fresh() {
	tmp_plugins="$(make_temp_dir)"
	mkdir -p "${tmp_plugins}/C/default"

	cat > "${tmp_plugins}/C/default/plugin" <<'EOF'
#!/usr/bin/env bash
set -eo pipefail

case "${1:-}" in
	meta)
		cat <<'META'
out_rel=hello
build_cmd=printf '%s\n' '#!/usr/bin/env bash' '# first marker' 'exit 0' > "$JUMPSCRIPT_ARTIFACT"; chmod +x "$JUMPSCRIPT_ARTIFACT"
rebuild_mode=mtime
exec_kind=bin
META
		exit 0
		;;
	*)
		echo "unsupported" >&2
		exit 1
		;;
esac
EOF
	chmod +x "${tmp_plugins}/C/default/plugin"

	cache_root="$(make_temp_dir)/cache"

	JUMPSCRIPT_PLUGINS_DIR="${tmp_plugins}" \
	JUMPSCRIPT_CACHE="${cache_root}" \
	"${runner}" run C "${repo_root}/tests/fixtures/hello.c" >/dev/null 2>&1 || fail "initial build should succeed"

	version_dir="${cache_root}/C/default"
	mapfile -t entries < <(find "${version_dir}" -mindepth 1 -maxdepth 1 -type d)
	if [[ "${#entries[@]}" -ne 1 ]]; then
		fail "expected exactly one cache entry directory, found ${#entries[@]}"
	fi

	artifact_path="${entries[0]}/hello"
	if [[ ! -f "${artifact_path}" ]]; then
		fail "expected artifact ${artifact_path} to exist after first build"
	fi

	# Modify plugin so a rebuild would change content to 'second'
	cat > "${tmp_plugins}/C/default/plugin" <<'EOF'
#!/usr/bin/env bash
set -eo pipefail

case "${1:-}" in
	meta)
		cat <<'META'
out_rel=hello
build_cmd=printf '%s\n' '#!/usr/bin/env bash' '# second marker' 'exit 0' > "$JUMPSCRIPT_ARTIFACT"; chmod +x "$JUMPSCRIPT_ARTIFACT"
rebuild_mode=mtime
exec_kind=bin
META
		exit 0
		;;
	*)
		echo "unsupported" >&2
		exit 1
		;;
esac
EOF
	chmod +x "${tmp_plugins}/C/default/plugin"

	JUMPSCRIPT_PLUGINS_DIR="${tmp_plugins}" \
	JUMPSCRIPT_CACHE="${cache_root}" \
	"${runner}" run C "${repo_root}/tests/fixtures/hello.c" >/dev/null 2>&1 || fail "second run should succeed"

	if ! grep -q '# first marker' "${artifact_path}"; then
		fail "expected cached artifact to retain first marker"
	fi

	if grep -q '# second marker' "${artifact_path}"; then
		fail "artifact should not contain second marker after cache hit"
	fi
}

test_executes_binary_artifact() {
	tmp_plugins="$(make_temp_dir)"
	mkdir -p "${tmp_plugins}/C/default"

	cat > "${tmp_plugins}/C/default/plugin" <<'EOF'
#!/usr/bin/env bash
set -eo pipefail

case "${1:-}" in
	meta)
		cat <<'META'
out_rel=bin/run
build_cmd=printf '%s\n' '#!/usr/bin/env bash' 'printf "ARGS:%s:%s\n" "$1" "$2"' 'exit 7' > "$JUMPSCRIPT_ARTIFACT"; chmod +x "$JUMPSCRIPT_ARTIFACT"
rebuild_mode=mtime
exec_kind=bin
META
		exit 0
		;;
	*)
		echo "unsupported" >&2
		exit 1
		;;
esac
EOF
	chmod +x "${tmp_plugins}/C/default/plugin"

	cache_root="$(make_temp_dir)/cache"

	set +e
	output="$(JUMPSCRIPT_PLUGINS_DIR="${tmp_plugins}" JUMPSCRIPT_CACHE="${cache_root}" "${runner}" run C "${repo_root}/tests/fixtures/hello.c" foo bar 2>&1)"
	status=$?
	set -e

	if [[ "${status}" -ne 7 ]]; then
		fail "expected exit status 7 from executed artifact, got ${status}"
	fi

	expected_output="ARGS:foo:bar"
	if [[ "${output}" != *"${expected_output}"* ]]; then
		printf 'Expected output containing:\n%s\nGot:\n%s\n' "${expected_output}" "${output}" >&2
		exit 1
	fi
}

test_runtime_command_executes_text_artifact() {
	tmp_plugins="$(make_temp_dir)"
	mkdir -p "${tmp_plugins}/Txt/default"

	cat > "${tmp_plugins}/Txt/default/plugin" <<'EOF'
#!/usr/bin/env bash
set -eo pipefail

case "${1:-}" in
	meta)
		cat <<'META'
out_rel=script/run.sh
build_cmd=printf '%s\n' '#!/usr/bin/env bash' 'echo runtime-ok' > "$JUMPSCRIPT_ARTIFACT" && chmod +x "$JUMPSCRIPT_ARTIFACT"
rebuild_mode=mtime
exec_kind=text
runtime_cmd=bash {{artifact}}
META
		exit 0
		;;
	*)
		echo "unsupported" >&2
		exit 1
		;;
esac
EOF
	chmod +x "${tmp_plugins}/Txt/default/plugin"

	cache_root="$(make_temp_dir)/cache"

	set +e
	output="$(JUMPSCRIPT_PLUGINS_DIR="${tmp_plugins}" JUMPSCRIPT_CACHE="${cache_root}" "${runner}" run Txt "${repo_root}/tests/fixtures/hello.c" 2>&1)"
	status=$?
	set -e

	if [[ "${status}" -ne 0 ]]; then
		printf 'Expected runtime command to execute successfully; got %d\nOutput:\n%s\n' "${status}" "${output}" >&2
		exit 1
	fi

	if [[ "${output}" != *"runtime-ok"* ]]; then
		printf 'Expected runtime output, got:\n%s\n' "${output}" >&2
		exit 1
	fi
}

test_cache_root_permission_check() {
	tmp_plugins="$(make_temp_dir)"
	mkdir -p "${tmp_plugins}/C/default"

	cat > "${tmp_plugins}/C/default/plugin" <<'EOF'
#!/usr/bin/env bash
set -eo pipefail

case "${1:-}" in
	meta)
		cat <<'META'
out_rel=hello
build_cmd=printf '%s\n' '#!/usr/bin/env bash' 'exit 0' '# built marker' > "$JUMPSCRIPT_ARTIFACT"; chmod +x "$JUMPSCRIPT_ARTIFACT"
rebuild_mode=mtime
exec_kind=bin
META
		exit 0
		;;
	*)
		echo "unsupported" >&2
		exit 1
		;;
esac
EOF
	chmod +x "${tmp_plugins}/C/default/plugin"

	cache_root="$(make_temp_dir)/cache"
	mkdir -p "${cache_root}"
	chmod 755 "${cache_root}"

	set +e
	output="$(JUMPSCRIPT_PLUGINS_DIR="${tmp_plugins}" JUMPSCRIPT_CACHE="${cache_root}" "${runner}" run C "${repo_root}/tests/fixtures/hello.c" 2>&1)"
	status=$?
	set -e

	expected_msg="Error: cache root '${cache_root}' has permissions 755; expected 700"

	if [[ "${status}" -eq 0 ]]; then
		fail "expected failure when cache permissions too open"
	fi

	if [[ "${output}" != *"${expected_msg}"* ]]; then
		printf 'Expected error message containing:\n%s\nGot:\n%s\n' "${expected_msg}" "${output}" >&2
		exit 1
	fi
}

test_missing_script_path
test_missing_plugin_error_message
test_missing_plugin_executable
test_plugin_meta_failure
test_plugin_meta_missing_field
test_plugin_meta_unsupported_rebuild_mode
test_plugin_meta_unsupported_exec_kind
test_cache_root_created_with_secure_perms
test_executes_binary_artifact
test_runtime_command_executes_text_artifact
test_cache_root_permission_check
test_cache_lang_version_directory_created
test_cache_entry_directory_created
test_meta_file_written
test_out_rel_must_stay_within_entry
test_build_command_runs_when_artifact_missing
test_build_skipped_when_artifact_fresh
