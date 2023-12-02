const std = @import("std");
const nanovg = @import("dep/nanovg-zig/build.zig");

pub fn build(b: *std.build.Builder) !void {
    const optimize = b.standardOptimizeOption();

    const zgl_pkg = std.build.Pkg{
        .name = "zgl",
        .source = .{ .path = "dep/zgl/zgl.zig" },
    };

    const nanovg_pkg = nanovg.getPkg(zgl_pkg);

    const util_pkg = std.build.Pkg{
        .name = "util",
        .source = .{ .path = "util/util.zig" },
        .dependencies = &.{
            @import("root").dependencies.imports.glfw.pkg,
            zgl_pkg,
            nanovg_pkg,
        },
    };

    const glfw_dep = b.dependency("glfw", .{});
    const glfw_lib = glfw_dep.artifact("glfw");

    const util_lib = b.addStaticLibrary("util", null);
    util_lib.installHeadersDirectory("dep/nanovg-zig/src", "");
    util_lib.linkLibrary(glfw_lib);
    util_lib.linkSystemLibrary("avformat");
    util_lib.linkSystemLibrary("avcodec");
    util_lib.linkSystemLibrary("avutil");
    util_lib.linkSystemLibrary("swscale");
    nanovg.link(util_lib);
    util_lib.setBuildMode(mode);

    const years = &[_][]const u8{
        "2021",
        "2022",
    };
    inline for (years) |year| {
        var dir = try std.fs.cwd().openIterableDir(comptime thisDir() ++ "/" ++ year, .{});
        defer dir.close();

        var iter = dir.iterateAssumeFirstIteration();
        while (try iter.next()) |entry| {
            if (entry.kind != .File) continue;
            const extension = std.fs.path.extension(entry.name);
            if (!std.mem.eql(u8, ".zig", extension)) continue;

            const basename = std.fs.path.basename(entry.name);
            const filepath = try dir.dir.realpathAlloc(b.allocator, entry.name);
            const name = b.fmt(year ++ "-{s}", .{basename[0 .. basename.len - extension.len]});

            const run_test = b.addTest(filepath);
            run_test.addPackage(util_pkg);
            run_test.setBuildMode(mode);

            const run_test_step = b.step(b.fmt("{s}-test", .{name}), "Run tests for this day");
            run_test_step.dependOn(&run_test.step);

            const exe = b.addExecutable(name, filepath);
            exe.addPackage(util_pkg);
            exe.linkLibrary(util_lib);
            exe.linkLibrary(glfw_lib);

            exe.setBuildMode(mode);
            exe.install();

            const run_exe = exe.run();
            if (b.args) |args| {
                run_exe.addArgs(args);
            }

            const run_program_step = b.step(b.fmt("{s}-run", .{name}), "Run the executable to get the answers for this day");
            run_program_step.dependOn(&run_exe.step);

            const day_step = b.step(b.fmt("{s}", .{name}), "Run the tests, and then run the executable");
            day_step.dependOn(&run_test.step);
            day_step.dependOn(&run_exe.step);
        }
    }
}

pub fn thisDir() []const u8 {
    return std.fs.path.dirname(@src().file).?;
}
