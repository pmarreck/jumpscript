//! The jumpscript runner's I/O adapter: environment, filesystem, plugin and
//! build processes, and the final exec. Every decision comes from core.zig.
const std = @import("std");
const builtin = @import("builtin");
const core = @import("core");
const build_options = @import("build_options");
const Io = std.Io;
const Dir = std.Io.Dir;

const purpose = "cached edit-run harness for compiled languages";
const summary = "jumpscript: " ++ purpose;
/// --about: name, version, purpose, and the OS and CPU the binary was built for.
const about_line = std.fmt.comptimePrint("jumpscript {s}: {s} ({s} {s})\n", .{ build_options.version, purpose, @tagName(builtin.os.tag), @tagName(builtin.cpu.arch) });
const secure_mode: std.posix.mode_t = 0o700;
const meta_dir_name = ".meta";

/// Process-wide context: one arena for the whole (short) run, the Io, and
/// the process environment, read raw. A full environment map is built only
/// when a child needs a changed environment, because building one costs
/// more than the rest of a warm run.
const Ctx = struct {
	arena: std.mem.Allocator,
	io: Io,
	environ: std.process.Environ,
	cwd: Dir,
	/// The runner's --no-* flags, exported to every child as
	/// JUMPSCRIPT_NO_BUILD_DEPS / JUMPSCRIPT_NO_RUNTIME_DEPS (set to 1, or unset).
	skip_build_deps: bool = false,
	skip_runtime_deps: bool = false,

	/// An environment value, with an empty value treated as unset (Bash `:-`).
	fn getenv(ctx: Ctx, name: []const u8) ?[]const u8 {
		const v = ctx.environ.getPosix(name) orelse return null;
		return if (v.len == 0) null else v;
	}

	/// The environment children get: null (inherit unchanged) when the
	/// flag variables already match and there is nothing extra to add.
	fn childEnv(ctx: Ctx, extra: []const [2][]const u8) ?*const std.process.Environ.Map {
		if (extra.len == 0 and flagMatches(ctx, "JUMPSCRIPT_NO_BUILD_DEPS", ctx.skip_build_deps) and
			flagMatches(ctx, "JUMPSCRIPT_NO_RUNTIME_DEPS", ctx.skip_runtime_deps)) return null;
		const map = ctx.arena.create(std.process.Environ.Map) catch oom();
		map.* = ctx.environ.createMap(ctx.arena) catch oom();
		setFlag(map, "JUMPSCRIPT_NO_BUILD_DEPS", ctx.skip_build_deps);
		setFlag(map, "JUMPSCRIPT_NO_RUNTIME_DEPS", ctx.skip_runtime_deps);
		for (extra) |v| map.put(v[0], v[1]) catch oom();
		return map;
	}

	fn flagMatches(ctx: Ctx, name: []const u8, on: bool) bool {
		const v = ctx.environ.getPosix(name);
		return if (on) (v != null and std.mem.eql(u8, v.?, "1")) else v == null;
	}

	fn print(ctx: Ctx, comptime fmt: []const u8, args: anytype) []u8 {
		return std.fmt.allocPrint(ctx.arena, fmt, args) catch oom();
	}

	fn die(ctx: Ctx, status: u8, comptime fmt: []const u8, args: anytype) noreturn {
		const msg = std.fmt.allocPrint(ctx.arena, "Error: " ++ fmt ++ "\n", args) catch oom();
		Io.File.stderr().writeStreamingAll(ctx.io, msg) catch {};
		std.process.exit(status);
	}
};

fn oom() noreturn {
	std.process.exit(70);
}

pub fn main(init: std.process.Init.Minimal) u8 {
	var arena_state: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
	const arena = arena_state.allocator();
	var threaded: std.Io.Threaded = .init(arena, .{ .environ = init.environ });
	const ctx: Ctx = .{ .arena = arena, .io = threaded.io(), .environ = init.environ, .cwd = Dir.cwd() };
	if (comptime builtin.mode == .Debug) {
		if (ctx.getenv("MUTE_DEBUG_STATUS") == null) Io.File.stderr().writeStreamingAll(ctx.io, "\x1b[33mDEBUG BUILD\x1b[0m\n") catch {};
	}
	const raw_args = init.args.toSlice(arena) catch oom();
	const args = arena.alloc([]const u8, raw_args.len -| 1) catch oom();
	for (args, 0..) |*a, i| a.* = raw_args[i + 1];

	const paths = pluginRoots(ctx);
	switch (core.parseArgs(args)) {
		.about => {
			writeOut(ctx, about_line);
			return 0;
		},
		.help => {
			writeOut(ctx, helpText(ctx, paths));
			return 0;
		},
		.fail => |f| switch (f.reason) {
			.no_command => ctx.die(1, "no command provided", .{}),
			.unsupported_option => ctx.die(1, "unsupported option '{s}'", .{f.arg}),
			.no_lang => ctx.die(1, "language token is required", .{}),
			.no_script => ctx.die(1, "script path is required", .{}),
		},
		.run => |r| run(ctx, paths, r),
	}
}

fn writeOut(ctx: Ctx, text: []const u8) void {
	Io.File.stdout().writeStreamingAll(ctx.io, text) catch {};
}

const Roots = struct { bundled: []const u8, user: []const u8 };

/// Bundled plugins live beside the binary's directory (`<prefix>/plugins`
/// next to `<prefix>/bin`), else in it; both roots can be overridden.
fn pluginRoots(ctx: Ctx) Roots {
	var buf: [Dir.max_path_bytes]u8 = undefined;
	const n = std.process.executableDirPath(ctx.io, &buf) catch ctx.die(1, "unable to locate the jumpscript executable", .{});
	const exe_dir = ctx.arena.dupe(u8, buf[0..n]) catch oom();
	const parent = std.fs.path.dirname(exe_dir) orelse exe_dir;
	const repo_plugins = ctx.print("{s}/plugins", .{parent});
	const base = if (isDir(ctx, repo_plugins)) parent else exe_dir;
	const bundled = ctx.getenv("JUMPSCRIPT_PLUGINS_DIR") orelse ctx.print("{s}/plugins", .{base});
	const data_home = ctx.getenv("XDG_DATA_HOME") orelse ctx.print("{s}/.local/share", .{ctx.getenv("HOME") orelse ""});
	const user = ctx.getenv("JUMPSCRIPT_USER_PLUGINS") orelse ctx.print("{s}/jumpscript/plugins", .{data_home});
	return .{ .bundled = bundled, .user = user };
}

fn defaultCacheRoot(ctx: Ctx) []const u8 {
	const cache_home = ctx.getenv("XDG_CACHE_HOME") orelse ctx.print("{s}/.cache", .{ctx.getenv("HOME") orelse ""});
	return ctx.print("{s}/jumpscript-artifacts", .{cache_home});
}

fn helpText(ctx: Ctx, roots: Roots) []const u8 {
	const default_cache = defaultCacheRoot(ctx);
	return ctx.print(
		\\Usage: jumpscript run <Language[-Version]> <script> [args...]
		\\
		\\{s}
		\\
		\\Cache:
		\\  Default cache root: {s}
		\\  Current cache root: {s}
		\\  Cache overrides: JUMPSCRIPT_CACHE, XDG_CACHE_HOME
		\\
		\\Plugins:
		\\  Bundled plugins dir: {s}
		\\  Plugins override: JUMPSCRIPT_PLUGINS_DIR
		\\
		\\User Plugins:
		\\  User plugins search root: {s}
		\\  User plugins overrides: JUMPSCRIPT_USER_PLUGINS, XDG_DATA_HOME
		\\
	, .{ summary, default_cache, ctx.getenv("JUMPSCRIPT_CACHE") orelse default_cache, roots.bundled, roots.user });
}

fn statPath(ctx: Ctx, path: []const u8) ?Io.File.Stat {
	return ctx.cwd.statFile(ctx.io, path, .{}) catch null;
}

fn isDir(ctx: Ctx, path: []const u8) bool {
	const st = statPath(ctx, path) orelse return false;
	return st.kind == .directory;
}

fn isFile(ctx: Ctx, path: []const u8) bool {
	const st = statPath(ctx, path) orelse return false;
	return st.kind == .file;
}

fn isExecutable(ctx: Ctx, path: []const u8) bool {
	ctx.cwd.access(ctx.io, path, .{ .execute = true }) catch return false;
	return true;
}

fn mtimeNs(st: Io.File.Stat) i128 {
	return st.mtime.toNanoseconds();
}

/// The runner's cache directories are private: an existing one must be
/// mode 700, a missing one is created (with parents) and set to 700.
fn ensureSecureDir(ctx: Ctx, path: []const u8, comptime what: []const u8) void {
	if (statPath(ctx, path)) |st| {
		const mode = st.permissions.toMode() & 0o7777;
		if (mode != secure_mode) ctx.die(1, what ++ " '{s}' has permissions {o}; expected 700", .{ path, mode });
		return;
	}
	ctx.cwd.createDirPath(ctx.io, path) catch |e| ctx.die(1, "unable to create '{s}': {t}", .{ path, e });
	ctx.cwd.setFilePermissions(ctx.io, path, .fromMode(secure_mode), .{}) catch |e| ctx.die(1, "unable to set permissions of '{s}': {t}", .{ path, e });
}

/// A plugin's meta answer with the stamps (dependency mtimes) it was
/// checked against.
const Answer = struct {
	text: []const u8,
	meta: core.Meta,
	deps: []const core.Stamp,
};

fn run(base_ctx: Ctx, roots: Roots, r: core.Run) noreturn {
	var ctx = base_ctx;
	ctx.skip_build_deps = r.skip_build_deps;
	ctx.skip_runtime_deps = r.skip_runtime_deps;
	const script_stat = statPath(ctx, r.script);
	if (script_stat == null or script_stat.?.kind != .file) ctx.die(1, "script '{s}' not found", .{r.script});
	const script = absolutePath(ctx, r.script);
	const tok = core.splitLangToken(r.lang_token);

	const plugin_dir = findPlugin(ctx, roots, tok);
	const plugin_exec = ctx.print("{s}/plugin", .{plugin_dir});
	if (!isExecutable(ctx, plugin_exec)) ctx.die(1, "plugin executable not found at {s}", .{plugin_exec});

	const cache_root = ctx.getenv("JUMPSCRIPT_CACHE") orelse defaultCacheRoot(ctx);
	ensureSecureDir(ctx, cache_root, "cache root");
	const lang_dir = ctx.print("{s}/{s}", .{ cache_root, tok.lang });
	const version_dir = ctx.print("{s}/{s}", .{ lang_dir, tok.version });
	ensureSecureDir(ctx, lang_dir, "directory");
	ensureSecureDir(ctx, version_dir, "directory");

	const script_dir = std.fs.path.dirname(script) orelse "/";
	const answer = metaAnswer(ctx, .{
		.lang = tok.lang,
		.plugin_dir = plugin_dir,
		.plugin_exec = plugin_exec,
		.script = script,
		.script_dir = script_dir,
		.script_stat = script_stat.?,
		.run = r,
		.cache_root = cache_root,
	});
	const meta = answer.meta;

	var newest = mtimeNs(script_stat.?);
	var freshest: []const u8 = script;
	for (answer.deps) |d| {
		if (d.mtime_ns > newest) {
			newest = d.mtime_ns;
			freshest = d.path;
		}
	}

	var key_buf: [Dir.max_path_bytes]u8 = undefined;
	const key = core.entryKey(&key_buf, std.fs.path.basename(script), newest) catch ctx.die(1, "script name too long", .{});
	const entry_dir = ctx.print("{s}/{s}", .{ version_dir, key });
	ensureSecureDir(ctx, entry_dir, "directory");

	if (core.outRelEscapes(meta.out_rel)) ctx.die(1, "plugin '{s}' out_rel '{s}' escapes cache entry", .{ tok.lang, meta.out_rel });
	const artifact = ctx.print("{s}/{s}", .{ entry_dir, meta.out_rel });
	writeMetaEnv(ctx, entry_dir, meta);
	const artifact_dir = std.fs.path.dirname(artifact) orelse entry_dir;
	if (!std.mem.eql(u8, artifact_dir, entry_dir)) ensureSecureDir(ctx, artifact_dir, "directory");

	const artifact_mtime: ?i128 = if (statPath(ctx, artifact)) |st| (if (st.kind == .file) mtimeNs(st) else null) else null;
	if (core.needsBuild(artifact_mtime, newest)) build(ctx, .{
		.lang = tok.lang,
		.meta = meta,
		.entry_dir = entry_dir,
		.artifact = artifact,
		.script = script,
		.script_dir = script_dir,
		.deps = answer.deps,
		.freshest = freshest,
	});

	execute(ctx, tok.lang, meta, artifact, script, r.script_args);
}

/// Bash's `$(cd "$(dirname p)" && pwd)/$(basename p)` for a relative path:
/// the current directory joined and lexically normalized.
fn absolutePath(ctx: Ctx, path: []const u8) []const u8 {
	if (std.fs.path.isAbsolute(path)) return path;
	const cwd = std.process.currentPathAlloc(ctx.io, ctx.arena) catch |e| ctx.die(1, "unable to read the current directory: {t}", .{e});
	return std.fs.path.resolve(ctx.arena, &.{ cwd, path }) catch oom();
}

fn findPlugin(ctx: Ctx, roots: Roots, tok: core.LangToken) []const u8 {
	const search = [_][]const u8{ roots.user, roots.bundled };
	for (search) |root| {
		if (root.len == 0) continue;
		const candidate = ctx.print("{s}/{s}/{s}", .{ root, tok.lang, tok.version });
		if (isDir(ctx, candidate)) return candidate;
	}
	ctx.die(1, "plugin not found for language '{s}' version '{s}' (searched: {s},{s})", .{ tok.lang, tok.version, roots.user, roots.bundled });
}

fn setFlag(map: *std.process.Environ.Map, name: []const u8, on: bool) void {
	if (on) {
		map.put(name, "1") catch oom();
	} else {
		_ = map.swapRemove(name);
	}
}

const MetaRequest = struct {
	lang: []const u8,
	plugin_dir: []const u8,
	plugin_exec: []const u8,
	script: []const u8,
	script_dir: []const u8,
	script_stat: Io.File.Stat,
	run: core.Run,
	/// Cached answers live in <cache root>/.meta, keyed by everything they depend on
	/// (the plugin path included), outside the per-language build entries.
	cache_root: []const u8,
};

/// The plugin's meta answer: from the meta cache when its key matches and
/// its stamps and runtime still hold, else from the plugin (then cached).
fn metaAnswer(ctx: Ctx, req: MetaRequest) Answer {
	var key_buf: [64]u8 = undefined;
	const key = core.metaCacheKey(ctx.arena, .{
		.plugin_exec = req.plugin_exec,
		.plugin_files = pluginFiles(ctx, req.plugin_dir),
		.script = req.script,
		.script_mtime_ns = mtimeNs(req.script_stat),
		.script_size = req.script_stat.size,
		.skip_build_deps = req.run.skip_build_deps,
		.skip_runtime_deps = req.run.skip_runtime_deps,
		.env = keyEnv(ctx),
	}, &key_buf) catch oom();
	const meta_dir = ctx.print("{s}/{s}", .{ req.cache_root, meta_dir_name });
	const cache_file = ctx.print("{s}/{s}", .{ meta_dir, key });
	if (cachedAnswer(ctx, cache_file)) |a| return a;

	const text = runMeta(ctx, req);
	const meta = core.parseMeta(text);
	if (core.validateMeta(meta)) |problem| switch (problem) {
		.missing_field => |f| ctx.die(1, "plugin '{s}' meta output missing required field '{s}'", .{ req.lang, f }),
		.unsupported_rebuild_mode => |m| ctx.die(1, "plugin '{s}' requested unsupported rebuild_mode '{s}'", .{ req.lang, m }),
		.unsupported_exec_kind => |k| ctx.die(1, "plugin '{s}' reported unsupported exec_kind '{s}'", .{ req.lang, k }),
	};
	const dep_paths = core.resolveDeps(ctx.arena, meta.deps, req.script_dir) catch oom();
	const stamps = ctx.arena.alloc(core.Stamp, dep_paths.len) catch oom();
	var rel = std.mem.splitScalar(u8, meta.deps, ':');
	for (dep_paths, stamps) |p, *s| {
		var dep_rel = rel.next() orelse "";
		while (dep_rel.len == 0) dep_rel = rel.next() orelse break;
		const st = statPath(ctx, p) orelse ctx.die(1, "dependency '{s}' for script '{s}' not found", .{ dep_rel, req.script });
		s.* = .{ .path = p, .mtime_ns = mtimeNs(st) };
	}

	ensureSecureDir(ctx, meta_dir, "directory");
	storeAnswer(ctx, meta_dir, key, stamps, text);
	return .{ .text = text, .meta = meta, .deps = stamps };
}

/// The regular files directly in the plugin directory, stamped for the key.
fn pluginFiles(ctx: Ctx, plugin_dir: []const u8) []const core.FileStamp {
	var dir = ctx.cwd.openDir(ctx.io, plugin_dir, .{ .iterate = true }) catch |e| ctx.die(1, "unable to read plugin directory '{s}': {t}", .{ plugin_dir, e });
	defer dir.close(ctx.io);
	var list: std.ArrayList(core.FileStamp) = .empty;
	var it = dir.iterate();
	while (it.next(ctx.io) catch |e| ctx.die(1, "unable to read plugin directory '{s}': {t}", .{ plugin_dir, e })) |entry| {
		const st = dir.statFile(ctx.io, entry.name, .{}) catch continue;
		if (st.kind != .file) continue;
		list.append(ctx.arena, .{ .name = ctx.arena.dupe(u8, entry.name) catch oom(), .mtime_ns = mtimeNs(st), .size = st.size }) catch oom();
	}
	return list.items;
}

/// The meta-key variables, read straight from the raw `NAME=value` block.
fn keyEnv(ctx: Ctx) []const core.EnvPair {
	var list: std.ArrayList(core.EnvPair) = .empty;
	for (ctx.environ.block.view().slice) |entry_z| {
		const entry = std.mem.sliceTo(entry_z, 0);
		const eq = std.mem.findScalar(u8, entry, '=') orelse continue;
		if (core.metaKeyEnv(entry[0..eq])) list.append(ctx.arena, .{ .name = entry[0..eq], .value = entry[eq + 1 ..] }) catch oom();
	}
	return list.items;
}

/// A cached answer still valid: well-formed, a meta that passes validation,
/// every dependency at its stamped mtime, and an absolute runtime program
/// that still exists (a garbage-collected Nix store path would not).
fn cachedAnswer(ctx: Ctx, cache_file: []const u8) ?Answer {
	const text = ctx.cwd.readFileAlloc(ctx.io, cache_file, ctx.arena, .unlimited) catch return null;
	var parsed = core.parseMetaCache(text) orelse return null;
	const meta = core.parseMeta(parsed.meta_text);
	if (core.validateMeta(meta) != null) return null;
	var stamps: std.ArrayList(core.Stamp) = .empty;
	while (parsed.stamps.next()) |s| {
		const st = statPath(ctx, s.path) orelse return null;
		if (mtimeNs(st) != s.mtime_ns) return null;
		stamps.append(ctx.arena, s) catch oom();
	}
	var words = std.mem.tokenizeAny(u8, meta.runtime_cmd, " \t\n");
	if (words.next()) |program| {
		if (std.fs.path.isAbsolute(program) and statPath(ctx, program) == null) return null;
	}
	return .{ .text = parsed.meta_text, .meta = meta, .deps = stamps.items };
}

/// Writes the cache file atomically (temporary file, then rename), so a
/// concurrent run never reads half an answer. Failure only costs the cache.
fn storeAnswer(ctx: Ctx, meta_dir: []const u8, key: []const u8, stamps: []const core.Stamp, text: []const u8) void {
	const body = core.renderMetaCache(ctx.arena, stamps, text) catch return;
	var rnd: [8]u8 = undefined;
	ctx.io.random(&rnd);
	const tmp = ctx.print("{s}/{s}.{x}.tmp", .{ meta_dir, key, rnd });
	ctx.cwd.writeFile(ctx.io, .{ .sub_path = tmp, .data = body }) catch return;
	ctx.cwd.rename(tmp, ctx.cwd, ctx.print("{s}/{s}", .{ meta_dir, key }), ctx.io) catch {
		ctx.cwd.deleteFile(ctx.io, tmp) catch {};
	};
}

/// Runs `plugin meta <script>` with stdout captured and stderr passed
/// through, exiting with the plugin's status if it fails.
fn runMeta(ctx: Ctx, req: MetaRequest) []const u8 {
	var child = std.process.spawn(ctx.io, .{
		.argv = &.{ req.plugin_exec, "meta", req.script },
		.environ_map = ctx.childEnv(&.{}),
		.stdout = .pipe,
	}) catch |e| ctx.die(1, "unable to run plugin '{s}': {t}", .{ req.plugin_exec, e });
	var buf: [4096]u8 = undefined;
	var reader = child.stdout.?.reader(ctx.io, &buf);
	const out = reader.interface.allocRemaining(ctx.arena, .unlimited) catch |e| ctx.die(1, "unable to read plugin '{s}' meta output: {t}", .{ req.lang, e });
	const term = child.wait(ctx.io) catch |e| ctx.die(1, "unable to wait for plugin '{s}': {t}", .{ req.lang, e });
	const status = exitStatus(term);
	if (status != 0) ctx.die(status, "plugin '{s}' meta command failed with exit code {d}", .{ req.lang, status });
	return out;
}

/// A child's status the way a shell reports it: the exit code, or 128 plus
/// the signal number.
fn exitStatus(term: std.process.Child.Term) u8 {
	return switch (term) {
		.exited => |c| c,
		.signal, .stopped => |sig| 128 +% @as(u8, @truncate(@intFromEnum(sig))),
		.unknown => 1,
	};
}

/// meta.env in the cache entry records the answer the entry was built from.
fn writeMetaEnv(ctx: Ctx, entry_dir: []const u8, m: core.Meta) void {
	var text: std.ArrayList(u8) = .empty;
	text.print(ctx.arena, "out_rel={s}\nbuild_cmd={s}\nrebuild_mode={s}\nexec_kind={s}\n", .{ m.out_rel, m.build_cmd, m.rebuild_mode, m.exec_kind }) catch oom();
	if (m.runtime_cmd.len > 0) text.print(ctx.arena, "runtime_cmd={s}\n", .{m.runtime_cmd}) catch oom();
	if (m.deps.len > 0) text.print(ctx.arena, "deps={s}\n", .{m.deps}) catch oom();
	const path = ctx.print("{s}/meta.env", .{entry_dir});
	ctx.cwd.writeFile(ctx.io, .{ .sub_path = path, .data = text.items }) catch |e| ctx.die(1, "unable to write '{s}': {t}", .{ path, e });
}

const BuildRequest = struct {
	lang: []const u8,
	meta: core.Meta,
	entry_dir: []const u8,
	artifact: []const u8,
	script: []const u8,
	script_dir: []const u8,
	deps: []const core.Stamp,
	freshest: []const u8,
};

/// Runs the plugin's build command in the cache entry, then stamps the
/// artifact with the newest source's timestamps (touch -r), which is what
/// marks it fresh.
fn build(ctx: Ctx, b: BuildRequest) void {
	var deps_env: std.ArrayList(u8) = .empty;
	for (b.deps, 0..) |d, i| {
		if (i > 0) deps_env.append(ctx.arena, ':') catch oom();
		deps_env.appendSlice(ctx.arena, d.path) catch oom();
	}
	const vars = [_][2][]const u8{
		.{ "JUMPSCRIPT_ENTRY_DIR", b.entry_dir },
		.{ "JUMPSCRIPT_ARTIFACT", b.artifact },
		.{ "JUMPSCRIPT_SCRIPT", b.script },
		.{ "JUMPSCRIPT_OUT_REL", b.meta.out_rel },
		.{ "JUMPSCRIPT_LANG", b.lang },
		.{ "JUMPSCRIPT_BUILD_CMD", b.meta.build_cmd },
		.{ "JUMPSCRIPT_SCRIPT_DIR", b.script_dir },
		.{ "JUMPSCRIPT_DEPS", deps_env.items },
	};
	var child = std.process.spawn(ctx.io, .{
		.argv = &.{ "bash", "--noprofile", "--norc", "-lc", b.meta.build_cmd },
		.environ_map = ctx.childEnv(&vars),
		.cwd = .{ .path = b.entry_dir },
	}) catch |e| ctx.die(1, "unable to run plugin '{s}' build command: {t}", .{ b.lang, e });
	const status = exitStatus(child.wait(ctx.io) catch |e| ctx.die(1, "unable to wait for plugin '{s}' build: {t}", .{ b.lang, e }));
	if (status != 0) ctx.die(status, "plugin '{s}' build command failed with exit code {d}", .{ b.lang, status });
	if (!isFile(ctx, b.artifact)) ctx.die(1, "plugin '{s}' build command did not produce artifact '{s}'", .{ b.lang, b.meta.out_rel });

	const ref = statPath(ctx, b.freshest) orelse ctx.die(1, "unable to determine mtime for '{s}'", .{b.freshest});
	ctx.cwd.setTimestamps(ctx.io, b.artifact, .{
		.access_timestamp = .init(ref.atime),
		.modify_timestamp = .{ .new = ref.mtime },
	}) catch |e| ctx.die(1, "unable to stamp artifact '{s}': {t}", .{ b.artifact, e });
}

/// Replaces this process with the artifact, or with the plugin's runtime
/// running it; the program inherits the runner's environment.
fn execute(ctx: Ctx, lang: []const u8, meta: core.Meta, artifact: []const u8, script: []const u8, script_args: []const []const u8) noreturn {
	var argv: std.ArrayList([]const u8) = .empty;
	if (std.mem.eql(u8, meta.exec_kind, "bin")) {
		if (!isExecutable(ctx, artifact)) ctx.die(1, "artifact '{s}' is not executable", .{meta.out_rel});
		argv.append(ctx.arena, artifact) catch oom();
	} else {
		if (meta.runtime_cmd.len == 0) ctx.die(1, "plugin '{s}' exec_kind '{s}' requires runtime_cmd", .{ lang, meta.exec_kind });
		const parts = core.expandRuntime(ctx.arena, meta.runtime_cmd, artifact, script) catch oom();
		if (parts.len == 0) ctx.die(1, "plugin '{s}' exec_kind '{s}' requires runtime_cmd", .{ lang, meta.exec_kind });
		argv.appendSlice(ctx.arena, parts) catch oom();
	}
	argv.appendSlice(ctx.arena, script_args) catch oom();
	const err = std.process.replace(ctx.io, .{ .argv = argv.items, .environ_map = ctx.childEnv(&.{}) });
	ctx.die(127, "unable to execute '{s}': {t}", .{ argv.items[0], err });
}
