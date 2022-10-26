const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    var dir = try std.fs.cwd().openIterableDir(comptime thisDir() ++ "/2021", .{});
    defer dir.close();

    var iter = dir.iterateAssumeFirstIteration();
    while (try iter.next()) |entry| {
        if (entry.kind != .File) continue;
        const extension = std.fs.path.extension(entry.name);
        if (!std.mem.eql(u8, ".zig", extension)) continue;

        const basename = std.fs.path.basename(entry.name);
        const filepath = try dir.dir.realpathAlloc(b.allocator, entry.name);
        const name = b.fmt("2021-{s}", .{basename[0 .. basename.len - extension.len]});

        const run_test = b.addTest(filepath);
        const run_test_step = b.step(b.fmt("test-{s}", .{name}), "Run tests for this day");
        run_test_step.dependOn(&run_test.step);

        const exe = b.addExecutable(entry.name, filepath);
        const run_exe = exe.run();

        const run_program_step = b.step(b.fmt("run-{s}", .{name}), "Run the executable to get the answers for this day");
        run_program_step.dependOn(&run_exe.step);
    }
}

pub fn thisDir() []const u8 {
    return std.fs.path.dirname(@src().file).?;
}
