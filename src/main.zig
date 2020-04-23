const std = @import("std");

const Game = @import("game.zig").Game;

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;
    var game = try Game.init(allocator);

    for (game.gen_market) |gen| {
        std.debug.warn("market: {}\n", .{gen});
    }

    std.debug.warn("\n", .{});

    for (game.future_gens) |gen| {
        std.debug.warn("future market: {}\n", .{gen});
    }

    std.debug.warn("\n", .{});

    for (game.hidden_generators) |gen| {
        std.debug.warn("hidden generator: {}\n", .{gen});
    }
}
