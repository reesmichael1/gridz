const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

const City = @import("city.zig").City;
const Loader = @import("loader.zig").Loader;

/// A Grid holds the layout of all Cities on the map
pub const Grid = struct {
    /// A list of Cities playable in the board
    cities: []City,
    /// An adjacency matrix of the connections between Cities
    connections: [][]u8,

    pub fn init(allocator: *Allocator, loader: Loader) !Grid {
        const cities = try loader.loadCities();
        const connections = try loader.loadConnections(cities);

        return Grid{
            .cities = cities,
            .connections = connections,
        };
    }

    pub fn cityAtCoords(self: Grid, x: u8, y: u8) ?City {
        for (self.cities) |city| {
            if (city.x == x and city.y == y) {
                return city;
            }
        }

        return null;
    }

    pub fn getConnections(self: Grid, allocator: *Allocator, city: City) ![]City {
        var maybe_ix: ?usize = null;
        for (self.cities) |c, index| {
            if (c.eq(city)) {
                maybe_ix = index;
                break;
            }
        }

        const city_ix = maybe_ix orelse unreachable;
        const row = self.connections[city_ix];

        var connections = std.ArrayList(City).init(allocator);

        for (row) |col, col_ix| {
            if (col != 0) {
                try connections.append(self.cities[col_ix]);
            }
        }

        return connections.items;
    }
};

fn loadTestGrid(allocator: *Allocator) !Grid {
    // This should only be called by tests.
    if (!std.builtin.is_test) {
        unreachable;
    }

    // Return a grid with this topology:
    // A -5- B -3- E
    // |     |
    // 5     3
    // |     |
    // C -4- D

    const cities = &[_]City{
        City.init("A", 0, 0),
        City.init("B", 1, 0),
        City.init("C", 0, 1),
        City.init("D", 1, 1),
        City.init("E", 2, 0),
    };

    var city_list = std.ArrayList(City).init(allocator);
    for (cities) |city| {
        try city_list.append(city);
    }
    const adjacency = [5][5]u8{
        //     A  B  C  D  E
        [5]u8{ 0, 5, 5, 0, 0 }, // A
        [5]u8{ 5, 0, 0, 3, 3 }, // B
        [5]u8{ 5, 0, 0, 4, 0 }, // C
        [5]u8{ 0, 3, 4, 0, 0 }, // D
        [5]u8{ 0, 3, 0, 0, 0 }, // E
    };

    var grid = std.ArrayList([]u8).init(allocator);

    for (adjacency) |row| {
        var rowList = std.ArrayList(u8).init(allocator);

        for (row) |col| {
            try rowList.append(col);
        }
        try grid.append(rowList.items);
    }

    return Grid{
        .cities = city_list.items,
        .connections = grid.items,
    };
}

test "finding cities at coordinates" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const grid = try loadTestGrid(&arena.allocator);

    const city1 = grid.cityAtCoords(0, 1).?;
    const city2 = grid.cityAtCoords(2, 0).?;
    const nothing = grid.cityAtCoords(2, 2);

    testing.expect(city1.eq(City.init("C", 0, 1)));
    testing.expect(city2.eq(City.init("E", 2, 0)));

    if (nothing) |_| {
        testing.expect(false);
    }
}

test "calculating connections between cities" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const grid = try loadTestGrid(&arena.allocator);

    const two_connections = try grid.getConnections(&arena.allocator, grid.cities[0]);
    const three_connections = try grid.getConnections(&arena.allocator, grid.cities[1]);
    const one_connection = try grid.getConnections(&arena.allocator, grid.cities[4]);

    const a_connections = &[_]City{ City.init("B", 1, 0), City.init("C", 0, 1) };
    const b_connections = &[_]City{ City.init("A", 0, 0), City.init("D", 1, 1), City.init("E", 2, 0) };
    const e_connections = &[_]City{City.init("B", 1, 0)};

    testing.expectEqualSlices(City, e_connections, one_connection);
    testing.expectEqualSlices(City, a_connections, two_connections);
    testing.expectEqualSlices(City, b_connections, three_connections);
}
