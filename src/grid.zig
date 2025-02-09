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
    /// The allocator used for all necessary allocations
    allocator: *Allocator,

    pub fn init(allocator: *Allocator, loader: Loader) !Grid {
        const cities = try loader.loadCities();
        const connections = try loader.loadConnections(cities);

        return Grid{
            .allocator = allocator,
            .cities = cities,
            .connections = connections,
        };
    }

    /// Release any allocated memory.
    pub fn deinit(self: Grid) void {
        self.allocator.free(self.cities);
        for (self.connections) |row| {
            self.allocator.free(row);
        }
        self.allocator.free(self.connections);
    }

    /// If a City exists at the given coordinates, return it.
    /// Otherwise, return null;
    pub fn cityAtCoords(self: Grid, x: u8, y: u8) ?City {
        for (self.cities) |city| {
            if (city.x == x and city.y == y) {
                return city;
            }
        }

        return null;
    }

    /// Return a slice of all of the Cities that are connected to the given city.
    /// Caller owns the returned slice.
    pub fn getConnections(self: Grid, city: City) ![]City {
        var maybe_ix: ?usize = null;
        for (self.cities) |c, index| {
            if (c.eq(city)) {
                maybe_ix = index;
                break;
            }
        }

        const city_ix = maybe_ix orelse unreachable;
        const row = self.connections[city_ix];

        var connections = std.ArrayList(City).init(self.allocator);

        for (row) |col, col_ix| {
            if (col != 0) {
                try connections.append(self.cities[col_ix]);
            }
        }

        return connections.toOwnedSlice();
    }

    // TODO: change getConnections to return a slice of tuples of weights/cities.
    /// If two Cities are connected, then return the weight of the connection.
    /// Otherwise, return null.
    pub fn getWeight(self: Grid, city1: City, city2: City) ?u8 {
        var ix1: usize = undefined;
        var ix2: usize = undefined;
        for (self.cities) |city, index| {
            if (city.eq(city1)) {
                ix1 = index;
            } else if (city.eq(city2)) {
                ix2 = index;
            }
        }

        const weight = self.connections[ix1][ix2];

        if (weight == 0) {
            return null;
        }

        return weight;
    }

    /// Find a city whose name matches the given string.
    /// If none match, then null is returned.
    pub fn findCityByName(self: Grid, name: []const u8) ?*City {
        for (self.cities) |*city| {
            if (std.mem.eql(u8, name, city.name)) {
                return city;
            }
        }

        return null;
    }

    /// Find the cheapest cost of adding a city to a Player's network.
    /// If there are no cities in the Player's network,
    /// then the connection cost is 0. Otherwise, it is the cheapest
    /// path from one of the Player's cities to the target city.
    pub fn getMinConnectionCost(self: Grid, city: City, network: []City) !u64 {
        if (network.len == 0) {
            return 0;
        }

        // Use Dijkstra's algorithm to calculate the cost from the target city
        // to every other city in the grid.
        // Then, compare the cost of going to each city in the network
        // to find the cheapest one.
        var visited = std.BufSet.init(self.allocator);
        defer visited.deinit();

        var unvisited = std.BufSet.init(self.allocator);
        defer unvisited.deinit();

        var cities_by_name = std.StringHashMap(City).init(self.allocator);
        defer cities_by_name.deinit();

        var distances = std.StringHashMap(u64).init(self.allocator);
        defer distances.deinit();

        for (self.cities) |node| {
            try unvisited.insert(node.name);
            _ = try distances.put(node.name, std.math.maxInt(u64));
            _ = try cities_by_name.put(node.name, node);
        }

        _ = try distances.put(city.name, 0);

        var current_node = city;

        while (unvisited.count() > 0) {
            const current_distance = distances.get(current_node.name).?;
            const connections = try self.getConnections(current_node);
            defer self.allocator.free(connections);

            for (connections) |connection| {
                if (!unvisited.contains(connection.name)) {
                    continue;
                }

                const connection_value = distances.get(connection.name).?;
                const connection_weight = self.getWeight(current_node, connection).?;
                const new_weight = current_distance + connection_weight;
                if (connection_value > new_weight) {
                    _ = try distances.put(connection.name, new_weight);
                }
            }

            unvisited.remove(current_node.name);

            var next: ?City = null;
            var it = unvisited.iterator();
            while (true) {
                const entry = it.next() orelse break;
                const next_unvisited = cities_by_name.get(entry.*).?;
                if (next == null) {
                    next = next_unvisited;
                    continue;
                }
                if (distances.get(next_unvisited.name).? < distances.get(next.?.name).?) {
                    next = next_unvisited;
                }
            }

            if (next) |unwrapped| {
                current_node = unwrapped;
            } else {
                // If we couldn't find a new city to start the algorithm on, then we're done.
                break;
            }
        }

        var min = distances.get(network[0].name).?;
        for (network[1..]) |network_city| {
            const distance = distances.get(network_city.name).?;
            if (distance < min) {
                min = distance;
            }
        }

        return min;
    }
};

fn loadTestGrid(allocator: *Allocator) !Grid {
    // This should only be called by tests.
    if (!@import("builtin").is_test) {
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
        defer rowList.deinit();

        for (row) |col| {
            try rowList.append(col);
        }
        try grid.append(try std.mem.dupe(allocator, u8, rowList.items));
    }

    return Grid{
        .allocator = allocator,
        .cities = try std.mem.dupe(allocator, City, cities),
        .connections = grid.toOwnedSlice(),
    };
}

test "finding cities at coordinates" {
    const grid = try loadTestGrid(testing.allocator);
    defer grid.deinit();

    const city1 = grid.cityAtCoords(0, 1).?;
    const city2 = grid.cityAtCoords(2, 0).?;
    const nothing = grid.cityAtCoords(2, 2);

    try testing.expect(city1.eq(City.init("C", 0, 1)));
    try testing.expect(city2.eq(City.init("E", 2, 0)));

    if (nothing) |_| {
        try testing.expect(false);
    }
}

test "calculating connections between cities" {
    const grid = try loadTestGrid(testing.allocator);
    defer grid.deinit();

    const two_connections = try grid.getConnections(grid.cities[0]);
    defer testing.allocator.free(two_connections);

    const three_connections = try grid.getConnections(grid.cities[1]);
    defer testing.allocator.free(three_connections);

    const one_connection = try grid.getConnections(grid.cities[4]);
    defer testing.allocator.free(one_connection);

    const a_connections = &[_]City{ City.init("B", 1, 0), City.init("C", 0, 1) };
    const b_connections = &[_]City{ City.init("A", 0, 0), City.init("D", 1, 1), City.init("E", 2, 0) };
    const e_connections = &[_]City{City.init("B", 1, 0)};

    try testing.expectEqualSlices(City, e_connections, one_connection);
    try testing.expectEqualSlices(City, a_connections, two_connections);
    try testing.expectEqualSlices(City, b_connections, three_connections);
}

test "calculating connection weight" {
    const grid = try loadTestGrid(testing.allocator);
    defer grid.deinit();

    try testing.expectEqual(@as(u8, 5), grid.getWeight(grid.cities[0], grid.cities[1]).?);
    try testing.expectEqual(@as(u8, 3), grid.getWeight(grid.cities[1], grid.cities[3]).?);
}

test "calculating connection costs" {
    const grid = try loadTestGrid(testing.allocator);
    defer grid.deinit();

    // Want to start with A
    try testing.expectEqual(@as(u64, 0), try grid.getMinConnectionCost(grid.cities[0], &[_]City{}));
    // Have A, want to connect to B
    try testing.expectEqual(@as(u64, 5), try grid.getMinConnectionCost(grid.cities[1], &[_]City{
        grid.cities[0],
    }));

    // Have A and B, want to connect to C
    try testing.expectEqual(@as(u64, 5), try grid.getMinConnectionCost(grid.cities[2], &[_]City{
        grid.cities[0],
        grid.cities[1],
    }));

    // Have B and E, want to connect to C
    try testing.expectEqual(@as(u64, 7), try grid.getMinConnectionCost(grid.cities[2], &[_]City{
        grid.cities[1],
        grid.cities[4],
    }));
}
