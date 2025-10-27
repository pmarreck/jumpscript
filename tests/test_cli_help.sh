#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}" )/.." && pwd)"
jump="${repo_root}/jumpscript"

expect_equal() {
	local actual="$1"
	local expected="$2"
	if [[ "${actual}" != "${expected}" ]]; then
		printf "Expected '%s'\nGot: '%s'\n" "${expected}" "${actual}" >&2
		exit 1
	fi
}

expect_contains() {
	local haystack="$1"
	local needle="$2"
	if [[ "${haystack}" != *"${needle}"* ]]; then
		printf "Expected output to contain '%s'\nOutput:\n%s\n" "${needle}" "${haystack}" >&2
		exit 1
	fi
}

about_output="$("${jump}" -a)"
expect_equal "${about_output}" "jumpscript: cached edit-run harness for compiled languages"

about_long_output="$("${jump}" --about)"
expect_equal "${about_long_output}" "${about_output}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

export XDG_CACHE_HOME="${tmp_dir}/xdg-cache"
export JUMPSCRIPT_CACHE="${tmp_dir}/explicit-cache"
export JUMPSCRIPT_PLUGINS_DIR="${tmp_dir}/custom-plugins"
export XDG_DATA_HOME="${tmp_dir}/xdg-data"
unset JUMPSCRIPT_USER_PLUGINS

help_output="$("${jump}" -h)"

expect_contains "${help_output}" "Usage: jumpscript run <Language[-Version]> <script> [args...]"
expect_contains "${help_output}" "Current cache root: ${JUMPSCRIPT_CACHE}"
expect_contains "${help_output}" "Default cache root: ${XDG_CACHE_HOME}/jumpscript-artifacts"
expect_contains "${help_output}" "Cache overrides: JUMPSCRIPT_CACHE, XDG_CACHE_HOME"
expect_contains "${help_output}" "Bundled plugins dir: ${JUMPSCRIPT_PLUGINS_DIR}"
expect_contains "${help_output}" "Plugins override: JUMPSCRIPT_PLUGINS_DIR"
expect_contains "${help_output}" "User plugins search root: ${XDG_DATA_HOME}/jumpscript/plugins"
expect_contains "${help_output}" "User plugins overrides: JUMPSCRIPT_USER_PLUGINS, XDG_DATA_HOME"

help_long_output="$("${jump}" --help)"
expect_equal "${help_long_output}" "${help_output}"
