const std = @import("std");

const DATA = @embedFile("./data/day9.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(DATA)});
    // try out.print("{}\n", .{try challenge2(arena.allocator(), DATA)});
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
