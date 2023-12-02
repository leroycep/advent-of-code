const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const days = [_][]const u8{
        "01",
        "02",
    };
    const day = b.option([]const u8, "day", b.fmt("Specify the day you want to work with (default: {s})", .{days[days.len - 1]})) orelse days[days.len - 1];

    const day_input_path = std.Build.LazyPath{
        .path = b.pathJoin(&.{ day, "input" }),
    };

    const exe_name = b.fmt("2023-day{s}", .{day});
    const source_path = b.pathJoin(&.{ day, "main.zig" });

    const exe = b.addExecutable(.{
        .name = exe_name,
        .root_source_file = .{ .path = source_path },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addFileArg(day_input_path);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run executable for day, passing input file as the first argument");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = source_path },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests for day");
    test_step.dependOn(&run_unit_tests.step);
}
