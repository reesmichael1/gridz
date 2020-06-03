const std = @import("std");

const GameStage = @import("stage.zig").GameStage;
const Resource = @import("resource.zig").Resource;

/// Rules keeps track of the constants of the game,
/// some of which are set depending on the number of players.
pub const Rules = struct {
    pub const first_city_cost: u8 = 10;
    pub const second_city_cost: u8 = 15;
    pub const third_city_cost: u8 = 20;

    gens_removed: u8 = 8,
    game_end_gens: u8 = 17,
    max_gens: u8 = 3,
    players: usize = undefined,
    stage2_trigger: u8 = 7,

    pub fn init(player_count: usize) Rules {
        switch (player_count) {
            2 => return Rules{
                .players = player_count,
                .max_gens = 4,
                .game_end_gens = 21,
                .stage2_trigger = 10,
            },
            3 => return Rules{
                .players = player_count,
            },
            4 => return Rules{
                .players = player_count,
                .gens_removed = 4,
            },
            5 => return Rules{
                .players = player_count,
                .gens_removed = 0,
                .game_end_gens = 15,
            },
            6 => return Rules{
                .players = player_count,
                .gens_removed = 0,
                .game_end_gens = 14,
                .stage2_trigger = 6,
            },
            else => unreachable,
        }
    }

    /// Get how much money should be paid to a player
    /// based on how many cities they powered this round.
    pub fn getPaymentForCities(self: Rules, cities: u8) u64 {
        switch (cities) {
            0 => return 10,
            1 => return 22,
            2 => return 33,
            3 => return 44,
            4 => return 54,
            5 => return 64,
            6 => return 73,
            7 => return 82,
            8 => return 90,
            9 => return 98,
            10 => return 105,
            11 => return 112,
            12 => return 118,
            13 => return 124,
            14 => return 128,
            15 => return 134,
            16 => return 138,
            17 => return 142,
            18 => return 145,
            19 => return 148,
            20 => return 150,
            else => unreachable,
        }
    }

    // TODO: limit total resources available in the game
    /// Get the number of a resource that should be put back into the market
    /// depending on the current game state.
    pub fn getResourcesToRefill(self: Rules, stage: GameStage, resource: Resource) u8 {
        switch (stage) {
            GameStage.Stage1 => {
                switch (resource) {
                    Resource.Coal => return 4,
                    Resource.Oil => return 2,
                    Resource.Garbage => return 1,
                    Resource.Uranium => return 1,
                    else => unreachable,
                }
            },
            GameStage.Stage2 => {
                switch (resource) {
                    Resource.Coal => return 5,
                    Resource.Oil => return 3,
                    Resource.Garbage => return 2,
                    Resource.Uranium => return 1,
                    else => unreachable,
                }
            },
            GameStage.Stage3 => {
                switch (resource) {
                    Resource.Coal => return 3,
                    Resource.Oil => return 4,
                    Resource.Garbage => return 3,
                    Resource.Uranium => return 1,
                    else => unreachable,
                }
            },
        }
    }

    /// Get the number of cities required in one player's network
    /// to move the game into stage 2.
    pub fn getStage2Trigger(self: Rules) u8 {
        return switch (self.players) {
            2 => 10,
            3, 4, 5 => 7,
            6 => 6,
            else => unreachable,
        };
    }
};
