#!/usr/bin/env -S jumpscript Zig

const std = @import("std");
const helper = @import("./hello_helper.zig");

pub fn main(init: std.process.Init) !void {
	var buf: [256]u8 = undefined;
	var stdout = std.Io.File.stdout().writer(init.io, &buf);
	try stdout.interface.print("{s}\n", .{helper.message()});
	try stdout.interface.flush();
}
