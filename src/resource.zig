const std = @import("std");

/// The types of fuel available for generators.
pub const Resource = enum {
    Coal,
    Garbage,
    Oil,
    Uranium,
    Hydro,
    Wind,
    Solar,

    pub fn format(
        self: Resource,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        switch (self) {
            Resource.Coal => return std.fmt.format(out_stream, "Coal", .{}),
            Resource.Garbage => return std.fmt.format(out_stream, "Garbage", .{}),
            Resource.Oil => return std.fmt.format(out_stream, "Oil", .{}),
            Resource.Uranium => return std.fmt.format(out_stream, "Uranium", .{}),
            Resource.Hydro => return std.fmt.format(out_stream, "Hydro", .{}),
            Resource.Wind => return std.fmt.format(out_stream, "Wind", .{}),
            Resource.Solar => return std.fmt.format(out_stream, "Solar", .{}),
        }
    }
};
