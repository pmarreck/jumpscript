#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}" )/.." && pwd)"
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

write_plugin() {
	local root="$1"
	local message="$2"
	local plugin_dir="${root}/Test/default"
	mkdir -p "${plugin_dir}"
	cat > "${plugin_dir}/plugin" <<EOF
#!/usr/bin/env bash
set -euo pipefail

meta() {
	cat <<META
lang=Test
out_rel=artifact
build_cmd=printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "${message}"' > artifact; chmod +x artifact
rebuild_mode=mtime
exec_kind=bin
META
}

doctor() {
	echo "status=ok"
}

case "\${1:-}" in
	meta)
		shift
		meta "\$@"
		;;
	doctor)
		shift
		doctor "\$@"
		;;
	help)
		echo "Test plugin"
		;;
	*)
		echo "usage: plugin meta|doctor|help" >&2
		exit 1
		;;
esac
EOF
	chmod +x "${plugin_dir}/plugin"
}

main() {
	local cache_root stock_plugins user_plugins script_dir script_path output bash_bin bash_dir

	cache_root="$(make_temp_dir)/cache"
	stock_plugins="$(make_temp_dir)"
	user_plugins="$(make_temp_dir)"
	script_dir="$(make_temp_dir)"

	write_plugin "${stock_plugins}" "stock-plugin"
	write_plugin "${user_plugins}" "user-plugin"

	script_path="${script_dir}/hello.test"
	cat > "${script_path}" <<'SCRIPT'
-- dummy script content that should be ignored by the plugin
SCRIPT

	bash_bin="$(command -v bash || true)"
	if [[ -z "${bash_bin}" ]]; then
		echo "bash not found on PATH" >&2
		exit 1
	fi
	bash_dir="$(dirname "${bash_bin}")"

	output="$(
		PATH="${bash_dir}:${PATH}" \
		JUMPSCRIPT_CACHE="${cache_root}" \
		JUMPSCRIPT_PLUGINS_DIR="${stock_plugins}" \
		JUMPSCRIPT_USER_PLUGINS="${user_plugins}" \
		"${runner}" run Test "${script_path}"
	)"

	if [[ "${output}" != "user-plugin" ]]; then
		echo "expected user plugin output, got: ${output}" >&2
		exit 1
	fi
}

main
