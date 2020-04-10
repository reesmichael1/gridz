const std = @import("std");
const Allocator = std.mem.Allocator;

const City = @import("city.zig").City;

/// A Grid holds the layout of all Cities on the map
pub const Grid = struct {
    /// A list of Cities playable in the board
    cities: []City,
    /// An incidence matrix of the connections between Cities
    connections: [][]u8,

    pub fn init(allocator: *Allocator) Grid {
        var cities = std.ArrayList(City).init(allocator);
        return Grid{
            .cities = cities.items,
            .connections = &[_][]u8{},
        };
    }
};
