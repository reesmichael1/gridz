const std = @import("std");
const testing = std.testing;

const constants = @import("constants.zig");
const GameStage = @import("stage.zig").GameStage;
const Player = @import("player.zig").Player;

/// A City is a location that up to three Players can settle in.
/// Cities are connected to each other as specified in the Board.
pub const City = struct {
    /// The name displayed for this City
    name: []const u8,
    /// The first (if any) player to settle in the City
    firstPlayer: ?Player = null,
    /// The second (if any) player to settle in the City
    secondPlayer: ?Player = null,
    /// The third (if any) player to settle in the City
    thirdPlayer: ?Player = null,
    /// X coordinate of City on map
    x: u8,
    /// Y coordinate of City on map
    y: u8,

    pub fn init(name: []const u8, x: u8, y: u8) City {
        return City{
            .name = name,
            .x = x,
            .y = y,
        };
    }

    pub fn eq(self: City, other: City) bool {
        return std.mem.eql(u8, self.name, other.name) and self.x == other.x and self.y == other.y;
    }

    /// Check if a City has room for a Player to build in it
    /// at the current stage of the game.
    pub fn canBuild(self: City, stage: GameStage) bool {
        var player: ?Player = null;
        switch (stage) {
            GameStage.Stage1 => player = self.firstPlayer,
            GameStage.Stage2 => player = self.secondPlayer,
            GameStage.Stage3 => player = self.thirdPlayer,
        }

        if (player) |_| {
            return false;
        }

        return true;
    }

    /// Calculate the cost of building in this City
    /// (not counting connection costs).
    /// Will panic if called in a city with no room left.
    pub fn buildingCost(self: City) u8 {
        if (self.firstPlayer == null) {
            return constants.first_city_cost;
        } else if (self.secondPlayer == null) {
            return constants.second_city_cost;
        }

        std.debug.assert(self.thirdPlayer == null);
        return constants.third_city_cost;
    }

    pub fn addPlayer(self: *City, player: Player) void {
        if (self.firstPlayer == null) {
            self.firstPlayer = player;
            return;
        }

        if (self.secondPlayer == null) {
            self.secondPlayer = player;
            return;
        }

        std.debug.assert(self.thirdPlayer == null);
        self.thirdPlayer = player;
    }
};

test "building capacities in the various stages" {
    var city = City.init("Test City", 1, 2);

    testing.expect(city.canBuild(GameStage.Stage1));
    testing.expect(city.canBuild(GameStage.Stage2));
    testing.expect(city.canBuild(GameStage.Stage3));
    testing.expectEqual(constants.first_city_cost, city.buildingCost());

    // city.firstPlayer = Player.init("Player 1");
    city.addPlayer(Player.init("Player 1"));

    testing.expect(!city.canBuild(GameStage.Stage1));
    testing.expect(city.canBuild(GameStage.Stage2));
    testing.expect(city.canBuild(GameStage.Stage3));
    testing.expectEqual(constants.second_city_cost, city.buildingCost());

    // city.secondPlayer = Player.init("Player 2");
    city.addPlayer(Player.init("Player 2"));

    testing.expect(!city.canBuild(GameStage.Stage1));
    testing.expect(!city.canBuild(GameStage.Stage2));
    testing.expect(city.canBuild(GameStage.Stage3));
    testing.expectEqual(constants.third_city_cost, city.buildingCost());

    // city.thirdPlayer = Player.init("Player 3");
    city.addPlayer(Player.init("Player 3"));

    testing.expect(!city.canBuild(GameStage.Stage1));
    testing.expect(!city.canBuild(GameStage.Stage2));
    testing.expect(!city.canBuild(GameStage.Stage3));
}
