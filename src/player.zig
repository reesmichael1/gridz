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
    /// The name this player is playing under
    name: []const u8,
    /// The amount of money the player has on hand
    money: u64 = 50, // Use a u64 because you never know!
    /// The generators purchased by this player.
    /// They should always be sorted by generator index.
    generators: []Generator,
    /// Cities that this player has constructed so far.
    cities: []City,

    pub fn init(name: []const u8) Player {
        return Player{
            .name = name,
            .generators = &[_]Generator{},
            .cities = &[_]City{},
        };
    }

    /// Actually perform the mechanics of buying a generator (i.e., deduct the cost
    /// from the player's cash reserves and add the generator to the player's inventory.)
    pub fn buyGenerator(self: *Player, allocator: *Allocator, gen: Generator, cost: u64) !void {
        self.money -= cost;

        var gens = std.ArrayList(Generator).init(allocator);

        if (self.generators.len == constants.max_gens) {
            unreachable; // TODO: ask the player to remove a generator
        }

        for (self.generators) |generator| {
            try gens.append(generator);
        }

        try gens.append(gen);
        self.generators = gens.items;

        std.sort.sort(Generator, self.generators, gen_mod.genComp);
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
        .name = "first on cities",
        .generators = &[_]Generator{Generator.init(3, 1, 1, Resource.Oil)},
        .cities = &[_]City{ City.init("ABC"), City.init("DEF") },
    };

    const playerSecond = Player{
        .name = "second on generators",
        .generators = &[_]Generator{Generator.init(8, 1, 1, Resource.Oil)},
        .cities = &[_]City{City.init("ABC")},
    };

    const playerThird = Player{
        .name = "third on generators",
        .generators = &[_]Generator{Generator.init(5, 1, 1, Resource.Oil)},
        .cities = &[_]City{City.init("DEF")},
    };

    var players = &[_]Player{ playerSecond, playerThird, playerFirst };
    std.sort.sort(Player, players, playerComp);

    testing.expectEqualSlices(Player, players, &[_]Player{ playerFirst, playerSecond, playerThird });
}

test "turn order entirely on cities" {
    const playerFirst = Player{
        .name = "first",
        .generators = &[_]Generator{Generator.init(3, 1, 1, Resource.Oil)},
        .cities = &[_]City{ City.init("ABC"), City.init("DEF"), City.init("GHI") },
    };

    const playerSecond = Player{
        .name = "second",
        .generators = &[_]Generator{Generator.init(8, 1, 1, Resource.Oil)},
        .cities = &[_]City{ City.init("ABC"), City.init("DEF") },
    };

    const playerThird = Player{
        .name = "third",
        .generators = &[_]Generator{Generator.init(5, 1, 1, Resource.Oil)},
        .cities = &[_]City{City.init("GHI")},
    };

    var players = &[_]Player{ playerThird, playerSecond, playerFirst };
    std.sort.sort(Player, players, playerComp);

    testing.expectEqualSlices(Player, players, &[_]Player{ playerFirst, playerSecond, playerThird });
}

test "turn order entirely on generators" {
    const playerFirst = Player{
        .name = "first",
        .generators = &[_]Generator{Generator.init(30, 1, 1, Resource.Oil)},
        .cities = &[_]City{City.init("ABC")},
    };

    const playerSecond = Player{
        .name = "second",
        .generators = &[_]Generator{Generator.init(20, 1, 1, Resource.Oil)},
        .cities = &[_]City{City.init("DEF")},
    };

    const playerThird = Player{
        .name = "third",
        .generators = &[_]Generator{Generator.init(10, 1, 1, Resource.Oil)},
        .cities = &[_]City{City.init("GHI")},
    };

    var players = &[_]Player{ playerThird, playerSecond, playerFirst };
    std.sort.sort(Player, players, playerComp);

    testing.expectEqualSlices(Player, players, &[_]Player{ playerFirst, playerSecond, playerThird });
}
