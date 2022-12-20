const std = @import("std");

const DATA = @embedFile("./data/day11.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(arena.allocator(), DATA)});
    try out.print("{}\n", .{try challenge2(arena.allocator(), DATA)});
}

pub fn challenge1(allocator: std.mem.Allocator, text: []const u8) !u64 {
    const grid = try Grid.parse(allocator, text);
    defer grid.deinit(allocator);

    var number_of_flashes: u64 = 0;

    var iterations: u32 = 0;
    while (iterations < 100) : (iterations += 1) {
        number_of_flashes += grid.step();
    }

    return number_of_flashes;
}

const Grid = struct {
    area: []u32,
    flashed: []bool,
    width: usize,

    pub fn deinit(this: @This(), allocator: std.mem.Allocator) void {
        allocator.free(this.area);
        allocator.free(this.flashed);
    }

    pub fn parse(allocator: std.mem.Allocator, text: []const u8) !Grid {
        var area = std.ArrayList(u32).init(allocator);
        defer area.deinit();

        var width: usize = 0;
        var line_iter = std.mem.tokenize(u8, text, "\n");
        while (line_iter.next()) |line| {
            if (width == 0) width = line.len;
            for (line) |character| {
                try area.append(character - '0');
            }
        }

        return Grid{
            .flashed = try allocator.alloc(bool, area.items.len),
            .area = try area.toOwnedSlice(),
            .width = width,
        };
    }

    pub fn step(this: @This()) u64 {
        this.incrementAll();
        while (this.flash()) {}
        const number_of_flashes = tallyFlashes(this.flashed);
        this.reset();
        return number_of_flashes;
    }

    pub fn incrementAll(this: @This()) void {
        for (this.area) |*octopus| {
            octopus.* += 1;
        }
    }

    pub fn dump(this: @This()) void {
        const height = this.area.len / this.width;

        var pos = @Vector(2, i64){ 0, 0 };
        while (pos[1] < @intCast(i64, height)) : (pos[1] += 1) {
            pos[0] = 0;
            while (pos[0] < @intCast(i64, this.width)) : (pos[0] += 1) {
                const index = @intCast(usize, pos[1]) * this.width + @intCast(usize, pos[0]);
                std.debug.print("{}", .{this.area[index]});
            }
            std.debug.print("\n", .{});
        }
        std.debug.print("\n", .{});
    }

    pub fn flash(this: @This()) bool {
        const height = this.area.len / this.width;

        var any_flashed = false;

        var pos = @Vector(2, i64){ 0, 0 };
        while (pos[1] < @intCast(i64, height)) : (pos[1] += 1) {
            pos[0] = 0;
            while (pos[0] < @intCast(i64, this.width)) : (pos[0] += 1) {
                const index = @intCast(usize, pos[1]) * this.width + @intCast(usize, pos[0]);
                if (this.area[index] > 9 and !this.flashed[index]) {
                    this.flashed[index] = true;
                    any_flashed = true;
                    const neighbors = [_][2]i64{
                        .{ -1, -1 },
                        .{ 0, -1 },
                        .{ 1, -1 },
                        .{ -1, 0 },
                        .{ 1, 0 },
                        .{ -1, 1 },
                        .{ 0, 1 },
                        .{ 1, 1 },
                    };
                    for (neighbors) |offset| {
                        const neighbor_pos = pos + offset;
                        if (neighbor_pos[0] < 0 or neighbor_pos[1] < 0 or neighbor_pos[0] >= this.width or neighbor_pos[1] >= height) {
                            continue;
                        }
                        const neighbor_index = @intCast(usize, neighbor_pos[1]) * this.width + @intCast(usize, neighbor_pos[0]);
                        this.area[neighbor_index] += 1;
                    }
                }
            }
        }

        return any_flashed;
    }

    pub fn reset(this: @This()) void {
        for (this.area) |*octopus| {
            if (octopus.* > 9) {
                octopus.* = 0;
            }
        }
        for (this.flashed) |*did_flash| {
            did_flash.* = false;
        }
    }
};

pub fn tallyFlashes(has_flashed: []const bool) u64 {
    var total: u64 = 0;
    for (has_flashed) |did_flash| {
        if (did_flash) {
            total += 1;
        }
    }
    return total;
}

test challenge1 {
    try std.testing.expectEqual(@as(u64, 1656), try challenge1(std.testing.allocator,
        \\5483143223
        \\2745854711
        \\5264556173
        \\6141336146
        \\6357385478
        \\4167524645
        \\2176841721
        \\6882881134
        \\4846848554
        \\5283751526
        \\
    ));
}

test "flashes" {
    const steps = [_]Grid{
        try Grid.parse(std.testing.allocator,
            \\11111
            \\19991
            \\19191
            \\19991
            \\11111
            \\
        ),
        try Grid.parse(std.testing.allocator,
            \\34543
            \\40004
            \\50005
            \\40004
            \\34543
            \\
        ),
        try Grid.parse(std.testing.allocator,
            \\45654
            \\51115
            \\61116
            \\51115
            \\45654
            \\
        ),
    };
    defer {
        for (steps) |step| {
            step.deinit(std.testing.allocator);
        }
    }

    std.debug.print("width = {}\n", .{steps[0].width});
    steps[0].dump();
    _ = steps[0].step();
    steps[0].dump();
    steps[1].dump();
    try std.testing.expectEqualSlices(u32, steps[1].area, steps[0].area);
    _ = steps[0].step();
    try std.testing.expectEqualSlices(u32, steps[2].area, steps[0].area);
}

pub fn challenge2(allocator: std.mem.Allocator, text: []const u8) !u64 {
    const grid = try Grid.parse(allocator, text);
    defer grid.deinit(allocator);

    var iterations: u32 = 0;
    while (true) : (iterations += 1) {
        if (true and iterations % 1000 == 0) {
            std.debug.print("iterations = {}\n", .{iterations});
        }
        if (std.mem.allEqual(u32, grid.area, grid.area[0])) {
            break;
        }
        _ = grid.step();
    }

    return iterations;
}
