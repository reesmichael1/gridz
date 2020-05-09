const std = @import("std");

const Game = @import("game.zig").Game;

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;
    var game = try Game.init(allocator);
    defer game.deinit();

    while (!game.has_ended) {
        try game.nextTurn();
    }
}
