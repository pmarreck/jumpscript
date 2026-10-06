//! Pure core of the jumpscript runner: no I/O. The adapter in main.zig does
//! the filesystem and process work and asks this module every decision.
const std = @import("std");

test "splitLangToken: version after the first dash, default otherwise" {
	try std.testing.expectEqualDeep(LangToken{ .lang = "Roc", .version = "default" }, splitLangToken("Roc"));
	try std.testing.expectEqualDeep(LangToken{ .lang = "Roc", .version = "luajit" }, splitLangToken("Roc-luajit"));
	try std.testing.expectEqualDeep(LangToken{ .lang = "C", .version = "x-y" }, splitLangToken("C-x-y"));
}

/// A shebang language token split into plugin directory names:
/// `Lang-Version` selects plugins/<Lang>/<Version>, a bare `Lang` the
/// `default` variant. Only the first dash separates.
pub const LangToken = struct { lang: []const u8, version: []const u8 };

pub fn splitLangToken(token: []const u8) LangToken {
	if (std.mem.findScalar(u8, token, '-')) |i| return .{ .lang = token[0..i], .version = token[i + 1 ..] };
	return .{ .lang = token, .version = "default" };
}

fn expectRun(args: []const []const u8, want: Run) !void {
	const got = parseArgs(args);
	try std.testing.expect(got == .run);
	try std.testing.expectEqualDeep(want, got.run);
}

fn expectFailure(args: []const []const u8, want: Failure) !void {
	const got = parseArgs(args);
	try std.testing.expect(got == .fail);
	try std.testing.expectEqualDeep(want, got.fail);
}

test "parseArgs: about and help only before the command" {
	try std.testing.expect(parseArgs(&.{"-a"}) == .about);
	try std.testing.expect(parseArgs(&.{ "--about", "x" }) == .about);
	try std.testing.expect(parseArgs(&.{"-h"}) == .help);
	try std.testing.expect(parseArgs(&.{ "--help", "Roc" }) == .help);
	try expectRun(&.{ "Roc", "-h" }, .{ .lang_token = "Roc", .script = "-h", .script_args = &.{} });
}

test "parseArgs: run is implicit, as in a shebang" {
	try expectRun(&.{ "Roc", "s.roc", "a", "b" }, .{ .lang_token = "Roc", .script = "s.roc", .script_args = &.{ "a", "b" } });
	try expectRun(&.{ "run", "Roc", "s.roc" }, .{ .lang_token = "Roc", .script = "s.roc", .script_args = &.{} });
	try expectRun(&.{ "--", "Roc", "s" }, .{ .lang_token = "Roc", .script = "s", .script_args = &.{} });
}

test "parseArgs: --no-* flags count until the script, later ones are script arguments" {
	try expectRun(&.{ "--no-deps", "Roc", "s" }, .{ .skip_build_deps = true, .skip_runtime_deps = true, .lang_token = "Roc", .script = "s", .script_args = &.{} });
	try expectRun(&.{ "run", "Roc", "--no-runtime-deps", "s", "--no-deps" }, .{ .skip_runtime_deps = true, .lang_token = "Roc", .script = "s", .script_args = &.{"--no-deps"} });
	try expectRun(&.{ "--no-build-deps", "C", "s" }, .{ .skip_build_deps = true, .lang_token = "C", .script = "s", .script_args = &.{} });
}

test "parseArgs: failures name what is missing or unsupported" {
	try expectFailure(&.{}, .{ .reason = .no_command });
	try expectFailure(&.{ "-x", "Roc" }, .{ .reason = .unsupported_option, .arg = "-x" });
	try expectFailure(&.{"run"}, .{ .reason = .no_lang });
	try expectFailure(&.{ "run", "--", "Roc", "s" }, .{ .reason = .no_lang });
	try expectFailure(&.{"Roc"}, .{ .reason = .no_script });
}

/// A parsed `run` invocation.
pub const Run = struct {
	skip_build_deps: bool = false,
	skip_runtime_deps: bool = false,
	lang_token: []const u8,
	script: []const u8,
	script_args: []const []const u8,
};

/// Why the arguments were rejected; `arg` is the offending argument, if any.
pub const Failure = struct {
	reason: enum { no_command, unsupported_option, no_lang, no_script },
	arg: []const u8 = "",
};

pub const Command = union(enum) { about, help, run: Run, fail: Failure };

/// Parses the runner's argv (without the program name) the way the original
/// Bash runner did: options before the command, an implicit `run` (the
/// shebang form `jumpscript Lang script args`), `--no-*` flags until the
/// script path, and everything after the script passed through untouched.
pub fn parseArgs(args: []const []const u8) Command {
	var i: usize = 0;
	while (i < args.len) {
		const a = args[i];
		if (eql(a, "-a") or eql(a, "--about")) return .about;
		if (eql(a, "-h") or eql(a, "--help")) return .help;
		if (eql(a, "--no-deps") or eql(a, "--no-build-deps") or eql(a, "--no-runtime-deps")) break;
		if (eql(a, "--")) {
			i += 1;
			break;
		}
		if (a.len > 0 and a[0] == '-') return .{ .fail = .{ .reason = .unsupported_option, .arg = a } };
		break;
	}
	if (i >= args.len or args[i].len == 0) return .{ .fail = .{ .reason = .no_command } };
	if (eql(args[i], "run")) i += 1;

	var run: Run = .{ .lang_token = "", .script = "", .script_args = &.{} };
	while (i < args.len) {
		const a = args[i];
		if (eql(a, "--no-deps")) {
			run.skip_build_deps = true;
			run.skip_runtime_deps = true;
		} else if (eql(a, "--no-build-deps")) {
			run.skip_build_deps = true;
		} else if (eql(a, "--no-runtime-deps")) {
			run.skip_runtime_deps = true;
		} else if (eql(a, "--")) {
			i += 1;
			break;
		} else if (run.lang_token.len == 0) {
			run.lang_token = a;
		} else break;
		i += 1;
	}
	if (run.lang_token.len == 0) return .{ .fail = .{ .reason = .no_lang } };
	if (i >= args.len or args[i].len == 0) return .{ .fail = .{ .reason = .no_script } };
	run.script = args[i];
	run.script_args = args[i + 1 ..];
	return .{ .run = run };
}

fn eql(a: []const u8, b: []const u8) bool {
	return std.mem.eql(u8, a, b);
}

test "parseMeta: key=value lines, later keys win, values keep their = signs" {
	const m = parseMeta("out_rel=bin/x\n\nbuild_cmd=cc -DX=1 \"$JUMPSCRIPT_SCRIPT\"\nrebuild_mode=mtime\nexec_kind=bin\nexec_kind=lua\nnoise\n");
	try std.testing.expectEqualStrings("bin/x", m.out_rel);
	try std.testing.expectEqualStrings("cc -DX=1 \"$JUMPSCRIPT_SCRIPT\"", m.build_cmd);
	try std.testing.expectEqualStrings("lua", m.exec_kind);
	try std.testing.expectEqualStrings("", m.runtime_cmd);
	try std.testing.expectEqualStrings("", m.deps);
}

test "validateMeta: required fields, then supported rebuild modes and exec kinds" {
	const ok = "out_rel=a\nbuild_cmd=b\nrebuild_mode=mtime\nexec_kind=wasm\nruntime_cmd=w {{artifact}}\n";
	try std.testing.expectEqual(@as(?MetaProblem, null), validateMeta(parseMeta(ok)));
	try std.testing.expectEqualDeep(@as(?MetaProblem, .{ .missing_field = "out_rel" }), validateMeta(parseMeta("build_cmd=b\nrebuild_mode=mtime\nexec_kind=bin\n")));
	try std.testing.expectEqualDeep(@as(?MetaProblem, .{ .missing_field = "exec_kind" }), validateMeta(parseMeta("out_rel=a\nbuild_cmd=b\nrebuild_mode=mtime\n")));
	try std.testing.expectEqualDeep(@as(?MetaProblem, .{ .unsupported_rebuild_mode = "hash" }), validateMeta(parseMeta("out_rel=a\nbuild_cmd=b\nrebuild_mode=hash\nexec_kind=bin\n")));
	try std.testing.expectEqualDeep(@as(?MetaProblem, .{ .unsupported_exec_kind = "jar" }), validateMeta(parseMeta("out_rel=a\nbuild_cmd=b\nrebuild_mode=mtime\nexec_kind=jar\n")));
	for ([_][]const u8{ "bin", "lua", "wasm", "beam", "text" }) |kind| {
		var buf: [128]u8 = undefined;
		const text = try std.fmt.bufPrint(&buf, "out_rel=a\nbuild_cmd=b\nrebuild_mode=mtime\nexec_kind={s}\n", .{kind});
		try std.testing.expectEqual(@as(?MetaProblem, null), validateMeta(parseMeta(text)));
	}
}

test "outRelEscapes: absolute paths and .. segments leave the cache entry" {
	const escaping = [_][]const u8{ "/bin/x", "../x", "a/../b", "a/..", ".." };
	const contained = [_][]const u8{ "x", "bin/x", "a/..b", "..a/b", "a/b../c", "./x" };
	for (escaping) |p| try std.testing.expect(outRelEscapes(p));
	for (contained) |p| try std.testing.expect(!outRelEscapes(p));
}

/// A plugin's `meta` answer. Fields borrow from the parsed text; absent
/// fields are empty.
pub const Meta = struct {
	out_rel: []const u8 = "",
	build_cmd: []const u8 = "",
	rebuild_mode: []const u8 = "",
	exec_kind: []const u8 = "",
	runtime_cmd: []const u8 = "",
	deps: []const u8 = "",
};

/// Parses `key=value` lines (split at the first `=`, later keys win, unknown
/// keys ignored). Unlike Bash `read`, a trailing `=` stays in the value.
pub fn parseMeta(text: []const u8) Meta {
	var m: Meta = .{};
	var lines = std.mem.splitScalar(u8, text, '\n');
	while (lines.next()) |line| {
		const eq = std.mem.findScalar(u8, line, '=') orelse continue;
		const key = line[0..eq];
		const value = line[eq + 1 ..];
		inline for (@typeInfo(Meta).@"struct".fields) |field| {
			if (eql(key, field.name)) @field(m, field.name) = value;
		}
	}
	return m;
}

pub const MetaProblem = union(enum) {
	missing_field: []const u8,
	unsupported_rebuild_mode: []const u8,
	unsupported_exec_kind: []const u8,
};

const exec_kinds = [_][]const u8{ "bin", "lua", "wasm", "beam", "text" };

/// The first contract violation in a plugin's meta, checked in the order
/// the Bash runner reported them, or null.
pub fn validateMeta(m: Meta) ?MetaProblem {
	inline for (.{ "out_rel", "build_cmd", "rebuild_mode", "exec_kind" }) |name| {
		if (@field(m, name).len == 0) return .{ .missing_field = name };
	}
	if (!eql(m.rebuild_mode, "mtime")) return .{ .unsupported_rebuild_mode = m.rebuild_mode };
	for (exec_kinds) |k| {
		if (eql(m.exec_kind, k)) return null;
	}
	return .{ .unsupported_exec_kind = m.exec_kind };
}

/// True when a plugin's out_rel would place the artifact outside its cache
/// entry: an absolute path or any `..` segment.
pub fn outRelEscapes(out_rel: []const u8) bool {
	if (out_rel.len > 0 and out_rel[0] == '/') return true;
	var segments = std.mem.splitScalar(u8, out_rel, '/');
	while (segments.next()) |s| {
		if (eql(s, "..")) return true;
	}
	return false;
}

test "expandRuntime: substitutes placeholders, then splits on blanks" {
	var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
	defer arena.deinit();
	const a = arena.allocator();
	const got = try expandRuntime(a, "  /w/wasmtime run\t--dir=/  {{artifact}} {{script}}\n", "/c/app.wasm", "/s/hello");
	try std.testing.expectEqualDeep(@as([]const []const u8, &.{ "/w/wasmtime", "run", "--dir=/", "/c/app.wasm", "/s/hello" }), got);
	const twice = try expandRuntime(a, "x {{artifact}}{{artifact}}", "A", "S");
	try std.testing.expectEqualDeep(@as([]const []const u8, &.{ "x", "AA" }), twice);
}

test "resolveDeps: colon list, empty entries skipped, relative to the script's directory" {
	var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
	defer arena.deinit();
	const a = arena.allocator();
	const got = try resolveDeps(a, "lib/a.h::/abs/b.h:", "/s");
	try std.testing.expectEqualDeep(@as([]const []const u8, &.{ "/s/lib/a.h", "/abs/b.h" }), got);
	const none = try resolveDeps(a, "", "/s");
	try std.testing.expectEqual(@as(usize, 0), none.len);
}

test "entryKey: script basename, newest source mtime in whole seconds, toolchain digest" {
	var buf: [256]u8 = undefined;
	try std.testing.expectEqualStrings("hello.roc-1791134550-0123456789ab", try entryKey(&buf, "hello.roc", 1791134550_999999999, "0123456789abcdef"));
	try std.testing.expectEqualStrings("x-0-000000000000", try entryKey(&buf, "x", 5, "000000000000ffff"));
}

test "toolchainDigest: the build command and the plugin files, in any file order" {
	const gpa = std.testing.allocator;
	const files = [_]FileStamp{ .{ .name = "flake.nix", .mtime_ns = 1, .size = 10 }, .{ .name = "plugin", .mtime_ns = 2, .size = 20 } };
	const meta = "nix develop /p#build --command cc";
	var want_buf: [64]u8 = undefined;
	const want = try toolchainDigest(gpa, meta, &files, &want_buf);
	var got: [64]u8 = undefined;
	const reordered = [_]FileStamp{ files[1], files[0] };
	try std.testing.expectEqualStrings(want, try toolchainDigest(gpa, meta, &reordered, &got));
	const relocked = [_]FileStamp{ .{ .name = "flake.lock", .mtime_ns = 5, .size = 30 }, files[0], files[1] };
	const lock_edit = [_]FileStamp{ .{ .name = "flake.nix", .mtime_ns = 1, .size = 11 }, files[1] };
	try std.testing.expect(!std.mem.eql(u8, want, try toolchainDigest(gpa, meta, &relocked, &got)));
	try std.testing.expect(!std.mem.eql(u8, want, try toolchainDigest(gpa, meta, &lock_edit, &got)));
	try std.testing.expect(!std.mem.eql(u8, want, try toolchainDigest(gpa, "/opt/roc build", &files, &got)));
}

test "needsBuild: missing artifact, or its mtime differs from the newest source to the nanosecond" {
	try std.testing.expect(needsBuild(null, 10));
	try std.testing.expect(needsBuild(9, 10));
	try std.testing.expect(needsBuild(1_000_000_001, 1_000_000_002));
	try std.testing.expect(!needsBuild(10, 10));
}

/// The argv a runtime_cmd template expands to: `{{artifact}}` and
/// `{{script}}` substituted, then split on blanks like Bash `read -a`
/// (so a path containing spaces splits too). Allocate from an arena.
pub fn expandRuntime(arena: std.mem.Allocator, template: []const u8, artifact: []const u8, script: []const u8) ![]const []const u8 {
	const with_artifact = try std.mem.replaceOwned(u8, arena, template, "{{artifact}}", artifact);
	const expanded = try std.mem.replaceOwned(u8, arena, with_artifact, "{{script}}", script);
	var parts: std.ArrayList([]const u8) = .empty;
	var words = std.mem.tokenizeAny(u8, expanded, " \t\n");
	while (words.next()) |w| try parts.append(arena, w);
	return parts.items;
}

/// Absolute paths of a plugin's `deps` list (colon-separated, empty entries
/// skipped, relative entries resolved against the script's directory).
/// Allocate from an arena.
pub fn resolveDeps(arena: std.mem.Allocator, deps: []const u8, script_dir: []const u8) ![]const []const u8 {
	var paths: std.ArrayList([]const u8) = .empty;
	var entries = std.mem.splitScalar(u8, deps, ':');
	while (entries.next()) |dep| {
		if (dep.len == 0) continue;
		try paths.append(arena, if (dep[0] == '/') dep else try std.fs.path.join(arena, &.{ script_dir, dep }));
	}
	return paths.items;
}

/// Hex digits of the toolchain digest kept in an entry name.
pub const entry_digest_len = 12;

/// The cache entry directory name: the script's basename, the newest source
/// mtime in whole seconds, and the first hex digits of the toolchain digest,
/// so a changed plugin or pin builds into a fresh entry.
pub fn entryKey(buf: []u8, basename: []const u8, newest_mtime_ns: i128, toolchain_digest: []const u8) ![]const u8 {
	return std.fmt.bufPrint(buf, "{s}-{d}-{s}", .{ basename, @divFloor(newest_mtime_ns, std.time.ns_per_s), toolchain_digest[0..entry_digest_len] });
}

/// Identity of the toolchain a build uses: SHA-256 (hex) over the plugin's
/// build command (it names the compiler or the flake it enters) and the
/// plugin directory's file stamps (flake.nix and flake.lock pin what
/// that flake provides). An artifact built under an older pin would otherwise
/// outlive it, and its garbage-collected store paths (dynamic loader,
/// libraries) with it. PATH, other environment and the runtime command do not
/// enter, so they rebuild only when they change the build command.
pub fn toolchainDigest(gpa: std.mem.Allocator, build_cmd: []const u8, plugin_files: []const FileStamp, out: *[64]u8) ![]const u8 {
	return metaCacheKey(gpa, .{
		.plugin_exec = build_cmd,
		.plugin_files = plugin_files,
		.script = "",
		.script_mtime_ns = 0,
		.script_size = 0,
		.skip_build_deps = false,
		.skip_runtime_deps = false,
		.env = &.{},
	}, out);
}

/// A build is needed unless the artifact exists with exactly the newest
/// source mtime, which the runner copies onto it after each build.
/// Nanosecond precision: two edits in one second still rebuild.
pub fn needsBuild(artifact_mtime_ns: ?i128, newest_mtime_ns: i128) bool {
	const m = artifact_mtime_ns orelse return true;
	return m != newest_mtime_ns;
}

test "storeRefs: distinct store paths in first-seen order, cut at the first byte a name cannot hold" {
	const arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
	var arena = arena_state;
	defer arena.deinit();
	const a = arena.allocator();
	const glibc = "/nix/store/znb3q6g1ik34454j3vcjx824h1871asg-glibc-2.42-84";
	const gcc = "/nix/store/2ga5nd1m56n5cx2wh8vbf6nrdhqk2f0q-gcc-15.3.0-lib";
	const bytes = "\x7fELF\x00" ++ glibc ++ "/lib/ld-linux-x86-64.so.2\x00junk" ++ gcc ++ ":" ++ glibc ++ "\x00";
	const got = try storeRefs(a, bytes);
	try std.testing.expectEqual(@as(usize, 2), got.len);
	try std.testing.expectEqualStrings(glibc, got[0]);
	try std.testing.expectEqualStrings(gcc, got[1]);
	try std.testing.expectEqualStrings(glibc, (try storeRefs(a, glibc))[0]);
}

test "storeRefs: rejects what only looks like a store path" {
	const arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
	var arena = arena_state;
	defer arena.deinit();
	const a = arena.allocator();
	const not_refs = [_][]const u8{
		"",
		"/nix/store/",
		"/nix/store/znb3q6g1ik34454j3vcjx824h1871asg-",
		"/nix/store/znb3q6g1ik34454j3vcjx824h1871asg/glibc",
		"/nix/store/znb3q6g1ik34454j3vcjx824h1871as-glibc",
		"/nix/store/enb3q6g1ik34454j3vcjx824h1871asg-glibc",
		"/nix/store/Znb3q6g1ik34454j3vcjx824h1871asg-glibc",
		"/nix/stor/znb3q6g1ik34454j3vcjx824h1871asg-glibc",
	};
	for (not_refs) |bytes| try std.testing.expectEqual(@as(usize, 0), (try storeRefs(a, bytes)).len);
}

/// The Nix store paths an artifact names, found by scanning its bytes for
/// `/nix/store/<32 base-32 chars>-<name>`, the way Nix finds a build
/// output's references. Rooting them keeps the artifact's dynamic loader
/// and libraries through garbage collection. Allocate from an arena.
pub fn storeRefs(arena: std.mem.Allocator, bytes: []const u8) ![]const []const u8 {
	const prefix = "/nix/store/";
	const hash_len = 32;
	var refs: std.ArrayList([]const u8) = .empty;
	var rest: usize = 0;
	while (std.mem.indexOfPos(u8, bytes, rest, prefix)) |start| {
		const hash_at = start + prefix.len;
		rest = hash_at;
		const name_at = hash_at + hash_len + 1;
		if (name_at > bytes.len or bytes[name_at - 1] != '-') continue;
		const all_base32 = for (bytes[hash_at .. hash_at + hash_len]) |c| {
			if (std.mem.indexOfScalar(u8, nix_base32, c) == null) break false;
		} else true;
		if (!all_base32) continue;
		var end = name_at;
		while (end < bytes.len and isStoreNameChar(bytes[end])) end += 1;
		if (end == name_at) continue;
		const ref = bytes[start..end];
		rest = end;
		for (refs.items) |seen| {
			if (eql(seen, ref)) break;
		} else try refs.append(arena, ref);
	}
	return refs.items;
}

/// Nix's base-32 alphabet: digits and lowercase letters without e, o, u, t.
const nix_base32 = "0123456789abcdfghijklmnpqrsvwxyz";

fn isStoreNameChar(c: u8) bool {
	return std.ascii.isAlphanumeric(c) or std.mem.indexOfScalar(u8, "+-._?=", c) != null;
}

test "metaKeyEnv classifies variables over a set" {
	const included = [_][]const u8{ "PATH", "JUMPSCRIPT_ROC", "JUMPSCRIPT_ROC_WASI_PLATFORM", "JUMPSCRIPT_CACHE", "JUMPSCRIPT_PLUGINS_DIR", "JUMPSCRIPT_DEBUG" };
	const excluded = [_][]const u8{ "HOME", "PWD", "OLDPWD", "SHLVL", "_", "PATHX", "MY_JUMPSCRIPT_X", "jumpscript_roc", "JUMPSCRIPT", "JUMPSCRIPT_NO_BUILD_DEPS", "JUMPSCRIPT_NO_RUNTIME_DEPS" };
	for (included) |n| try std.testing.expect(metaKeyEnv(n));
	for (excluded) |n| try std.testing.expect(!metaKeyEnv(n));
}

const base_inputs: MetaKeyInputs = .{
	.plugin_exec = "/p/Roc/default/plugin",
	.plugin_files = &.{ .{ .name = "flake.nix", .mtime_ns = 1, .size = 10 }, .{ .name = "plugin", .mtime_ns = 2, .size = 20 } },
	.script = "/s/hello",
	.script_mtime_ns = 3,
	.script_size = 30,
	.skip_build_deps = false,
	.skip_runtime_deps = false,
	.env = &.{ .{ .name = "PATH", .value = "/bin" }, .{ .name = "JUMPSCRIPT_ROC", .value = "/r/roc" } },
};

test "metaCacheKey: independent of plugin file and env order" {
	var a: [64]u8 = undefined;
	var b: [64]u8 = undefined;
	var shuffled = base_inputs;
	shuffled.plugin_files = &.{ .{ .name = "plugin", .mtime_ns = 2, .size = 20 }, .{ .name = "flake.nix", .mtime_ns = 1, .size = 10 } };
	shuffled.env = &.{ .{ .name = "JUMPSCRIPT_ROC", .value = "/r/roc" }, .{ .name = "PATH", .value = "/bin" } };
	try std.testing.expectEqualStrings(try metaCacheKey(std.testing.allocator, base_inputs, &a), try metaCacheKey(std.testing.allocator, shuffled, &b));
}

test "metaCacheKey: every input changes the key" {
	var mutations: [11]MetaKeyInputs = @splat(base_inputs);
	mutations[0].plugin_exec = "/p/Roc/luajit/plugin";
	mutations[1].plugin_files = &.{ .{ .name = "flake.nix", .mtime_ns = 1, .size = 10 }, .{ .name = "plugin", .mtime_ns = 9, .size = 20 } };
	mutations[2].plugin_files = &.{ .{ .name = "flake.nix", .mtime_ns = 1, .size = 11 }, .{ .name = "plugin", .mtime_ns = 2, .size = 20 } };
	mutations[3].plugin_files = &.{.{ .name = "plugin", .mtime_ns = 2, .size = 20 }};
	mutations[4].script = "/s/other";
	mutations[5].script_mtime_ns = 4;
	mutations[6].script_size = 31;
	mutations[7].skip_build_deps = true;
	mutations[8].skip_runtime_deps = true;
	mutations[9].env = &.{ .{ .name = "PATH", .value = "/usr/bin" }, .{ .name = "JUMPSCRIPT_ROC", .value = "/r/roc" } };
	mutations[10].env = &.{.{ .name = "PATH", .value = "/bin" }};
	var base_buf: [64]u8 = undefined;
	const base = try metaCacheKey(std.testing.allocator, base_inputs, &base_buf);
	for (mutations) |m| {
		var buf: [64]u8 = undefined;
		try std.testing.expect(!eql(base, try metaCacheKey(std.testing.allocator, m, &buf)));
	}
	// Field boundaries are unambiguous: moving bytes between name and value changes the key.
	var split = base_inputs;
	split.env = &.{ .{ .name = "PATH", .value = "/bin" }, .{ .name = "JUMPSCRIPT_RO", .value = "C/r/roc" } };
	var split_buf: [64]u8 = undefined;
	try std.testing.expect(!eql(base, try metaCacheKey(std.testing.allocator, split, &split_buf)));
}

test "meta cache file: render then parse round-trips stamps and meta text" {
	const a = std.testing.allocator;
	const stamps = [_]Stamp{ .{ .path = "/s/lib a.h", .mtime_ns = -5 }, .{ .path = "/s/b.h", .mtime_ns = 1791134550123456789 } };
	const meta_text = "out_rel=bin/x\nbuild_cmd=cc\n";
	const text = try renderMetaCache(a, &stamps, meta_text);
	defer a.free(text);
	var parsed = parseMetaCache(text) orelse return error.TestUnexpectedNull;
	try std.testing.expectEqualStrings(meta_text, parsed.meta_text);
	var got: [2]Stamp = undefined;
	var n: usize = 0;
	while (parsed.stamps.next()) |s| : (n += 1) got[n] = s;
	try std.testing.expectEqual(@as(usize, 2), n);
	try std.testing.expectEqualDeep(stamps, got);
}

test "meta cache file: foreign or damaged files are rejected, unrepresentable paths refused" {
	const rejected = [_][]const u8{ "", "garbage", "jumpscript-meta-cache 2\n\nx=y\n", "jumpscript-meta-cache 1\nstamp x /p\n\n", "jumpscript-meta-cache 1\nstamp 5\n\n", "jumpscript-meta-cache 1\nstamp 5 /p\n" };
	for (rejected) |t| try std.testing.expect(parseMetaCache(t) == null);
	try std.testing.expectError(error.UnrepresentablePath, renderMetaCache(std.testing.allocator, &.{.{ .path = "/a\nb", .mtime_ns = 0 }}, ""));
}

/// Environment variables a plugin's meta may depend on, and so part of the
/// meta-cache key: PATH (plugins find host tools there) and every
/// JUMPSCRIPT_* variable except the two the runner sets from its own flags.
pub fn metaKeyEnv(name: []const u8) bool {
	if (eql(name, "PATH")) return true;
	if (eql(name, "JUMPSCRIPT_NO_BUILD_DEPS") or eql(name, "JUMPSCRIPT_NO_RUNTIME_DEPS")) return false;
	return std.mem.startsWith(u8, name, "JUMPSCRIPT_");
}

pub const FileStamp = struct { name: []const u8, mtime_ns: i128, size: u64 };
pub const EnvPair = struct { name: []const u8, value: []const u8 };

/// Everything a plugin's meta answer is assumed to depend on.
pub const MetaKeyInputs = struct {
	plugin_exec: []const u8,
	/// The regular files directly in the plugin directory.
	plugin_files: []const FileStamp,
	script: []const u8,
	script_mtime_ns: i128,
	script_size: u64,
	skip_build_deps: bool,
	skip_runtime_deps: bool,
	/// Already filtered with metaKeyEnv.
	env: []const EnvPair,
};

/// The meta-cache entry name: SHA-256 (hex) over a length-prefixed encoding
/// of the inputs, with plugin files and env sorted by name so their order
/// does not matter.
pub fn metaCacheKey(gpa: std.mem.Allocator, in: MetaKeyInputs, out: *[64]u8) ![]const u8 {
	const files = try gpa.dupe(FileStamp, in.plugin_files);
	defer gpa.free(files);
	std.mem.sortUnstable(FileStamp, files, {}, struct {
		fn lt(_: void, x: FileStamp, y: FileStamp) bool {
			return std.mem.lessThan(u8, x.name, y.name);
		}
	}.lt);
	const env = try gpa.dupe(EnvPair, in.env);
	defer gpa.free(env);
	std.mem.sortUnstable(EnvPair, env, {}, struct {
		fn lt(_: void, x: EnvPair, y: EnvPair) bool {
			return std.mem.lessThan(u8, x.name, y.name);
		}
	}.lt);

	var h = std.crypto.hash.sha2.Sha256.init(.{});
	const H = struct {
		fn bytes(hh: *std.crypto.hash.sha2.Sha256, b: []const u8) void {
			hh.update(std.mem.asBytes(&@as(u64, b.len)));
			hh.update(b);
		}
		fn int(hh: *std.crypto.hash.sha2.Sha256, v: anytype) void {
			const w: i128 = v;
			hh.update(std.mem.asBytes(&w));
		}
	};
	H.bytes(&h, "jumpscript-meta-key 1");
	H.bytes(&h, in.plugin_exec);
	H.int(&h, files.len);
	for (files) |f| {
		H.bytes(&h, f.name);
		H.int(&h, f.mtime_ns);
		H.int(&h, f.size);
	}
	H.bytes(&h, in.script);
	H.int(&h, in.script_mtime_ns);
	H.int(&h, in.script_size);
	H.int(&h, @intFromBool(in.skip_build_deps));
	H.int(&h, @intFromBool(in.skip_runtime_deps));
	H.int(&h, env.len);
	for (env) |e| {
		H.bytes(&h, e.name);
		H.bytes(&h, e.value);
	}
	const digest = h.finalResult();
	out.* = std.fmt.bytesToHex(digest, .lower);
	return out;
}

/// A file whose mtime a cached meta answer depends on.
pub const Stamp = struct { path: []const u8, mtime_ns: i128 };

const meta_cache_header = "jumpscript-meta-cache 1\n";

/// Serializes a cached meta answer: a header, one `stamp <mtime_ns> <path>`
/// line per dependency, a blank line, then the plugin's meta text verbatim.
pub fn renderMetaCache(gpa: std.mem.Allocator, stamps: []const Stamp, meta_text: []const u8) ![]u8 {
	var out: std.ArrayList(u8) = .empty;
	errdefer out.deinit(gpa);
	try out.appendSlice(gpa, meta_cache_header);
	for (stamps) |s| {
		if (s.path.len == 0 or std.mem.findScalar(u8, s.path, '\n') != null) return error.UnrepresentablePath;
		try out.print(gpa, "stamp {d} {s}\n", .{ s.mtime_ns, s.path });
	}
	try out.append(gpa, '\n');
	try out.appendSlice(gpa, meta_text);
	return out.toOwnedSlice(gpa);
}

pub const ParsedMetaCache = struct {
	stamps: StampIterator,
	meta_text: []const u8,
};

pub const StampIterator = struct {
	lines: std.mem.SplitIterator(u8, .scalar),

	pub fn next(it: *StampIterator) ?Stamp {
		const line = it.lines.next() orelse return null;
		return parseStampLine(line);
	}
};

fn parseStampLine(line: []const u8) ?Stamp {
	const rest = std.mem.cutPrefix(u8, line, "stamp ") orelse return null;
	const sp = std.mem.findScalar(u8, rest, ' ') orelse return null;
	const mtime = std.fmt.parseInt(i128, rest[0..sp], 10) catch return null;
	const path = rest[sp + 1 ..];
	if (path.len == 0) return null;
	return .{ .path = path, .mtime_ns = mtime };
}

/// Parses a meta-cache file, or null for anything renderMetaCache would not
/// have written (wrong header or version, a malformed stamp, no separator).
pub fn parseMetaCache(text: []const u8) ?ParsedMetaCache {
	const body = std.mem.cutPrefix(u8, text, meta_cache_header) orelse return null;
	const sep = if (std.mem.startsWith(u8, body, "\n")) 0 else (std.mem.find(u8, body, "\n\n") orelse return null) + 1;
	const stamp_text = body[0..sep -| 1];
	if (sep > 0) {
		var check = std.mem.splitScalar(u8, stamp_text, '\n');
		while (check.next()) |line| _ = parseStampLine(line) orelse return null;
	}
	return .{
		.stamps = .{ .lines = std.mem.splitScalar(u8, if (sep > 0) stamp_text else "", '\n') },
		.meta_text = body[sep + 1 ..],
	};
}
