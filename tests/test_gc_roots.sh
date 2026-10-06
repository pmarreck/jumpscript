#!/usr/bin/env bash
# A cached artifact stays runnable across Nix garbage collection: every store
# path the built binary names (its loader, libc, runtime libraries) must be
# kept alive by a GC root inside the binary's own cache entry.
#
# The oracle is `nix-store --query --roots`, the same question the collector
# asks, so no garbage is actually collected from the user's store. Collecting
# for real would also pass vacuously whenever the host system happens to
# hold the same glibc.
set -u

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runner="${repo_root}/bin/jumpscript"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT
export JUMPSCRIPT_CACHE="${tmp_dir}/cache"

failures=0
fail() {
	printf 'FAIL: %s\n' "$*" >&2
	failures=$((failures + 1))
}

# Prints the distinct /nix/store/<hash>-<name> paths named inside file $1.
store_refs() {
	LC_ALL=C grep -a -o -E '/nix/store/[0-9a-z]{32}-[^/[:space:][:cntrl:]]+' "$1" | sort -u
}

# Checks that one fixture's artifact references the store and that each
# referenced path has a GC root under the artifact's cache entry.
check_rooted() {
	local lang="$1" fixture="$2" expect="$3"
	local script="${tmp_dir}/${fixture}"
	cp "${repo_root}/tests/fixtures/${fixture}" "${script}"

	local output status
	output="$("${runner}" run "${lang}" "${script}" 2>&1)"
	status=$?
	if [[ ${status} -ne 0 || "${output}" != *"${expect}"* ]]; then
		fail "${lang}: run exited ${status} without '${expect}': ${output}"
		return
	fi

	local entry
	entry="$(find "${JUMPSCRIPT_CACHE}/${lang}/default" -mindepth 1 -maxdepth 1 -type d -name "${fixture}-*")"
	local artifact
	artifact="$(find "${entry}" -path "${entry}/.*" -prune -o -type f -perm -u+x -print | head -n 1)"
	if [[ -z "${artifact}" ]]; then
		fail "${lang}: no executable artifact in ${entry}"
		return
	fi

	local refs
	refs="$(store_refs "${artifact}")"
	if [[ -z "${refs}" ]]; then
		fail "${lang}: artifact names no store paths, so this check proves nothing"
		return
	fi

	local closure="" root
	while IFS= read -r root; do
		[[ -n "${root}" ]] && closure+="$(nix-store --query --requisites "${root}")"$'\n'
	done < <(entry_roots "${entry}")

	local ref
	while IFS= read -r ref; do
		if [[ $'\n'"${closure}" != *$'\n'"${ref}"$'\n'* ]]; then
			fail "${lang}: ${ref} has no GC root under ${entry}"
		fi
	done <<< "${refs}"
}

# Prints the registered GC roots that live inside cache entry $1: links that
# Nix's indirect-root directory points at. This is what the collector reads;
# `nix-store --query --roots` asks the same question but scans every root
# and process on the machine, about 35 s per path.
entry_roots() {
	local auto target
	for auto in "${gcroots_auto}"/*; do
		target="$(readlink "${auto}")" || continue
		[[ "${target}" == "$1/"* && -L "${target}" ]] && printf '%s\n' "${target}"
	done
}
gcroots_auto="/nix/var/nix/gcroots/auto"

# A stub plugin whose artifact is the script itself, so the test controls
# exactly which store paths the artifact names.
write_stub_plugin() {
	local dir="$1/Stub/default"
	mkdir -p "${dir}"
	cat > "${dir}/plugin" <<'EOF'
#!/usr/bin/env bash
[[ "${1:-}" == meta ]] || exit 1
printf '%s\n' lang=Stub out_rel=artifact 'build_cmd=cp "$JUMPSCRIPT_SCRIPT" artifact; chmod +x artifact' rebuild_mode=mtime exec_kind=bin
EOF
	chmod +x "${dir}/plugin"
}

# A store path that is not in this store (a string a program merely prints)
# cannot be rooted offline; the build still succeeds and the paths that do
# exist are rooted.
test_absent_store_path_is_skipped() {
	local plugins="${tmp_dir}/user-plugins"
	write_stub_plugin "${plugins}"
	local present
	present="$(nix_store_path)"
	local absent="/nix/store/00000000000000000000000000000000-not-in-this-store"
	local script="${tmp_dir}/absent.stub"
	printf '%s\n' '#!/usr/bin/env bash' "# ${absent} ${present}" 'echo stub OK' > "${script}"

	local output status
	output="$(JUMPSCRIPT_USER_PLUGINS="${plugins}" "${runner}" run Stub "${script}" 2>&1)"
	status=$?
	if [[ ${status} -ne 0 || "${output}" != "stub OK" ]]; then
		fail "Stub: an absent store path broke the build (exit ${status}): ${output}"
		return
	fi
	local entry
	entry="$(find "${JUMPSCRIPT_CACHE}/Stub/default" -mindepth 1 -maxdepth 1 -type d -name 'absent.stub-*')"
	local closure="" root
	while IFS= read -r root; do
		[[ -n "${root}" ]] && closure+="$(nix-store --query --requisites "${root}")"$'\n'
	done < <(entry_roots "${entry}")
	[[ $'\n'"${closure}" == *$'\n'"${present}"$'\n'* ]] || fail "Stub: ${present} has no GC root under ${entry}"
}

# The store path holding the nix binary: present in every Nix install.
nix_store_path() {
	local p
	p="$(readlink -f "$(command -v nix)")"
	p="${p#/nix/store/}"
	printf '/nix/store/%s\n' "${p%%/*}"
}

test_absent_store_path_is_skipped
check_rooted C hello.c "C integration OK"
check_rooted C++ hello.cpp "C++ integration OK"
check_rooted Nim hello.nim "Nim integration OK"

if (( failures )); then
	echo "test_gc_roots: ${failures} failure(s)" >&2
	exit 1
fi
echo "test_gc_roots: all passed"
