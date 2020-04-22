const std = @import("std");
const Allocator = std.mem.Allocator;

const Block = @import("resource_market.zig").Block;
const Generator = @import("generator.zig").Generator;
const Grid = @import("grid.zig").Grid;
const Loader = @import("loader.zig").Loader;
const Market = @import("resource_market.zig").Market;
const Player = @import("player.zig").Player;

const GameStage = enum {
    Stage1,
    Stage2,
    Stage3,
};

/// Split the initial list of generators into three lists:
///     1. the current generator market
///     2. the future generator market
///     3. the generators remaining in the stack, not yet revealed
/// The initial list gens MUST be sorted by generator index.
fn splitGenerators(allocator: *Allocator, gens: []Generator) ![3][]Generator {
    const seed = std.time.milliTimestamp();
    var r = std.rand.DefaultPrng.init(seed);

    var eco = gens[10];

    var hidden_a = gens[8..10];
    var hidden_b = gens[11..];
    var hidden = try std.mem.concat(allocator, Generator, &[_][]Generator{ hidden_a, hidden_b });
    r.random.shuffle(Generator, hidden);

    var gen_stack = try std.mem.concat(allocator, Generator, &[_][]Generator{ &[_]Generator{eco}, hidden });

    return [3][]Generator{
        gens[0..4],
        gens[4..8],
        gen_stack,
    };
}

/// A Game is the main object for the game and its state.
/// It holds the board, the players, the generator markets, etc.
pub const Game = struct {
    /// The grid layout used to play.
    grid: Grid,
    /// The players (in turn order) playing the game.
    players: []Player, // in turn order
    /// Generators that are available for purchase.
    gen_market: []Generator,
    /// Generators that will soon be available.
    future_gens: []Generator,
    /// Remaining generators that have not yet been revealed.
    hidden_generators: []Generator,
    /// Resources that can be bought by Players.
    resource_market: Market,
    /// The current stage of the game.
    stage: GameStage,

    pub fn init(allocator: *Allocator) !Game {
        const loader = Loader.init(allocator);

        const generators = try loader.loadGenerators();
        const split = try splitGenerators(allocator, generators);

        return Game{
            .grid = loader.loadGrid(),
            .players = loader.loadPlayers(),
            .gen_market = split[0],
            .future_gens = split[1],
            .hidden_generators = split[2],
            .resource_market = try loader.loadResourceMarket(),
            .stage = GameStage.Stage1,
        };
    }
};
