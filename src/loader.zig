const std = @import("std");
const Allocator = std.mem.Allocator;

const City = @import("city.zig").City;
const Generator = @import("generator.zig").Generator;
const Grid = @import("grid.zig").Grid;
const Market = @import("resource_market.zig").Market;
const Player = @import("player.zig").Player;
const Resource = @import("resource.zig").Resource;

fn buildAdjacencyMatrix(allocator: *Allocator, cities: []City) ![][]u8 {
    // Eventually, this will be generated from the list of cities,
    // but for now, let's hardcode it.
    // This matrix corresponds to the layout in maps/default.graphml.
    const arrays = [20][20]u8{
        .{ 0, 7, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        .{ 7, 0, 4, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        .{ 0, 4, 0, 5, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        .{ 0, 0, 5, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        .{ 5, 7, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        .{ 0, 0, 0, 0, 5, 0, 8, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        .{ 0, 0, 3, 0, 0, 8, 0, 2, 0, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 0 },
        .{ 0, 0, 0, 0, 0, 0, 2, 0, 9, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0 },
        .{ 0, 0, 0, 6, 0, 0, 0, 9, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0 },
        .{ 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 3, 0, 0, 4, 11, 0, 0, 0, 0, 0 },
        .{ 0, 0, 0, 0, 0, 3, 0, 0, 0, 3, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0 },
        .{ 0, 0, 0, 0, 0, 0, 9, 0, 0, 0, 6, 0, 10, 0, 8, 2, 0, 0, 0, 0 },
        .{ 0, 0, 0, 0, 0, 0, 0, 3, 7, 0, 0, 10, 0, 0, 0, 9, 5, 0, 0, 0 },
        .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 6, 0, 0, 8, 0, 0 },
        .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 11, 0, 8, 0, 0, 0, 0, 0, 7, 7, 0 },
        .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 9, 0, 0, 0, 8, 0, 5, 11 },
        .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 8, 0, 0, 0, 6 },
        .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 7, 0, 0, 0, 0, 0 },
        .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 5, 0, 0, 0, 8 },
        .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 11, 6, 0, 8, 0 },
    };

    var grid = std.ArrayList([]u8).init(allocator);

    for (arrays) |row| {
        var rowList = std.ArrayList(u8).init(allocator);

        for (row) |col| {
            try rowList.append(col);
        }
        try grid.append(rowList.items);
    }

    return grid.items;
}

/// The Loader handles loading the initial game state.
/// Eventually, we want users to be able to load
/// custom games from config files, but for now,
/// we'll just build a temporary structure.
pub const Loader = struct {
    allocator: *Allocator,

    pub fn init(allocator: *Allocator) Loader {
        return Loader{ .allocator = allocator };
    }

    pub fn loadGenerators(self: Loader) ![]Generator {
        const resources = &[_]Resource{ Resource.Coal, Resource.Oil, Resource.Garbage, Resource.Uranium };
        const renewables = &[_]Resource{ Resource.Hydro, Resource.Wind };

        // Rather than hard-coding a huge list of generators,
        // we randomly generate one for now.
        const seed = std.time.milliTimestamp();
        var r = std.rand.DefaultPrng.init(seed);

        var generators = std.ArrayList(Generator).init(self.allocator);

        var gen_ix: u8 = 3;
        while (gen_ix <= 50) : (gen_ix += 1) {
            var resource_low: u8 = 1;
            var resource_high: u8 = 3;

            // Make sure that powerful generators require *some* resources
            // to be purchased each time.
            if (gen_ix > 30) {
                resource_low = 2;
            }

            var resource_count = r.random.intRangeAtMost(u8, resource_low, resource_high);
            const power_cap = @divFloor(gen_ix, 10) + 1;
            var can_power = r.random.intRangeAtMost(u8, power_cap, 2 * power_cap);

            // Roughly 20% of generators can use renewable resources.
            // The rest will use a randomly selected non-renewable resource.
            // No renewables should appear in the first 12 generators,
            // and uranium should not appear in the first 10 generators.
            // Generator 13 should use a renewable resource.
            const use_renewable = r.random.uintLessThan(u8, 10);
            var assign_resource: ?Resource = null;
            if (use_renewable >= 8 and gen_ix > 13 or gen_ix == 13) {
                assign_resource = renewables[r.random.uintLessThan(u8, renewables.len)];
                resource_count = 1;
            } else {
                if (gen_ix <= 10) {
                    std.debug.assert(resources[resources.len - 1] == Resource.Uranium);
                    assign_resource = resources[r.random.uintLessThan(u8, resources.len - 1)];
                } else {
                    assign_resource = resources[r.random.uintLessThan(u8, resources.len)];
                }
            }

            const resource = assign_resource orelse unreachable;

            // Since the supply of uranium is so scarce,
            // only require one to power any generator.
            if (resource == Resource.Uranium) {
                resource_count = 1;
            }

            const new_gen = Generator.init(gen_ix, can_power, resource_count, resource);
            try generators.append(new_gen);

            // We want our last generators to be indexed 40, 42, 44, 46, 50
            if (gen_ix == 40 or gen_ix == 42 or gen_ix == 44) {
                gen_ix += 1;
            } else if (gen_ix == 46) {
                gen_ix = 49;
            }
        }

        return generators.items;
    }

    pub fn loadGrid(self: Loader) !Grid {
        return try Grid.init(self.allocator, self);
    }

    pub fn loadCities(self: Loader) ![]City {
        const cities = [_]City{
            City.init("Ashworth", 0, 0),
            City.init("Transton", 1, 0),
            City.init("Greenwich", 2, 0),
            City.init("Winford", 3, 0),
            City.init("Morneault", 0, 1),
            City.init("Waterdale", 1, 1),
            City.init("Appleville", 2, 1),
            City.init("Foxworth", 2, 2),
            City.init("Winterside", 3, 1),
            City.init("Wheelmouth", 0, 2),
            City.init("Mannorham", 1, 2),
            City.init("Pinebury", 1, 3),
            City.init("Ashby", 3, 2),
            City.init("Halltown", 0, 3),
            City.init("Fairtown", 1, 4),
            City.init("Mayville", 2, 3),
            City.init("Rosebury", 3, 3),
            City.init("Norside", 0, 4),
            City.init("Waterfield", 2, 4),
            City.init("Starfolk", 3, 4),
        };

        var cities_list = std.ArrayList(City).init(self.allocator);
        for (cities) |city| {
            try cities_list.append(city);
        }

        return cities_list.items;
    }

    pub fn loadConnections(self: Loader, cities: []City) ![][]u8 {
        return try buildAdjacencyMatrix(self.allocator, cities);
    }

    pub fn loadPlayers(self: Loader) ![]Player {
        // TODO: assert that each player has a unique name.
        var players = [_]Player{
            Player.init(self.allocator, "Alice"),
            Player.init(self.allocator, "Bob"),
            Player.init(self.allocator, "Charlie"),
        };

        var players_list = std.ArrayList(Player).init(self.allocator);

        for (players) |player| {
            try players_list.append(player);
        }

        return players_list.items;
    }

    pub fn loadResourceMarket(self: Loader) !Market {
        return Market.init(self.allocator);
    }
};
