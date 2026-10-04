const std = @import("std");
const manifest = @import("build.zig.zon");

pub fn build(b: *std.Build) void {
	const target = b.standardTargetOptions(.{});
	const optimize = b.option(std.builtin.OptimizeMode, "optimize", "Optimization mode (default: ReleaseFast)") orelse .ReleaseFast;

	const core = b.createModule(.{
		.root_source_file = b.path("src/core.zig"),
		.target = target,
		.optimize = optimize,
	});

	const options = b.addOptions();
	options.addOption([]const u8, "version", manifest.version);

	const exe = b.addExecutable(.{
		.name = "jumpscript",
		.root_module = b.createModule(.{
			.root_source_file = b.path("src/main.zig"),
			.target = target,
			.optimize = optimize,
			.imports = &.{
				.{ .name = "core", .module = core },
				.{ .name = "build_options", .module = options.createModule() },
			},
			.strip = optimize != .Debug,
		}),
	});
	b.installArtifact(exe);

	const core_tests = b.addTest(.{ .root_module = core });
	const test_step = b.step("test", "Run the core unit tests");
	test_step.dependOn(&b.addRunArtifact(core_tests).step);
}
