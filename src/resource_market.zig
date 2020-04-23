const std = @import("std");
const Allocator = std.mem.Allocator;

const Resource = @import("resource.zig").Resource;

/// A ResourceBlock is a spot in the Market for a single resource.
/// It holds a type of Resource and can optionally be filled
/// with an instance of that Resource.
const ResourceBlock = struct {
    /// The type of resource available in this block.
    resource: Resource,
    /// The amount of this Resource this block can hold.
    count_available: u8,
    /// The amount of this Resource the block is currently holding.
    count_filled: u8,
};

/// A Block holds a group of resources together under a common cost.
const Block = struct {
    /// The common cost of all resources in this Block.
    cost: u8,
    /// The resources that can and/or have been placed in this Block.
    resources: []ResourceBlock,
};

/// The Market keeps track of what resources are available at what cost.
pub const Market = struct {
    /// The groups of Resources available in the Market.
    blocks: []Block,

    pub fn init(allocator: *Allocator) !Market {
        // const blocks = &[_]Block{};
        var blocks = std.ArrayList(Block).init(allocator);

        var cost: u8 = 1;
        while (cost <= 8) : (cost += 1) {
            var oil_count: u8 = 0;
            var garbage_count: u8 = 0;

            if (cost >= 3) {
                oil_count = 3;
            }

            if (cost >= 7) {
                garbage_count = 3;
            }

            const resources = &[_]ResourceBlock{
                ResourceBlock{
                    .resource = Resource.Coal,
                    .count_available = 3,
                    .count_filled = 3,
                },
                ResourceBlock{
                    .resource = Resource.Oil,
                    .count_available = 3,
                    .count_filled = oil_count,
                },
                ResourceBlock{
                    .resource = Resource.Garbage,
                    .count_available = 3,
                    .count_filled = garbage_count,
                },
                ResourceBlock{
                    .resource = Resource.Uranium,
                    .count_available = 1,
                    .count_filled = 0,
                },
            };

            try blocks.append(Block{
                .cost = cost,
                .resources = resources,
            });
        }

        cost = 12;
        while (cost <= 16) : (cost += 2) {
            var uranium_count: u8 = 0;
            if (cost >= 14) {
                uranium_count = 1;
            }

            const resources = &[_]ResourceBlock{
                ResourceBlock{
                    .resource = Resource.Uranium,
                    .count_available = 1,
                    .count_filled = uranium_count,
                },
            };

            try blocks.append(Block{
                .cost = cost,
                .resources = resources,
            });
        }

        return Market{ .blocks = blocks.items };
    }
};
