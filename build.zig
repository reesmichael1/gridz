const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("gridz", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Start a new game");
    run_step.dependOn(&run_cmd.step);

    const test_step = b.step("test", "Run the program tests");

    // Add any files that contain tests to this list
    const testable_files = [_][]const u8{
        "src/city.zig",
        "src/grid.zig",
        "src/player.zig",
        "src/resource_market.zig",
    };

    for (testable_files) |file| {
        const file_tests = b.addTest(file);
        test_step.dependOn(&file_tests.step);
    }
}
