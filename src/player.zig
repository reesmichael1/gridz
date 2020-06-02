const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const constants = @import("constants.zig");
const gen_mod = @import("generator.zig");
const input = @import("input.zig");
const getCitiesToShow = @import("game.zig").getCitiesToShow;

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
    /// Resources that the player has purchased and has in reserve.
    resources: []Resource,

    pub fn init(allocator: *Allocator, name: []const u8) Player {
        return Player{
            .allocator = allocator,
            .name = name,
            .generators = &[_]Generator{},
            .cities = &[_]City{},
            .resources = &[_]Resource{},
        };
    }

    pub fn deinit(self: Player) void {
        self.allocator.free(self.generators);
        self.allocator.free(self.cities);
        self.allocator.free(self.resources);
    }

    /// Add a new resource to the player's stored resources.
    pub fn buyResource(self: *Player, resource: Resource, count: u64) !void {
        var added: u64 = 0;
        var resources = std.ArrayList(Resource).init(self.allocator);
        defer resources.deinit();
        try resources.appendSlice(self.resources);

        while (added < count) : (added += 1) {
            try resources.append(resource);
        }

        self.resources = try std.mem.dupe(self.allocator, Resource, resources.items);
    }

    /// Actually perform the mechanics of buying a generator (i.e., deduct the cost
    /// from the player's cash reserves and add the generator to the player's inventory.)
    pub fn buyGenerator(self: *Player, gen: Generator, cost: u64) !void {
        self.money -= cost;

        var gens = std.ArrayList(Generator).init(self.allocator);
        defer gens.deinit();

        if (self.generators.len == constants.max_gens) {
            const stdout = std.io.getStdOut().outStream();
            try stdout.print("You have reached the maximum number of generators.\n", .{});
            try stdout.print("You currently own these generators:\n\n", .{});
            for (self.generators) |generator| {
                try stdout.print("Generator {}: uses {} {} to power {} {}\n", .{
                    generator.index,
                    generator.resource_count,
                    generator.resource,
                    generator.can_power,
                    getCitiesToShow(usize, generator.can_power),
                });
            }

            try stdout.print("\n", .{});

            while (true) {
                const remove_ix = try input.getNumberFromUser(u8, "Please enter the index of the generator you will discard: ", .{});

                for (self.generators) |generator| {
                    if (generator.index != remove_ix) {
                        try gens.append(generator);
                    }
                }

                if (gens.items.len == constants.max_gens) {
                    try stdout.print("You do not own generator {}.\n", .{remove_ix});
                    gens.deinit();
                    gens = std.ArrayList(Generator).init(self.allocator);
                } else {
                    break;
                }
            }
        } else {
            for (self.generators) |generator| {
                try gens.append(generator);
            }
        }

        try gens.append(gen);
        self.generators = gens.toOwnedSlice();
        std.sort.sort(Generator, self.generators, gen_mod.genComp);
    }

    /// Return a hash map of each resource the player can store -> how many can be stored.
    /// Caller owns returned memory.
    pub fn getStoreableResources(self: *const Player) !std.AutoHashMap(Resource, u8) {
        var map = std.AutoHashMap(Resource, u8).init(self.allocator);

        for (self.generators) |generator| {
            if (generator.isEco()) {
                continue;
            }

            const current = try map.getOrPutValue(generator.resource, 0);
            _ = try map.put(generator.resource, current.value + 2 * generator.resource_count);
        }

        for (self.resources) |resource| {
            const current = try map.getOrPutValue(resource, 0);
            _ = try map.put(resource, current.value - 1);
        }

        return map;
    }

    /// Return true if the player has enough resources to power this generator,
    /// and false otherwise.
    pub fn canPowerGenerator(self: Player, generator: Generator) bool {
        var available: u64 = 0;

        for (self.resources) |resource| {
            if (resource == generator.resource) {
                available += 1;
                if (available >= generator.resource_count) {
                    return true;
                }
            }
        }

        return false;
    }

    /// Deduct the resources needed to power a generator from the player's resources.
    /// Will panic if called with a generator the player cannot power.
    pub fn powerGenerator(self: *Player, generator: Generator) !void {
        var resources = std.ArrayList(Resource).init(self.allocator);
        defer resources.deinit();

        var consumed: u64 = 0;
        for (self.resources) |resource| {
            if (resource != generator.resource or consumed >= generator.resource_count) {
                try resources.append(resource);
            } else {
                consumed += 1;
            }
        }

        if (consumed < generator.resource_count) {
            unreachable;
        }

        self.allocator.free(self.resources);
        self.resources = try std.mem.dupe(self.allocator, Resource, resources.items);
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
        .resources = &[_]Resource{},
    };

    const playerSecond = Player{
        .allocator = testing.allocator,
        .name = "second on generators",
        .generators = &[_]Generator{Generator.init(8, 1, 1, Resource.Oil)},
        .cities = &[_]City{City.init("ABC", 0, 1)},
        .resources = &[_]Resource{},
    };

    const playerThird = Player{
        .allocator = testing.allocator,
        .name = "third on generators",
        .generators = &[_]Generator{Generator.init(5, 1, 1, Resource.Oil)},
        .cities = &[_]City{City.init("DEF", 0, 2)},
        .resources = &[_]Resource{},
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
        .resources = &[_]Resource{},
    };

    const playerSecond = Player{
        .allocator = testing.allocator,
        .name = "second",
        .generators = &[_]Generator{Generator.init(8, 1, 1, Resource.Oil)},
        .cities = &[_]City{ City.init("ABC", 0, 0), City.init("DEF", 0, 1) },
        .resources = &[_]Resource{},
    };

    const playerThird = Player{
        .allocator = testing.allocator,
        .name = "third",
        .generators = &[_]Generator{Generator.init(5, 1, 1, Resource.Oil)},
        .cities = &[_]City{City.init("GHI", 0, 2)},
        .resources = &[_]Resource{},
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
        .resources = &[_]Resource{},
    };

    const playerSecond = Player{
        .allocator = testing.allocator,
        .name = "second",
        .generators = &[_]Generator{Generator.init(20, 1, 1, Resource.Oil)},
        .cities = &[_]City{City.init("DEF", 0, 1)},
        .resources = &[_]Resource{},
    };

    const playerThird = Player{
        .allocator = testing.allocator,
        .name = "third",
        .generators = &[_]Generator{Generator.init(10, 1, 1, Resource.Oil)},
        .cities = &[_]City{City.init("GHI", 0, 2)},
        .resources = &[_]Resource{},
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
        .resources = &[_]Resource{},
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
        .resources = &[_]Resource{},
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
        .resources = &[_]Resource{},
    };

    const can_store = try playerWithTwoCoal.getStoreableResources();
    defer can_store.deinit();

    testing.expect(can_store.getValue(Resource.Coal).? == 10);
}

test "player with existing resources can buy fewer resources" {
    var resources = [_]Resource{ Resource.Coal, Resource.Coal };
    var playerWithTwoCoal = Player{
        .allocator = testing.allocator,
        .name = "two coal generators",
        .generators = &[_]Generator{
            Generator.init(10, 1, 2, Resource.Coal),
            Generator.init(20, 1, 3, Resource.Coal),
        },
        .cities = &[_]City{},
        .resources = &resources,
    };

    const can_store = try playerWithTwoCoal.getStoreableResources();
    defer can_store.deinit();

    testing.expect(can_store.getValue(Resource.Coal).? == 8);
}

test "player can determine if can power generators" {
    var player = Player{
        .allocator = testing.allocator,
        .name = "Player",
        .resources = try std.mem.dupe(testing.allocator, Resource, &[_]Resource{
            Resource.Coal,
            Resource.Coal,
            Resource.Uranium,
        }),
        .generators = &[_]Generator{},
        .cities = &[_]City{},
    };

    defer player.deinit();

    testing.expect(player.canPowerGenerator(Generator.init(1, 1, 1, Resource.Coal)));
    testing.expect(player.canPowerGenerator(Generator.init(2, 2, 2, Resource.Coal)));
    testing.expect(!player.canPowerGenerator(Generator.init(3, 3, 3, Resource.Coal)));

    try player.powerGenerator(Generator.init(2, 2, 2, Resource.Coal));
    std.testing.expectEqualSlices(Resource, &[_]Resource{Resource.Uranium}, player.resources);

    testing.expect(player.canPowerGenerator(Generator.init(4, 4, 1, Resource.Uranium)));
    testing.expect(!player.canPowerGenerator(Generator.init(5, 5, 5, Resource.Oil)));
}

test "player cannot store ecological resources" {
    const player = Player{
        .allocator = testing.allocator,
        .name = "Player",
        .resources = try std.mem.dupe(testing.allocator, Resource, &[_]Resource{}),
        .generators = &[_]Generator{Generator.init(13, 1, 1, Resource.Wind)},
        .cities = &[_]City{},
    };

    const can_store = try player.getStoreableResources();
    defer can_store.deinit();

    testing.expect(can_store.getValue(Resource.Wind) == null);
}
