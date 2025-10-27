#!/usr/bin/env -S jumpscript Zig

const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Zig integration OK\n", .{});

    const args = std.os.argv;
    if (args.len > 1) {
        const first = std.mem.span(args[1]);
        try stdout.print("arg={s}\n", .{first});
    }
}
