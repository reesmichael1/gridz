const std = @import("std");

pub fn getNumberFromUser(comptime T: type, comptime prompt: []const u8, args: anytype) !T {
    const stdout = std.io.getStdOut().writer();

    while (true) {
        var line_buf: [10]u8 = undefined;
        const line = try askUserForInput(prompt, args, &line_buf);

        if (line.len == 0) {
            continue;
        }

        const parsed = std.fmt.parseUnsigned(T, line, 10) catch {
            try stdout.print("Invalid number.\n", .{});
            continue;
        };

        return parsed;
    }
}

pub fn askYesOrNo(comptime prompt: []const u8, args: anytype) !bool {
    const stdout = std.io.getStdOut().writer();

    while (true) {
        var line_buf: [10]u8 = undefined;
        const answer = try askUserForInput(prompt, args, &line_buf);

        if (std.mem.eql(u8, answer, &[_]u8{'y'})) {
            return true;
        } else if (std.mem.eql(u8, answer, &[_]u8{'n'})) {
            return false;
        } else {
            try stdout.print("Unrecognized input--please enter 'y' or 'n'\n", .{});
        }
    }
}

pub fn askUserForInput(comptime prompt: []const u8, args: anytype, buf: []u8) ![]const u8 {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn();

    while (true) {
        try stdout.print(prompt, args);

        const amt = try stdin.read(buf);
        if (amt == buf.len) {
            try stdout.print("Input too long\n", .{});
            continue;
        }

        return std.mem.trimRight(u8, buf[0..amt], "\r\n");
    }
}
