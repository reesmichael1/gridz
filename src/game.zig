const std = @import("std");
const Allocator = std.mem.Allocator;

const Grid = @import("grid.zig").Grid;
const Player = @import("player.zig").Player;
const Generator = @import("generator.zig").Generator;
const Market = @import("resource_market.zig").Market;
const Block = @import("resource_market.zig").Block;

const GameStage = enum {
    Stage1,
    Stage2,
    Stage3,
};

/// A Game is the main object for the game and its state.
/// It holds the board, the players, the generator markets, etc.
pub const Game = struct {
    /// The grid layout used to play.
    board: Grid,
    /// The players (in turn order) playing the game.
    players: []Player, // in turn order
    /// Generators that are available for purchase.
    gen_market: []Generator,
    /// Generators that will soon be available.
    future_gens: []Generator,
    /// Resources that can be bought by Players.
    resource_market: Market,
    /// The current stage of the game.
    stage: GameStage,
    /// Remaining generators that have not yet been revealed.
    hidden_generators: []Generator,

    pub fn init(allocator: *Allocator) Game {
        return Game{
            .board = Grid.init(allocator),
            .players = &[_]Player{},
            .gen_market = &[_]Generator{},
            .future_gens = &[_]Generator{},
            .resource_market = Market.init(),
            .stage = GameStage.Stage1,
            .hidden_generators = &[_]Generator{},
        };
    }
};
