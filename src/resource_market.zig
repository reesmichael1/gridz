const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

pub const MarketError = error{NotEnoughResources};

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

            const resources = [4]ResourceBlock{
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

            var resource_blocks = std.ArrayList(ResourceBlock).init(allocator);
            for (resources) |block| {
                try resource_blocks.append(block);
            }

            try blocks.append(Block{
                .cost = cost,
                .resources = resource_blocks.items,
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
            var resource_blocks = std.ArrayList(ResourceBlock).init(allocator);
            for (resources) |block| {
                try resource_blocks.append(block);
            }

            try blocks.append(Block{
                .cost = cost,
                .resources = resource_blocks.items,
            });
        }

        return Market{ .blocks = blocks.items };
    }

    /// Buy a number of a resource from the market.
    pub fn buyResource(self: *Market, resource: Resource, count: u8) void {
        var remaining: u8 = count;

        for (self.blocks) |block| {
            for (block.resources) |*r| {
                if (r.resource == resource) {
                    if (r.count_filled >= remaining) {
                        r.count_filled -= remaining;
                        remaining = 0;
                        return;
                    } else {
                        remaining -= r.count_filled;
                        r.count_filled = 0;
                    }
                }
            }
        }
    }

    /// Calculate the cost of buying a number of a resource from the market.
    /// Returns an error if there are not enough resources in the market
    /// to buy the specified count.
    pub fn costOfResources(self: Market, resource: Resource, count: u8) !u64 {
        var cost: u64 = 0;
        var remaining: u8 = count;

        for (self.blocks) |block| {
            for (block.resources) |*r| {
                if (r.resource == resource) {
                    if (r.count_filled >= remaining) {
                        cost += block.cost * remaining;
                        remaining = 0;
                        return cost;
                    } else {
                        remaining -= r.count_filled;
                        cost += block.cost * r.count_filled;
                    }
                }
            }
        }

        return error.NotEnoughResources;
    }
};

test "buying coal from first block" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var market = try Market.init(&arena.allocator);

    std.testing.expectEqual(@as(u64, 2), try market.costOfResources(Resource.Coal, 2));

    market.buyResource(Resource.Coal, 2);
    std.testing.expectEqual(@as(u64, 1), market.blocks[0].resources[0].count_filled);
}

test "buying coal across two blocks" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var market = try Market.init(&arena.allocator);
    const expected_cost: u64 = 5;
    std.testing.expectEqual(expected_cost, try market.costOfResources(Resource.Coal, 4));

    market.buyResource(Resource.Coal, 4);
    std.testing.expectEqual(@as(u64, 0), market.blocks[0].resources[0].count_filled);
    std.testing.expectEqual(@as(u64, 2), market.blocks[1].resources[0].count_filled);
}

test "buying oil from first available block" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var market = try Market.init(&arena.allocator);
    const expected_cost: u64 = 3;
    std.testing.expectEqual(expected_cost, try market.costOfResources(Resource.Oil, 1));

    market.buyResource(Resource.Oil, 1);
    std.testing.expectEqual(@as(u64, 2), market.blocks[2].resources[1].count_filled);
}

test "buying too many resources from the market fails" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var market = try Market.init(&arena.allocator);
    std.testing.expectError(error.NotEnoughResources, market.costOfResources(Resource.Coal, 100));
}
