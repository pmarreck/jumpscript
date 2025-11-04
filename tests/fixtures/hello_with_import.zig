#!/usr/bin/env -S jumpscript Zig

const std = @import("std");
const helper = @import("./hello_helper.zig");

pub fn main() !void {
	const stdout = std.io.getStdOut().writer();
	try stdout.print("{s}\n", .{helper.message()});
}
