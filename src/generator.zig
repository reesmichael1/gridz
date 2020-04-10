const std = @import("std");

const Resource = @import("resource.zig");

/// A Generator can power some number of cities each turn
/// by consuming a certain number of resources.
pub const Generator = struct {
    /// The index of this generator (and minimum bid allowed)
    index: u8,
    /// The number of cities that this generator can power
    can_power: u8,
    /// The collection of resources this generator consumes each turn.
    /// Each list within the list is a group of resources that can pair the generator.
    /// For example, if a generator can be powered by 2 coal or by 1 oil,
    /// then .Resources would be [[Coal, Coal], [Oil]].
    resources: [][]Resource,
};
