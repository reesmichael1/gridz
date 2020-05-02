const std = @import("std");

const Player = @import("player.zig").Player;

/// A City is a location that up to three Players can settle in.
/// Cities are connected to each other as specified in the Board.
pub const City = struct {
    /// The name displayed for this City
    name: []const u8,
    /// The first (if any) player to settle in the City
    firstPlayer: ?Player = null,
    /// The second (if any) player to settle in the City
    secondPlayer: ?Player = null,
    /// The third (if any) player to settle in the City
    thirdPlayer: ?Player = null,
    /// X coordinate of City on map
    x: u8,
    /// Y coordinate of City on map
    y: u8,

    pub fn init(name: []const u8, x: u8, y: u8) City {
        return City{
            .name = name,
            .x = x,
            .y = y,
        };
    }

    pub fn eq(self: City, other: City) bool {
        return std.mem.eql(u8, self.name, other.name) and self.x == other.x and self.y == other.y;
    }
};
