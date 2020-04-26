const std = @import("std");

const Resource = @import("resource.zig").Resource;

/// A Generator can power some number of cities each turn
/// by consuming a certain number of resources.
pub const Generator = struct {
    /// The index of this generator (and minimum bid allowed)
    index: u8,
    /// The number of cities that this generator can power
    can_power: u8,
    /// The type of Resource that powers this generator.
    /// Eventually, we'll want to allow for hybrid generators
    /// that can use multiple types of Resources, but for now,
    /// we'll just use one.
    resource: Resource,
    /// The number of Resources this generator needs to operate
    resource_count: u8,

    pub fn init(index: u8, can_power: u8, resource_count: u8, resource: Resource) Generator {
        return Generator{
            .index = index,
            .can_power = can_power,
            .resource_count = resource_count,
            .resource = resource,
        };
    }
};

/// Return true if gen1 has a lower index than gen2, false otherwise.
/// Useful for sorting slices of generators by index.
pub fn genComp(gen1: Generator, gen2: Generator) bool {
    return gen1.index < gen2.index;
}
