const std = @import("std");
const Allocator = std.mem.Allocator;

const auction = @import("auction.zig");
const gen_mod = @import("generator.zig");
const player_mod = @import("player.zig");
const input = @import("input.zig");

const Block = @import("resource_market.zig").Block;
const City = @import("city.zig").City;
const GameStage = @import("stage.zig").GameStage;
const Generator = gen_mod.Generator;
const Grid = @import("grid.zig").Grid;
const Loader = @import("loader.zig").Loader;
const Market = @import("resource_market.zig").Market;
const Player = player_mod.Player;

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

/// Print an integer into a row of the buffer, starting at an x coordinate.
fn printNumberAtCoord(comptime T: type, buf: []u8, num: T, x: u64) void {
    const digits = @floatToInt(u8, @floor(@log10(@intToFloat(f32, num)))) + 1;
    _ = std.fmt.formatIntBuf(buf[x .. x + digits], num, 10, false, std.fmt.FormatOptions{});
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
        try self.phase4();

        self.has_ended = true;
    }

    /// Display the current game state for the players to see.
    fn updateDisplay(self: Game) !void {
        const stdout = std.io.getStdOut().outStream();

        try stdout.print("Player order for turn {}:\n", .{self.round});
        for (self.players) |player, ix| {
            try stdout.print("{}: {}\n", .{ ix + 1, player.name });
        }

        try self.displayMap();
        try self.displayGenerators();
    }

    /// Display the cities, their connections, and where players have built.
    fn displayMap(self: Game) !void {
        const col_offset = 4;
        const diag_offset = 2;
        const box_width = 14;
        const box_height = 5;
        const rows = 5;
        const cols = 4;
        const box_spacing_x = 20;
        const box_spacing_y = 6;
        const padding_x = box_width + box_spacing_x;
        const padding_y = box_height + box_spacing_y;

        const height = (rows - 1) * padding_y + box_height + 1;
        const width = (cols - 1) * padding_x + box_width + 1;
        var buf: [height][width]u8 = undefined;

        // Initialize the buffer to spaces
        for (buf) |*row| {
            for (row) |_, ix| {
                row[ix] = ' ';
            }
        }

        const stdout = std.io.getStdOut().outStream();
        try stdout.print("\n\n", .{});

        for (self.grid.cities) |city| {
            const start_x = @as(usize, city.x * padding_x);
            const start_y = city.y * padding_y;

            // Draw a box around the area for the city information.
            var x = start_x;
            var y = start_y + 1;
            while (x < start_x + box_width) : (x += 1) {
                buf[start_y][x] = '-';
                buf[start_y + box_height][x] = '-';
            }

            while (y < start_y + box_height) : (y += 1) {
                buf[y][start_x] = '|';
                buf[y][start_x + box_width] = '|';
            }

            // Print the city name in the box's first row.
            y = start_y + 1;
            x = start_x + (1 + box_width - city.name.len) / 2;
            for (city.name) |ch, ix| {
                buf[y][x + ix] = ch;
            }

            // Print the players (if any) who have built in the city.
            y = start_y + 2;
            x = start_x + 1;

            var players = &[_]?Player{ city.firstPlayer, city.secondPlayer, city.thirdPlayer };
            for (players) |maybe_player, ix| {
                printNumberAtCoord(usize, buf[y + ix][0..], ix + 1, x);
                buf[y + ix][x + 1] = '.';

                if (maybe_player) |player| {
                    for (player.name) |ch, name_ix| {
                        // TODO: assert player names fit
                        buf[y + ix][x + 3 + name_ix] = ch;
                    }
                }
            }

            // Print the connections between cities.
            // It is assumed that map designers avoid crossings
            // and otherwise verify that their layout is acceptable.
            const connections = try self.grid.getConnections(self.allocator, city);
            for (connections) |connection| {
                const weight = self.grid.getWeight(city, connection) orelse unreachable;

                if (connection.x == city.x + 1 and connection.y == city.y) {
                    // Draw horizontal bars between horizontal connections
                    x = start_x + box_width + 1;
                    y = start_y + 2;

                    while (@mod(x, padding_x) != 0) : (x += 1) {
                        buf[y][x] = '-';
                    }

                    const weight_ix = start_x + box_width + box_spacing_x / 2;
                    printNumberAtCoord(u8, buf[y][0..], weight, weight_ix);
                } else if (connection.y == city.y + 1 and connection.x == city.x) {
                    // Draw vertical bars between vertical connections
                    x = start_x + box_width / 2;
                    y = start_y + box_height + 1;

                    while (@mod(y, padding_y) != 0) : (y += 1) {
                        buf[y][x] = '|';
                    }

                    const weight_ix = start_y + box_height + box_spacing_y / 2;
                    printNumberAtCoord(u8, buf[weight_ix][0..], weight, x);
                } else if (connection.x > city.x and connection.y > city.y) {
                    // Connections below and to the right
                    x = start_x + box_width + 1;
                    y = start_y + box_height + 1;

                    const diag_connector = '\\';
                    const delta = (box_spacing_y + (connection.y - city.y - 1) * padding_y) / 2;
                    const midpoint = start_y + box_height + delta;
                    var lines_needed: u8 = 0;
                    while (y < midpoint) {
                        buf[y][x] = diag_connector;
                        y += 1;
                        x += 1;
                        lines_needed += 1;
                    }

                    while (x < padding_x * connection.x - lines_needed) : (x += 1) {
                        buf[y][x] = '-';
                    }

                    y += 1;
                    while (y != padding_y * connection.y) {
                        buf[y][x] = diag_connector;
                        y += 1;
                        x += 1;
                    }

                    const weight_ix = start_x + box_width + box_spacing_x / 2;
                    printNumberAtCoord(u8, buf[midpoint][0..], weight, weight_ix);
                } else if (city.x > 0 and connection.x == city.x - 1 and connection.y > city.y) {
                    // Connections below and to the left
                    x = start_x - 1;
                    y = start_y + box_height + 1;

                    const diag_connector = '/';
                    const delta = (box_spacing_y + (connection.y - city.y - 1) * padding_y) / 2;
                    const midpoint = start_y + box_height + delta;
                    var lines_needed: u8 = 0;
                    while (y < midpoint) {
                        buf[y][x] = diag_connector;
                        y += 1;
                        x -= 1;
                        lines_needed += 1;
                    }

                    while (x > padding_x * connection.x + box_width + lines_needed) : (x -= 1) {
                        buf[y][x] = '-';
                    }

                    y += 1;
                    while (y != padding_y * connection.y) {
                        buf[y][x] = diag_connector;
                        y += 1;
                        x -= 1;
                    }

                    const weight_ix = start_x - padding_x + box_width + box_spacing_x / 2;
                    printNumberAtCoord(u8, buf[midpoint][0..], weight, weight_ix);
                }
            }
        }

        for (buf) |row| {
            try stdout.print("{}\n", .{row});
        }
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

        var player_ix: usize = self.players.len - 1;

        while (player_ix >= 0) : (player_ix -= 1) {
            try self.buyResources(&self.players[player_ix]);
            try self.displayResourceMarket();

            if (player_ix == 0) {
                break;
            }
        }
    }

    /// Allow the players to build in the various cities.
    fn phase4(self: *Game) !void {
        const stdout = std.io.getStdOut().outStream();

        var player_ix: usize = self.players.len - 1;

        while (player_ix >= 0) : (player_ix -= 1) {
            try self.buildCities(&self.players[player_ix]);

            if (player_ix == 0) {
                break;
            }
        }
    }

    fn buildCities(self: *Game, player: *Player) !void {
        var built: usize = 0;
        const stdout = std.io.getStdOut().outStream();

        while (true) {
            try self.displayMap();
            try stdout.print("\n\n", .{});

            var will_build: bool = undefined;
            if (built == 0) {
                const prompt = "{}, would you like to build a city this round? [y/n] ";
                will_build = try input.askYesOrNo(prompt, .{player.name});
            } else {
                const prompt = "{}, would you like to build another city this round? [y/n] ";
                will_build = try input.askYesOrNo(prompt, .{player.name});
            }

            if (!will_build) {
                return;
            }

            choose_city: while (true) {
                var buf: [15]u8 = undefined;
                const name = try input.askUserForInput("Please enter the name of your next city: ", .{}, &buf);

                // Verify that the city given exists and this player can build in it.
                const city = self.grid.findCityByName(name) orelse {
                    try stdout.print("There is no city called {}.\n", .{name});
                    continue;
                };

                for (player.cities) |owned_city| {
                    if (owned_city.eq(city.*)) {
                        try stdout.print("You have already built in {}!\n", .{city.name});
                        continue :choose_city;
                    }
                }

                if (!city.canBuild(self.stage)) {
                    try stdout.print("There isn't room in {} to build.\n", .{city.name});
                    continue;
                }

                const build_cost = city.buildingCost();
                const connection_cost = try self.grid.getMinConnectionCost(self.allocator, city.*, player.cities);
                const total_cost = build_cost + connection_cost;

                if (total_cost > player.money) {
                    try stdout.print("You don't have enough money to build in {}.\n", .{city.name});
                    break;
                }

                // Ask the player to confirm the total cost.
                if (!try input.askYesOrNo("That will cost {} GZD, is that ok? [y/n] ", .{total_cost})) {
                    break;
                }

                // Actually add the player to the city and the city to the player's network.
                built += 1;
                player.money -= total_cost;

                city.addPlayer(player.*);

                var cities = std.ArrayList(City).init(self.allocator);
                for (player.cities) |owned_city| {
                    try cities.append(owned_city);
                }

                try cities.append(city.*);
                player.cities = cities.items;
                break;
            }
        }
    }

    fn buyResources(self: *Game, player: *Player) !void {
        const stdout = std.io.getStdOut().outStream();
        const can_store = try player.getStoreableResources(self.allocator);

        try stdout.print("Buying resources for {}\n", .{player.name});

        var it = can_store.iterator();
        while (it.next()) |resource| {
            var to_buy: u8 = 0;
            var cost: u64 = 0;
            while (true) {
                to_buy = try input.getNumberFromUser(u8, "You can store up to {} {}. How many would you like to buy? ", .{
                    resource.value,
                    resource.key,
                });

                if (to_buy == 0) {
                    try stdout.print("Please enter a non-zero number.\n", .{});
                    continue;
                }

                if (to_buy > resource.value) {
                    try stdout.print("You can store at most {} {}.\n", .{
                        resource.value,
                        resource.key,
                    });
                    continue;
                }

                cost = self.resource_market.costOfResources(resource.key, to_buy) catch |err| {
                    try stdout.print("The market doesn't have that many resources available.\n", .{});
                    continue;
                };

                if (cost > player.money) {
                    try stdout.print("You can't afford to buy that many {}.\n", .{resource.key});
                    continue;
                }

                break;
            }

            self.resource_market.buyResource(resource.key, to_buy);
            player.money -= cost;
        }

        try stdout.print("\n", .{});
    }

    /// Assign generators into current and future markets in the correct order.
    fn updateGenMarket(self: *Game, gens: []Generator) !void {
        std.sort.sort(Generator, gens, gen_mod.genComp);

        self.gen_market = gens[0..4];
        self.future_gens = gens[4..];
    }
};
