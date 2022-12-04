const std = @import("std");

const DATA = @embedFile("data/day04.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(arena.allocator(), DATA)});
    try out.print("{}\n", .{try challenge2(arena.allocator(), DATA)});
}

pub fn challenge1(allocator: std.mem.Allocator, input: []const u8) !i64 {
    _ = allocator;

    var accumulator: i64 = 0;

    var lines_iterator = std.mem.split(u8, input, "\n");
    while (lines_iterator.next()) |line| {
        if (line.len == 0) continue;

        var pair_iterator = std.mem.split(u8, line, ",");
        const pair_assignment_strings = [2][]const u8{
            pair_iterator.next().?,
            pair_iterator.next().?,
        };

        var ranges: [2][2]i64 = undefined;
        for (pair_assignment_strings) |range_string, i| {
            var range_part_iter = std.mem.split(u8, range_string, "-");
            ranges[i][0] = try std.fmt.parseInt(i64, range_part_iter.next().?, 10);
            ranges[i][1] = try std.fmt.parseInt(i64, range_part_iter.next().?, 10);
        }

        accumulator += @boolToInt(contains(ranges[0], ranges[1]) or contains(ranges[1], ranges[0]));
    }

    return accumulator;
}

// If a contains b
fn contains(a: [2]i64, b: [2]i64) bool {
    return a[0] <= b[0] and a[1] >= b[1];
}

test challenge1 {
    const INPUT =
        \\2-4,6-8
        \\2-3,4-5
        \\5-7,7-9
        \\2-8,3-7
        \\6-6,4-6
        \\2-6,4-8
        \\
    ;
    try std.testing.expectEqual(@as(i64, 2), try challenge1(std.testing.allocator, INPUT));
}

pub fn challenge2(allocator: std.mem.Allocator, input: []const u8) !i64 {
    _ = allocator;

    var accumulator: i64 = 0;

    var lines_iterator = std.mem.split(u8, input, "\n");
    while (lines_iterator.next()) |line| {
        if (line.len == 0) continue;

        var pair_iterator = std.mem.split(u8, line, ",");
        const pair_assignment_strings = [2][]const u8{
            pair_iterator.next().?,
            pair_iterator.next().?,
        };

        var ranges: [2][2]i64 = undefined;
        for (pair_assignment_strings) |range_string, i| {
            var range_part_iter = std.mem.split(u8, range_string, "-");
            ranges[i][0] = try std.fmt.parseInt(i64, range_part_iter.next().?, 10);
            ranges[i][1] = try std.fmt.parseInt(i64, range_part_iter.next().?, 10);
        }

        accumulator += @boolToInt(overlaps(ranges[0], ranges[1]) or overlaps(ranges[1], ranges[0]));
    }

    return accumulator;
}

// If a contains b
fn overlaps(a: [2]i64, b: [2]i64) bool {
    return (a[0] <= b[1] and a[1] >= b[0]);
}

test challenge2 {
    const INPUT =
        \\2-4,6-8
        \\2-3,4-5
        \\5-7,7-9
        \\2-8,3-7
        \\6-6,4-6
        \\2-6,4-8
        \\
    ;
    try std.testing.expectEqual(@as(i64, 4), try challenge2(std.testing.allocator, INPUT));
}
