const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const constants = @import("constants.zig");
const gen_mod = @import("generator.zig");

const City = @import("city.zig").City;
const Generator = gen_mod.Generator;
const Resource = @import("resource.zig").Resource;

/// A Player is a competitor in the game.
pub const Player = struct {
    /// The allocator used for all necessary allocations
    allocator: *Allocator,
    /// The name this player is playing under
    name: []const u8,
    /// The amount of money the player has on hand
    money: u64 = 50, // Use a u64 because you never know!
    /// The generators purchased by this player.
    /// They should always be sorted by generator index.
    generators: []Generator,
    /// Cities that this player has constructed so far.
    cities: []City,

    pub fn init(allocator: *Allocator, name: []const u8) Player {
        return Player{
            .allocator = allocator,
            .name = name,
            .generators = &[_]Generator{},
            .cities = &[_]City{},
        };
    }

    pub fn deinit(self: Player) void {
        self.allocator.free(self.generators);
        self.allocator.free(self.cities);
    }

    /// Actually perform the mechanics of buying a generator (i.e., deduct the cost
    /// from the player's cash reserves and add the generator to the player's inventory.)
    pub fn buyGenerator(self: *Player, gen: Generator, cost: u64) !void {
        self.money -= cost;

        var gens = std.ArrayList(Generator).init(self.allocator);
        defer gens.deinit();

        if (self.generators.len == constants.max_gens) {
            unreachable; // TODO: ask the player to remove a generator
        }

        for (self.generators) |generator| {
            try gens.append(generator);
        }

        try gens.append(gen);
        self.generators = try std.mem.dupe(self.allocator, Generator, gens.items);
        std.sort.sort(Generator, self.generators, gen_mod.genComp);
    }

    /// Return a hash map of each resource the player can store -> how many can be stored.
    /// Caller owns returned memory.
    pub fn getStoreableResources(self: *const Player) !std.AutoHashMap(Resource, u8) {
        var map = std.AutoHashMap(Resource, u8).init(self.allocator);

        for (self.generators) |generator| {
            const current = try map.getOrPutValue(generator.resource, 0);
            _ = try map.put(generator.resource, current.value + 2 * generator.resource_count);
        }

        return map;
    }
};

/// Compare players to determine turn order.
/// If one player has more cities than another,
/// then they should go first. Otherwise, the player
/// with the higher numbered generator goes first.
pub fn playerComp(player1: Player, player2: Player) bool {
    if (player1.cities.len != player2.cities.len) {
        return player1.cities.len > player2.cities.len;
    }

    const lastIx1 = player1.generators.len - 1;
    const lastIx2 = player2.generators.len - 1;

    return player1.generators[lastIx1].index > player2.generators[lastIx2].index;
}

test "determine turn order" {
    const playerFirst = Player{
        .allocator = testing.allocator,
        .name = "first on cities",
        .generators = &[_]Generator{Generator.init(3, 1, 1, Resource.Oil)},
        .cities = &[_]City{ City.init("ABC", 0, 1), City.init("DEF", 0, 2) },
    };

    const playerSecond = Player{
        .allocator = testing.allocator,
        .name = "second on generators",
        .generators = &[_]Generator{Generator.init(8, 1, 1, Resource.Oil)},
        .cities = &[_]City{City.init("ABC", 0, 1)},
    };

    const playerThird = Player{
        .allocator = testing.allocator,
        .name = "third on generators",
        .generators = &[_]Generator{Generator.init(5, 1, 1, Resource.Oil)},
        .cities = &[_]City{City.init("DEF", 0, 2)},
    };

    var players = &[_]Player{ playerSecond, playerThird, playerFirst };
    std.sort.sort(Player, players, playerComp);

    testing.expectEqualSlices(Player, players, &[_]Player{ playerFirst, playerSecond, playerThird });
}

test "turn order entirely on cities" {
    const playerFirst = Player{
        .allocator = testing.allocator,
        .name = "first",
        .generators = &[_]Generator{Generator.init(3, 1, 1, Resource.Oil)},
        .cities = &[_]City{ City.init("ABC", 0, 0), City.init("DEF", 0, 1), City.init("GHI", 0, 2) },
    };

    const playerSecond = Player{
        .allocator = testing.allocator,
        .name = "second",
        .generators = &[_]Generator{Generator.init(8, 1, 1, Resource.Oil)},
        .cities = &[_]City{ City.init("ABC", 0, 0), City.init("DEF", 0, 1) },
    };

    const playerThird = Player{
        .allocator = testing.allocator,
        .name = "third",
        .generators = &[_]Generator{Generator.init(5, 1, 1, Resource.Oil)},
        .cities = &[_]City{City.init("GHI", 0, 2)},
    };

    var players = &[_]Player{ playerThird, playerSecond, playerFirst };
    std.sort.sort(Player, players, playerComp);

    testing.expectEqualSlices(Player, players, &[_]Player{ playerFirst, playerSecond, playerThird });
}

test "turn order entirely on generators" {
    const playerFirst = Player{
        .allocator = testing.allocator,
        .name = "first",
        .generators = &[_]Generator{Generator.init(30, 1, 1, Resource.Oil)},
        .cities = &[_]City{City.init("ABC", 0, 0)},
    };

    const playerSecond = Player{
        .allocator = testing.allocator,
        .name = "second",
        .generators = &[_]Generator{Generator.init(20, 1, 1, Resource.Oil)},
        .cities = &[_]City{City.init("DEF", 0, 1)},
    };

    const playerThird = Player{
        .allocator = testing.allocator,
        .name = "third",
        .generators = &[_]Generator{Generator.init(10, 1, 1, Resource.Oil)},
        .cities = &[_]City{City.init("GHI", 0, 2)},
    };

    var players = &[_]Player{ playerThird, playerSecond, playerFirst };
    std.sort.sort(Player, players, playerComp);

    testing.expectEqualSlices(Player, players, &[_]Player{ playerFirst, playerSecond, playerThird });
}

test "player can store single resource" {
    const playerWithCoal = Player{
        .allocator = testing.allocator,
        .name = "coal",
        .generators = &[_]Generator{Generator.init(10, 1, 2, Resource.Coal)},
        .cities = &[_]City{},
    };

    const can_store = try playerWithCoal.getStoreableResources();
    defer can_store.deinit();

    testing.expect(can_store.getValue(Resource.Coal).? == 4);
}

test "player can store multiple resources" {
    const playerWithCoalAndOil = Player{
        .allocator = testing.allocator,
        .name = "coal and oil",
        .generators = &[_]Generator{
            Generator.init(10, 1, 2, Resource.Coal),
            Generator.init(20, 1, 3, Resource.Oil),
        },
        .cities = &[_]City{},
    };

    const can_store = try playerWithCoalAndOil.getStoreableResources();
    defer can_store.deinit();

    testing.expect(can_store.getValue(Resource.Coal).? == 4);
    testing.expect(can_store.getValue(Resource.Oil).? == 6);
}

test "player can store same resource across multiple generators" {
    const playerWithTwoCoal = Player{
        .allocator = testing.allocator,
        .name = "two coal generators",
        .generators = &[_]Generator{
            Generator.init(10, 1, 2, Resource.Coal),
            Generator.init(20, 1, 3, Resource.Coal),
        },
        .cities = &[_]City{},
    };

    const can_store = try playerWithTwoCoal.getStoreableResources();
    defer can_store.deinit();

    testing.expect(can_store.getValue(Resource.Coal).? == 10);
}
