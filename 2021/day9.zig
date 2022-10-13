const std = @import("std");

const DATA = @embedFile("./data/day9.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(DATA)});
    try out.print("{}\n", .{try challenge2(arena.allocator(), DATA)});
}

pub fn challenge1(data: []const u8) !u64 {
    const index_of_first_newline = std.mem.indexOf(u8, data, "\n") orelse return error.InvalidFormat;
    const width = index_of_first_newline + 1;
    if (data.len % width != 0) {
        std.debug.print("len = {}, width = {}\n", .{ data.len, width });
        return error.InvalidDimensions;
    }
    const height = data.len / width;

    var total_risk_level: u64 = 0;

    var j: i32 = 0;
    while (j < @intCast(i32, height)) : (j += 1) {
        var i: i32 = 0;
        while (i < @intCast(i32, width) - 1) : (i += 1) {
            if (isLowPoint(data, width, i, j)) {
                total_risk_level += depthAt(data, width, i, j).? + 1;
            }
        }
    }

    return total_risk_level;
}

pub fn isLowPoint(data: []const u8, width: usize, x: i32, y: i32) bool {
    const depth = depthAt(data, width, x, y).?;

    var j: i32 = -1;
    while (j <= 1) : (j += 1) {
        var i: i32 = -1;
        while (i <= 1) : (i += 1) {
            if (i == 0 and j == 0) continue;
            const depth_at_neighbor = depthAt(data, width, x + i, y + j) orelse continue;
            if (depth_at_neighbor <= depth) {
                return false;
            }
        }
    }
    return true;
}

pub fn depthAt(data: []const u8, width: usize, x: i32, y: i32) ?u8 {
    if (x < 0 or x >= width or y < 0 or y >= data.len / width) return null;

    const index = @intCast(usize, y) * width + @intCast(usize, x);
    return switch (data[index]) {
        '0'...'9' => |d| d - '0',
        else => return null,
    };
}

test challenge1 {
    try std.testing.expectEqual(@as(u64, 15), try challenge1(
        \\2199943210
        \\3987894921
        \\9856789892
        \\8767896789
        \\9899965678
        \\
    ));
}

pub fn challenge2(allocator: std.mem.Allocator, data: []const u8) !u64 {
    const index_of_first_newline = std.mem.indexOf(u8, data, "\n") orelse return error.InvalidFormat;
    const width = index_of_first_newline + 1;
    if (data.len % width != 0) {
        std.debug.print("len = {}, width = {}\n", .{ data.len, width });
        return error.InvalidDimensions;
    }
    const height = data.len / width;

    var largest_basins = [3]u64{ 1, 1, 1 };

    var j: i32 = 0;
    while (j < @intCast(i32, height)) : (j += 1) {
        var i: i32 = 0;
        while (i < @intCast(i32, width) - 1) : (i += 1) {
            if (isLowPoint(data, width, i, j)) {
                var basin_size = try basinSize(allocator, data, width, i, j);
                for (largest_basins) |*large_basin| {
                    if (basin_size > large_basin.*) {
                        std.mem.swap(u64, &basin_size, large_basin);
                    }
                }
            }
        }
    }

    return largest_basins[0] * largest_basins[1] * largest_basins[2];
}

pub fn basinSize(allocator: std.mem.Allocator, data: []const u8, width: usize, x: i32, y: i32) !u64 {
    var basin_size: u64 = 1;

    var checked = std.AutoHashMap([2]i32, void).init(allocator);
    defer checked.deinit();
    var to_check = std.ArrayList([2]i32).init(allocator);
    defer to_check.deinit();

    try to_check.append(.{ x, y });
    try checked.put(.{ x, y }, {});
    while (to_check.popOrNull()) |pos| {
        const depth = depthAt(data, width, pos[0], pos[1]).?;

        const OFFSETS = [_][2]i32{
            .{ -1, 0 },
            .{ 1, 0 },
            .{ 0, 1 },
            .{ 0, -1 },
        };
        for (OFFSETS) |offset| {
            const neighbor_pos = .{ pos[0] + offset[0], pos[1] + offset[1] };
            const depth_at_neighbor = depthAt(data, width, neighbor_pos[0], neighbor_pos[1]) orelse continue;
            if (depth_at_neighbor != 9 and depth_at_neighbor >= depth and !checked.contains(neighbor_pos)) {
                basin_size += 1;
                try to_check.append(neighbor_pos);
                try checked.put(neighbor_pos, {});
            }
        }
    }
    return basin_size;
}

test challenge2 {
    try std.testing.expectEqual(@as(u64, 1134), try challenge2(std.testing.allocator,
        \\2199943210
        \\3987894921
        \\9856789892
        \\8767896789
        \\9899965678
        \\
    ));
}
