#!/usr/bin/env -S jumpscript Zig

const std = @import("std");

pub fn main(init: std.process.Init) !void {
	var buf: [256]u8 = undefined;
	var stdout = std.Io.File.stdout().writer(init.io, &buf);
	const out = &stdout.interface;
	try out.print("Zig integration OK\n", .{});

	const args = try init.minimal.args.toSlice(init.arena.allocator());
	if (args.len > 1) try out.print("arg={s}\n", .{args[1]});
	try out.flush();
}
