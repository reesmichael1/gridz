const std = @import("std");
const Allocator = std.mem.Allocator;

const City = @import("city.zig").City;
const Loader = @import("loader.zig").Loader;

/// A Grid holds the layout of all Cities on the map
pub const Grid = struct {
    /// A list of Cities playable in the board
    cities: []City,
    /// An adjacency matrix of the connections between Cities
    connections: [][]u8,

    pub fn init(allocator: *Allocator, loader: Loader) Grid {
        const cities = loader.loadCities();
        const connections = loader.loadConnections(cities);

        return Grid{
            .cities = cities,
            .connections = connections,
        };
    }
};
