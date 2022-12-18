const std = @import("std");
const glfw = @import("glfw");
const gl = @import("zgl");
const nanovg = @import("nanovg");
const Grid = @import("util").Grid;
const ConstGrid = @import("util").ConstGrid;

const DATA = @embedFile("data/day18.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try calculateSurfaceArea(arena.allocator(), DATA)});
    try out.print("{}\n", .{try calculateExteriorSurfaceArea(arena.allocator(), DATA)});
}

fn calculateSurfaceArea(allocator: std.mem.Allocator, input: []const u8) !i64 {
    var positions = std.AutoHashMap(@Vector(3, i64), void).init(allocator);
    defer positions.deinit();

    var line_iterator = std.mem.split(u8, std.mem.trim(u8, input, "\n"), "\n");
    while (line_iterator.next()) |line| {
        var number_iterator = std.mem.tokenize(u8, line, ",");
        var pos: [3]i64 = undefined;
        for (pos) |*element| {
            const number_string = number_iterator.next() orelse return error.InvalidFormat;
            element.* = try std.fmt.parseInt(i64, number_string, 10);
        }
        try positions.put(pos, {});
    }

    var surface_area: i64 = 0;
    var block_iter = positions.keyIterator();
    while (block_iter.next()) |pos| {
        surface_area += 6;

        const NEIGHBORS = [_]@Vector(3, i64){
            .{ 0, 0, -1 },
            .{ 0, 0, 1 },
            .{ 0, -1, 0 },
            .{ 0, 1, 0 },
            .{ -1, 0, 0 },
            .{ 1, 0, 0 },
        };

        for (NEIGHBORS) |offset| {
            var neighbor = pos.* + offset;
            if (positions.contains(neighbor)) {
                surface_area -= 1;
            }
        }
    }

    return surface_area;
}

fn calculateExteriorSurfaceArea(allocator: std.mem.Allocator, input: []const u8) !i64 {
    var positions = std.AutoHashMap(@Vector(3, i64), void).init(allocator);
    defer positions.deinit();

    var min: @Vector(3, i64) = .{ std.math.maxInt(i64), std.math.maxInt(i64), std.math.maxInt(i64) };
    var max: @Vector(3, i64) = .{ 0, 0, 0 };

    var line_iterator = std.mem.split(u8, std.mem.trim(u8, input, "\n"), "\n");
    while (line_iterator.next()) |line| {
        var number_iterator = std.mem.tokenize(u8, line, ",");
        var pos: [3]i64 = undefined;
        for (pos) |*element| {
            const number_string = number_iterator.next() orelse return error.InvalidFormat;
            element.* = try std.fmt.parseInt(i64, number_string, 10);
        }
        try positions.put(pos, {});

        min = @min(min, @as(@Vector(3, i64), pos));
        max = @max(max, @as(@Vector(3, i64), pos));
    }

    min -= @Vector(3, i64){ 1, 1, 1 };
    max += @Vector(3, i64){ 1, 1, 1 };

    const size = max - min + @Vector(3, i64){ 1, 1, 1 };
    const grid = try allocator.alloc(u8, @intCast(usize, @reduce(.Mul, size)));
    defer allocator.free(grid);
    // 0 for blank, 1 for block, 2 for exterior
    std.mem.set(u8, grid, 0);

    var block_iter = positions.keyIterator();
    while (block_iter.next()) |pos| {
        const index = pos.* - min;
        const i = @intCast(usize, index[2] * size[1] * size[0] + index[1] * size[0] + index[0]);
        grid[i] = 1;
    }

    if (grid[0] == 1) return error.Unhandled;

    var next = std.ArrayList(@Vector(3, i64)).init(allocator);
    defer next.deinit();
    try next.append(min);

    while (next.popOrNull()) |pos| {
        const index = pos - min;
        if (@reduce(.Or, index < @Vector(3, i64){ 0, 0, 0 }) or @reduce(.Or, index >= size)) {
            continue;
        }
        const i = @intCast(usize, index[2] * size[1] * size[0] + index[1] * size[0] + index[0]);

        if (grid[i] == 0) {
            grid[i] = 2;

            const NEIGHBORS = [_]@Vector(3, i64){
                .{ 0, 0, -1 },
                .{ 0, 0, 1 },
                .{ 0, -1, 0 },
                .{ 0, 1, 0 },
                .{ -1, 0, 0 },
                .{ 1, 0, 0 },
            };

            for (NEIGHBORS) |neighbor_offset| {
                try next.append(pos + neighbor_offset);
            }
        }
    }

    var surface_area: i64 = 0;
    block_iter = positions.keyIterator();
    while (block_iter.next()) |pos| {
        const NEIGHBORS = [_]@Vector(3, i64){
            .{ 0, 0, -1 },
            .{ 0, 0, 1 },
            .{ 0, -1, 0 },
            .{ 0, 1, 0 },
            .{ -1, 0, 0 },
            .{ 1, 0, 0 },
        };

        for (NEIGHBORS) |neighbor_offset| {
            var neighbor = pos.* + neighbor_offset;

            const index = neighbor - min;
            if (@reduce(.Or, index < @Vector(3, i64){ 0, 0, 0 }) or @reduce(.Or, index >= size)) {
                surface_area += 1;
                continue;
            }
            const i = @intCast(usize, index[2] * size[1] * size[0] + index[1] * size[0] + index[0]);
            if (grid[i] == 2) {
                surface_area += 1;
            }
        }
    }

    return surface_area;
}

const TEST_DATA =
    \\2,2,2
    \\1,2,2
    \\3,2,2
    \\2,1,2
    \\2,3,2
    \\2,2,1
    \\2,2,3
    \\2,2,4
    \\2,2,6
    \\1,2,5
    \\3,2,5
    \\2,1,5
    \\2,3,5
    \\
;

test "challenge 1" {
    const output = try calculateSurfaceArea(std.testing.allocator, TEST_DATA);
    try std.testing.expectEqual(@as(i64, 64), output);
}

test "challenge 2" {
    const output = try calculateExteriorSurfaceArea(std.testing.allocator, TEST_DATA);
    try std.testing.expectEqual(@as(i64, 58), output);
}
