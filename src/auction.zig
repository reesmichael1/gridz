/// Support methods and structs for generator auctions
const std = @import("std");

const input = @import("input.zig");

const Game = @import("game.zig").Game;
const Generator = @import("generator.zig").Generator;
const Player = @import("player.zig").Player;

pub const AuctionResultTag = enum {
    Bought,
    Passed,
};

pub const PurchasedGen = struct {
    buyer: *Player,
    gen: Generator,
    cost: u64,
};

pub const AuctionResult = union(AuctionResultTag) {
    Bought: PurchasedGen,
    Passed: *Player,
};

pub fn getBidFromPlayer(player: *const Player, generator: Generator, min: u64) !u64 {
    const stdout = std.io.getStdOut().outStream();

    while (true) {
        const bid = try input.getNumberFromUser(u64, "{}, please enter your bid. ", .{player.name});

        if (bid < min) {
            try stdout.print("Bid must be at least {}.\n", .{min});
            continue;
        }

        if (bid > player.money) {
            try stdout.print("You don't have that much money to bid!\n", .{});
            continue;
        }

        return bid;
    }
}

/// Run a round of the generator auction.
/// eligible_players contains pointers to all of the player who can still bid,
/// and should be in the bidding order (with the first player at index 0).
pub fn auctionRound(game: *Game, eligible_players: []*Player, generators: []Generator, must_buy: bool) !AuctionResult {
    const stdout = std.io.getStdOut().outStream();
    const stdin = std.io.getStdIn();

    const starter = eligible_players[0];

    try stdout.print("{}, you have {} GZD.\n", .{ starter.name, starter.money });

    if (must_buy) {
        try stdout.print("You must buy a generator this round.\n", .{});
    } else {
        const wants_to_buy = try input.askYesOrNo("Would you like to bid on a generator this round? [y/n] ", .{});
        if (!wants_to_buy) {
            try stdout.print("Ok, you will not be able to buy a generator this round.\n", .{});
            return AuctionResult{ .Passed = starter };
        }
    }

    // Select the generator the players will bid on.
    var selected: ?Generator = null;
    outer: while (true) {
        const index = try input.getNumberFromUser(u8, "Please enter the index of the generator you would like to pick. ", .{});
        for (generators) |gen| {
            if (gen.index == index) {
                if (index > starter.money) {
                    try stdout.print("You do not have enough money to buy that generator.\n", .{});
                    continue;
                }
                selected = gen;
                break :outer;
            }
        }

        try stdout.print("Generator {} is not in the market, please try again.\n", .{index});
    }

    // Actually collect the bids for the generator.
    const generator = selected.?;
    var min_bid = generator.index;
    var highest_bid: u64 = try getBidFromPlayer(starter, generator, min_bid);

    if (eligible_players.len == 1) {
        const result = PurchasedGen{
            .buyer = starter,
            .gen = generator,
            .cost = highest_bid,
        };
        return AuctionResult{ .Bought = result };
    }

    var purchaser: ?*Player = null;
    var bidder_ix: u8 = 1;
    var highest_bidder: *Player = starter;

    var has_passed = std.BufSet.init(game.allocator);

    while (purchaser == null) {
        var bidder = eligible_players[bidder_ix];

        while (has_passed.exists(bidder.name)) {
            bidder_ix += 1;
            if (bidder_ix == eligible_players.len) {
                bidder_ix = 0;
            }
            bidder = eligible_players[bidder_ix];
        }

        if (has_passed.count() == eligible_players.len - 1) {
            purchaser = highest_bidder;
            break;
        }

        const bids_again = try input.askYesOrNo("{}, do you want to raise the bid? [y/n] ", .{bidder.name});

        if (!bids_again) {
            try has_passed.put(bidder.name);
        } else {
            highest_bidder = bidder;
            highest_bid = try getBidFromPlayer(bidder, generator, highest_bid + 1);
        }

        bidder_ix += 1;
        if (bidder_ix == eligible_players.len) {
            bidder_ix = 0;
        }
    }

    const result = PurchasedGen{
        .buyer = purchaser.?,
        .gen = generator,
        .cost = highest_bid,
    };
    return AuctionResult{ .Bought = result };
}
