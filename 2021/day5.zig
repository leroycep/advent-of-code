const std = @import("std");

const DATA = @embedFile("./data/day5.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(arena.allocator(), DATA)});
}

pub fn challenge1(allocator: std.mem.Allocator, data: []const u8) !u64 {
    var lines = std.ArrayList([2][2]i64).init(allocator);
    defer lines.deinit();

    var max_point = [2]i64{ 0, 0 };
    var line_iter = std.mem.tokenize(u8, data, "\n\r");
    while (line_iter.next()) |line_text| {
        const line = try parseLine(line_text);

        if (isDiagonal(line[0], line[1]))
            continue;

        for (line) |point| {
            max_point[0] = std.math.max(max_point[0], point[0]);
            max_point[1] = std.math.max(max_point[1], point[1]);
        }

        try lines.append(line);
    }

    const size = [2]i64{ max_point[0] + 1, max_point[1] + 1 };
    const grid = try allocator.alloc(u8, @intCast(usize, size[0] * size[1]));
    defer allocator.free(grid);
    std.mem.set(u8, grid, 0);

    for (lines.items) |line| {
        std.debug.assert(!isDiagonal(line[0], line[1]));
        const end = line[1];
        var p = line[0];

        const step = lineToDir(p, end);

        while (true) {
            const i = pointToIdx(size[0], p);

            grid[i] +|= 1;

            if (std.meta.eql(p, end))
                break;

            p[0] += step[0];
            p[1] += step[1];
        }
    }

    var num_intersections: u64 = 0;
    for (grid) |cell| {
        if (cell >= 2) {
            num_intersections += 1;
        }
    }

    return num_intersections;
}

pub fn parseLine(line_text: []const u8) ![2][2]i64 {
    var point_iter = std.mem.tokenize(u8, line_text, " ->");

    const point_text = [2][]const u8{
        point_iter.next() orelse return error.InvalidFormat,
        point_iter.next() orelse return error.InvalidFormat,
    };

    var points: [2][2]i64 = undefined;
    for (point_text) |t, i| {
        points[i] = try parsePoint(t);
    }

    std.debug.assert(point_iter.next() == null);
    return points;
}

fn parsePoint(point_text: []const u8) ![2]i64 {
    var num_iter = std.mem.tokenize(u8, point_text, ",");

    const num_text = [2][]const u8{
        num_iter.next() orelse return error.InvalidFormat,
        num_iter.next() orelse return error.InvalidFormat,
    };

    var nums: [2]i64 = undefined;
    for (num_text) |t, i| {
        nums[i] = try std.fmt.parseInt(i64, t, 10);
    }

    return nums;
}

test "parse line" {
    try std.testing.expectEqual([2][2]i64{ .{ 0, 9 }, .{ 5, 9 } }, try parseLine("0,9 -> 5,9"));
}

pub fn isDiagonal(a: [2]i64, b: [2]i64) bool {
    return !(a[0] == b[0] or a[1] == b[1]);
}

test "is diagonal" {
    try std.testing.expect(!isDiagonal(.{ 0, 9 }, .{ 5, 9 }));
    try std.testing.expect(isDiagonal(.{ 8, 0 }, .{ 0, 8 }));
}

pub fn pointToIdx(width: i64, a: [2]i64) usize {
    if (width <= 0) return 0;
    return @intCast(usize, a[1] * width + a[0]);
}

test "point to index" {
    try std.testing.expectEqual(@as(usize, 95), pointToIdx(10, .{ 5, 9 }));
}

pub fn lineToDir(start: [2]i64, end: [2]i64) [2]i64 {
    return .{
        numToDir(end[0] - start[0]),
        numToDir(end[1] - start[1]),
    };
}

fn numToDir(num: i64) i64 {
    if (num == 0) {
        return 0;
    } else if (num < 0) {
        return -1;
    } else {
        return 1;
    }
}

test "points to dir" {
    try std.testing.expectEqual(@as(usize, 95), pointToIdx(10, .{ 5, 9 }));
}

const TEST_CASE =
    \\0,9 -> 5,9
    \\8,0 -> 0,8
    \\9,4 -> 3,4
    \\2,2 -> 2,1
    \\7,0 -> 7,4
    \\6,4 -> 2,0
    \\0,9 -> 2,9
    \\3,4 -> 1,4
    \\0,0 -> 8,8
    \\5,5 -> 8,2
;

test "challenge1" {
    try std.testing.expectEqual(@as(u64, 5), try challenge1(std.testing.allocator, TEST_CASE));
}
