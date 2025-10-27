#!/usr/bin/env jumpscript -S Zig
# nix: {
#   buildInputs = [];
# }

const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Hello from Zig!\n", .{});
    
    // Process command line arguments
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    if (args.len > 1) {
        try stdout.print("Arguments:\n", .{});
        for (args[1..], 0..) |arg, i| {
            try stdout.print("  {d}: {s}\n", .{ i + 1, arg });
        }
        
        // Try to parse numeric arguments and calculate their sum
        var sum: i64 = 0;
        var has_numeric = false;
        
        for (args[1..]) |arg| {
            const parsed = std.fmt.parseInt(i64, arg, 10) catch continue;
            sum += parsed;
            has_numeric = true;
        }
        
        if (has_numeric) {
            try stdout.print("Sum of numeric arguments: {d}\n", .{sum});
        }
    }
}
