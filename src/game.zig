const std = @import("std");
const Allocator = std.mem.Allocator;

const auction = @import("auction.zig");
const gen_mod = @import("generator.zig");
const player_mod = @import("player.zig");
const input = @import("input.zig");

const Block = @import("resource_market.zig").Block;
const Generator = gen_mod.Generator;
const Grid = @import("grid.zig").Grid;
const Loader = @import("loader.zig").Loader;
const Market = @import("resource_market.zig").Market;
const Player = player_mod.Player;

const GameStage = enum {
    Stage1,
    Stage2,
    Stage3,
};

// Do this in a function to avoid a compiler error;
// about overwriting strings of different lengths.
fn getCitiesToShow(gen: Generator) []const u8 {
    if (gen.can_power == 1) {
        return "city";
    }

    return "cities";
}

/// Split the initial list of generators into three lists:
///     1. the current generator market
///     2. the future generator market
///     3. the generators remaining in the stack, not yet revealed
/// The initial list gens MUST be sorted by generator index.
fn splitGenerators(allocator: *Allocator, gens: []Generator, r: *std.rand.Xoroshiro128) ![3][]Generator {
    const seed = std.time.milliTimestamp();

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
    players: []Player,
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
    /// Whether or not the game is over.
    has_ended: bool = false,
    /// The current round of the game (starts at 1)
    round: u16,
    /// The RNG used for all game operations.
    rng: std.rand.Xoroshiro128,
    /// The Allocator used for all allocations
    allocator: *Allocator,

    /// Prepare the Game for the first turn.
    pub fn init(allocator: *Allocator) !Game {
        const loader = Loader.init(allocator);

        var rng = std.rand.DefaultPrng.init(std.time.milliTimestamp());
        const generators = try loader.loadGenerators();
        const split = try splitGenerators(allocator, generators, &rng);

        var players = try loader.loadPlayers();

        return Game{
            .grid = try loader.loadGrid(),
            .players = try loader.loadPlayers(),
            .gen_market = split[0],
            .future_gens = split[1],
            .hidden_generators = split[2],
            .resource_market = try loader.loadResourceMarket(),
            .stage = GameStage.Stage1,
            .rng = rng,
            .round = 1,
            .allocator = allocator,
        };
    }

    /// Run a turn of the game.
    pub fn nextTurn(self: *Game) !void {
        self.phase1(self.round == 1);
        try self.updateDisplay();
        try self.phase2();

        if (self.round == 1) {
            // In the first round, after choosing generators, set the turn order
            // based off of the new generators.
            self.phase1(false);
            try self.updateDisplay();
        }

        try self.phase3();

        self.has_ended = true;
    }

    /// Display the current game state for the players to see.
    fn updateDisplay(self: Game) !void {
        const stdout = std.io.getStdOut().outStream();

        try stdout.print("Player order for turn {}:\n", .{self.round});
        for (self.players) |player, ix| {
            try stdout.print("{}: {}\n", .{ ix + 1, player.name });
        }

        try self.displayGenerators();
    }

    /// Display the generators in the current and future markets.
    fn displayGenerators(self: Game) !void {
        const stdout = std.io.getStdOut().outStream();
        try stdout.print("\n\nGenerators available:\n", .{});

        for (self.gen_market) |generator| {
            try stdout.print("{}: uses {} {} to power {} {}\n", .{
                generator.index,
                generator.resource_count,
                generator.resource,
                generator.can_power,
                getCitiesToShow(generator),
            });
        }

        try stdout.print("\n\nGenerators in future market:\n", .{});
        for (self.future_gens) |generator| {
            try stdout.print("{}: uses {} {} to power {} {}\n", .{
                generator.index,
                generator.resource_count,
                generator.resource,
                generator.can_power,
                getCitiesToShow(generator),
            });
        }

        try stdout.print("\n\n", .{});
    }

    /// Display the resources available for the players to purchase.
    fn displayResourceMarket(self: Game) !void {
        const stdout = std.io.getStdOut().outStream();

        for (self.resource_market.blocks) |block| {
            try stdout.print("Resources available for {} GZD\n\n", .{block.cost});

            for (block.resources) |resource| {
                try stdout.print("{}: {}/{}\n", .{
                    resource.resource,
                    resource.count_filled,
                    resource.count_available,
                });
            }

            try stdout.print("\n", .{});
        }
    }

    /// Determine player order for this turn.
    fn phase1(self: *Game, random: bool) void {
        // For the first round, player order is randomly determined.
        // For the remaining turns, players are ordered by number of
        // cities selected, with ties broken by the highest numbered generator.
        if (random) {
            self.rng.random.shuffle(Player, self.players);
        } else {
            std.sort.sort(Player, self.players, player_mod.playerComp);
        }
    }

    /// Run a generator auction.
    fn phase2(self: *Game) !void {
        // Collect the players by reference so we can subtract money
        // from any players that do buy generators.
        var eligible_players = std.ArrayList(*Player).init(self.allocator);
        for (self.players) |*player| {
            try eligible_players.append(player);
        }

        var was_bought = false;
        while (eligible_players.items.len > 0) {
            const must_buy = self.round == 1;
            const result = try auction.auctionRound(self, eligible_players.items, self.gen_market, must_buy);
            var to_remove: ?*Player = null;
            switch (result) {
                auction.AuctionResultTag.Bought => |purchase| {
                    // Remove the player who bought a generator
                    // from the list of players eligible to buy a generator.
                    to_remove = purchase.buyer;

                    try purchase.buyer.buyGenerator(self.allocator, purchase.gen, purchase.cost);

                    // Update the generator markets by removing the purchased generator,
                    // replacing it with a generator from the stack,
                    // and then reorganizing the markets as necessary.
                    var new_market = std.ArrayList(Generator).init(self.allocator);

                    for (self.gen_market) |gen| {
                        if (gen.index != purchase.gen.index) {
                            try new_market.append(gen);
                        }
                    }

                    for (self.future_gens) |gen| {
                        try new_market.append(gen);
                    }

                    try new_market.append(self.hidden_generators[0]);
                    self.hidden_generators = self.hidden_generators[1..];

                    if (self.hidden_generators.len == 0) {
                        // TODO: send us into stage 3
                        unreachable;
                    }

                    try self.updateGenMarket(new_market.items);
                    try self.displayGenerators();

                    if (!was_bought) {
                        was_bought = true;
                    }
                },
                auction.AuctionResultTag.Passed => |passer| {
                    // If a player passed on buying a generator, they remove them
                    // from the list of players eligible to buy a generator.
                    to_remove = passer;
                },
            }

            // We should always be able to remove a player after each auction round.
            const remove = to_remove orelse unreachable;
            const old_players = eligible_players.items;
            eligible_players = std.ArrayList(*Player).init(self.allocator);
            for (old_players) |old_player| {
                if (!std.mem.eql(u8, old_player.name, remove.name)) {
                    try eligible_players.append(old_player);
                }
            }
        }

        // If no generator is sold, then remove the lowest numbered one from the market.
        // Replace it with the next one in the stack.
        if (!was_bought) {
            var new_market = std.ArrayList(Generator).init(self.allocator);

            for (self.gen_market[1..]) |gen| {
                try new_market.append(gen);
            }

            for (self.future_gens) |gen| {
                try new_market.append(gen);
            }

            try new_market.append(self.hidden_generators[0]);
            self.hidden_generators = self.hidden_generators[1..];

            try self.updateGenMarket(new_market.items);
            try self.displayGenerators();
        }
    }

    /// Allow the players to buy resources for their generators.
    fn phase3(self: *Game) !void {
        try self.displayResourceMarket();
    }

    /// Assign generators into current and future markets in the correct order.
    fn updateGenMarket(self: *Game, gens: []Generator) !void {
        std.sort.sort(Generator, gens, gen_mod.genComp);

        self.gen_market = gens[0..4];
        self.future_gens = gens[4..];
    }
};
