/// A Player is a competitor in the game.
pub const Player = struct {
    /// The name this player is playing under
    name: []const u8,
    /// The amount of money the player has on hand
    money: u64 = 50, // Use a u64 because you never know!

    pub fn init(name: []const u8) Player {
        return Player{
            .name = name,
        };
    }
};
