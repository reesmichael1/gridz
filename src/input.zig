const std = @import("std");

pub fn getNumberFromUser(comptime T: type, comptime prompt: []const u8, args: var) !T {
    const stdout = std.io.getStdOut().outStream();
    const stdin = std.io.getStdIn();

    while (true) {
        try stdout.print(prompt, args);
        var line_buf: [10]u8 = undefined;
        const input = try stdin.read(&line_buf);
        if (input == line_buf.len) {
            try stdout.print("Input too long.\n", .{});
            continue;
        }

        const line = std.mem.trimRight(u8, line_buf[0..input], "\r\n");

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

pub fn askYesOrNo(comptime prompt: []const u8, args: var) !bool {
    const stdout = std.io.getStdOut().outStream();
    const stdin = std.io.getStdIn();

    while (true) {
        try stdout.print(prompt, args);
        var line_buf: [10]u8 = undefined;
        const amt = try stdin.read(&line_buf);

        // This can cause some annoying behavior if you abuse it...so, don't abuse it :)
        // It's temporary anyway until we have a GUI.
        if (amt == line_buf.len) {
            try stdout.print("Input too long--please type 'y' or 'n'\n", .{});
            continue;
        }

        const answer = std.mem.trimRight(u8, line_buf[0..amt], "\r\n");
        if (std.mem.eql(u8, answer, &[_]u8{'y'})) {
            return true;
        } else if (std.mem.eql(u8, answer, &[_]u8{'n'})) {
            return false;
        } else {
            try stdout.print("Unrecognized input--please enter 'y' or 'n'\n", .{});
        }
    }
}
