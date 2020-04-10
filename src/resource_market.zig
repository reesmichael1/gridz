const Resource = @import("resource.zig").Resource;

/// A ResourceBlock is a spot in the Market for a single resource.
/// It holds a type of Resource and can optionally be filled
/// with an instance of that Resource.
const ResourceBlock = struct {
    /// The type of resource available in this block.
    resource: Resource,
    /// Whether or not the resource is available for purchase from this block.
    filled: bool,
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

    pub fn init() Market {
        const blocks = &[_]Block{};
        return Market{ .blocks = blocks };
    }
};
