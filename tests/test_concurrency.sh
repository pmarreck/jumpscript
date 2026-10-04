#!/usr/bin/env bash
# Concurrent cold runs of one script share a fresh cache: exactly one build
# happens, every run prints the right output, and none trips over another's
# half-created cache directory. The fake build waits until every runner has
# started, so runners that are not serialized all reach the build at once.
set -u

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runner="${repo_root}/bin/jumpscript"
runners=8
rounds=3
failures=0
fail() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }

tmp_root="$(mktemp -d)"
trap 'rm -rf "${tmp_root}"' EXIT

plugins="${tmp_root}/plugins"
mkdir -p "${plugins}/Fake/default"
cat > "${plugins}/Fake/default/plugin" <<'EOF'
#!/usr/bin/env bash
[[ "${1:-}" == meta ]] || exit 1
echo "out_rel=bin/app"
echo "build_cmd=\"${FAKE_BUILD:?}\""
echo "rebuild_mode=mtime"
echo "exec_kind=bin"
EOF
chmod +x "${plugins}/Fake/default/plugin"

# The build: record itself, wait (bounded) until every runner has started,
# then write the artifact in two steps so a reader could see it half done.
cat > "${tmp_root}/build" <<'EOF'
#!/usr/bin/env bash
echo build >> "${FAKE_STATE}/builds"
for _ in $(seq 1 1000); do
	[[ "$(wc -l < "${FAKE_STATE}/started")" -ge "${FAKE_RUNNERS}" ]] && break
	sleep 0.01
done
mkdir -p "$(dirname "${JUMPSCRIPT_ARTIFACT}")"
printf '#!/usr/bin/env bash\n' > "${JUMPSCRIPT_ARTIFACT}"
printf 'echo "fake ok $#"\n' >> "${JUMPSCRIPT_ARTIFACT}"
chmod +x "${JUMPSCRIPT_ARTIFACT}"
EOF
chmod +x "${tmp_root}/build"

mkdir -p "${tmp_root}/scripts"
script="${tmp_root}/scripts/hello"
echo "hello" > "${script}"

for round in $(seq 1 "${rounds}"); do
	state="${tmp_root}/state-${round}"
	cache="${tmp_root}/cache-${round}/nested"
	mkdir -p "${state}"
	: > "${state}/started"
	pids=()
	for i in $(seq 1 "${runners}"); do
		(
			echo "${i}" >> "${state}/started"
			JUMPSCRIPT_PLUGINS_DIR="${plugins}" JUMPSCRIPT_USER_PLUGINS="${tmp_root}/none" \
				JUMPSCRIPT_CACHE="${cache}" FAKE_STATE="${state}" FAKE_RUNNERS="${runners}" \
				FAKE_BUILD="${tmp_root}/build" \
				"${runner}" Fake "${script}" a b > "${state}/out.${i}" 2> "${state}/err.${i}"
			echo $? > "${state}/status.${i}"
		) &
		pids+=($!)
	done
	for pid in "${pids[@]}"; do wait "${pid}"; done
	for i in $(seq 1 "${runners}"); do
		status="$(cat "${state}/status.${i}")"
		[[ "${status}" == 0 && "$(cat "${state}/out.${i}")" == "fake ok 2" ]] \
			|| fail "round ${round} runner ${i}: status ${status}, output '$(cat "${state}/out.${i}")', stderr '$(cat "${state}/err.${i}")'"
	done
	builds="$(wc -l < "${state}/builds" | tr -d ' ')"
	[[ "${builds}" == 1 ]] || fail "round ${round}: ${builds} builds of one cache entry, want 1"
done

# A cache directory is never visible with permissions other than 700, even
# while another run is creating it. strace holds the first run right after
# its mkdir returns; a second run then finds the new directory and must
# accept it. (Created as 755 and then chmodded, it was rejected.) Linux-only,
# because strace is.
if [[ "$(uname -s)" == Linux ]]; then
	if ! command -v strace >/dev/null; then
		fail "strace is required for the cache directory permission check on Linux"
	else
		mkdir -p "${plugins}/Fail/default"
		printf '#!/bin/sh\nexit 9\n' > "${plugins}/Fail/default/plugin"
		chmod +x "${plugins}/Fail/default/plugin"
		cache="${tmp_root}/perm/nested/cache"
		(umask 022; JUMPSCRIPT_PLUGINS_DIR="${plugins}" JUMPSCRIPT_USER_PLUGINS="${tmp_root}/none" JUMPSCRIPT_CACHE="${cache}" \
			strace -f -o /dev/null -e trace=mkdirat,mkdir -e inject=mkdirat,mkdir:delay_exit=2000000 \
			"${runner}" Fail "${script}" > /dev/null 2> "${tmp_root}/perm.first") &
		first=$!
		for _ in $(seq 1 1000); do [[ -d "${cache}" ]] && break; sleep 0.01; done
		[[ -d "${cache}" ]] || fail "permission check: the first run never created ${cache}"
		(umask 022; JUMPSCRIPT_PLUGINS_DIR="${plugins}" JUMPSCRIPT_USER_PLUGINS="${tmp_root}/none" JUMPSCRIPT_CACHE="${cache}" \
			"${runner}" Fail "${script}" > /dev/null 2> "${tmp_root}/perm.second")
		second_status=$?
		wait "${first}"
		second_err="$(cat "${tmp_root}/perm.second")"
		[[ ${second_status} -eq 9 && "${second_err}" == *"meta command failed with exit code 9"* ]] \
			|| fail "permission check: a run during another's mkdir got status ${second_status}, stderr '${second_err}'"
	fi
fi

if [[ ${failures} -ne 0 ]]; then
	echo "test_concurrency: ${failures} failed" >&2
	exit 1
fi
echo "test_concurrency: all passed"
