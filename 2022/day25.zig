const std = @import("std");
const util = @import("util");
const glfw = @import("util").glfw;
const gl = @import("util").gl;
const nanovg = @import("util").nanovg;
const Grid = @import("util").Grid;
const ConstGrid = @import("util").ConstGrid;

const DATA = @embedFile("data/day25.txt");

pub fn challenge1(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var total: i64 = 0;

    var lines = std.mem.tokenize(u8, input, "\n");
    while (lines.next()) |line| {
        const number = try parseSNAFU(line);
        total += number;
    }

    return try writeSNAFUAlloc(allocator, total);
}

const TEST_DATA =
    \\1=-0-2
    \\12111
    \\2=0=
    \\21
    \\2=01
    \\111
    \\20012
    \\112
    \\1=-1=
    \\1-12
    \\12
    \\1=
    \\122
    \\
;

test challenge1 {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectEqualStrings("2=-1=0", try challenge1(arena.allocator(), TEST_DATA));
}

pub fn parseSNAFU(input: []const u8) !i64 {
    var result: i64 = 0;
    for (input) |character| {
        result *= 5;
        result += switch (character) {
            '2' => 2,
            '1' => 1,
            '0' => 0,
            '-' => -1,
            '=' => -2,
            else => return error.InvalidFormat,
        };
    }
    return result;
}

test parseSNAFU {
    try std.testing.expectEqual(@as(i64, 1), try parseSNAFU("1"));
    try std.testing.expectEqual(@as(i64, 2), try parseSNAFU("2"));
    try std.testing.expectEqual(@as(i64, 3), try parseSNAFU("1="));
    try std.testing.expectEqual(@as(i64, 4), try parseSNAFU("1-"));
    try std.testing.expectEqual(@as(i64, 5), try parseSNAFU("10"));
    try std.testing.expectEqual(@as(i64, 6), try parseSNAFU("11"));
    try std.testing.expectEqual(@as(i64, 7), try parseSNAFU("12"));
    try std.testing.expectEqual(@as(i64, 8), try parseSNAFU("2="));
    try std.testing.expectEqual(@as(i64, 9), try parseSNAFU("2-"));
    try std.testing.expectEqual(@as(i64, 10), try parseSNAFU("20"));
    try std.testing.expectEqual(@as(i64, 15), try parseSNAFU("1=0"));
    try std.testing.expectEqual(@as(i64, 20), try parseSNAFU("1-0"));
    try std.testing.expectEqual(@as(i64, 2022), try parseSNAFU("1=11-2"));
    try std.testing.expectEqual(@as(i64, 12345), try parseSNAFU("1-0---0"));
    try std.testing.expectEqual(@as(i64, 314159265), try parseSNAFU("1121-1110-1=0"));
}

pub fn writeSNAFUAlloc(allocator: std.mem.Allocator, input_value: i64) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();
    var value = input_value;
    while (value > 0) {
        switch (@mod(value, 5)) {
            0 => try result.append('0'),
            1 => try result.append('1'),
            2 => try result.append('2'),
            3 => try result.append('='),
            4 => try result.append('-'),
            else => unreachable,
        }
        switch (@mod(value, 5)) {
            0 => value -= 0,
            1 => value -= 1,
            2 => value -= 2,
            3 => value += 2,
            4 => value += 1,
            else => unreachable,
        }
        value = @divFloor(value, 5);
    }
    const slice = try result.toOwnedSlice();
    std.mem.reverse(u8, slice);
    return slice;
}

test writeSNAFUAlloc {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectEqualStrings("1", try writeSNAFUAlloc(arena.allocator(), 1));
    try std.testing.expectEqualStrings("2", try writeSNAFUAlloc(arena.allocator(), 2));
    try std.testing.expectEqualStrings("1=", try writeSNAFUAlloc(arena.allocator(), 3));
    try std.testing.expectEqualStrings("1-", try writeSNAFUAlloc(arena.allocator(), 4));
    try std.testing.expectEqualStrings("10", try writeSNAFUAlloc(arena.allocator(), 5));
    try std.testing.expectEqualStrings("11", try writeSNAFUAlloc(arena.allocator(), 6));
    try std.testing.expectEqualStrings("12", try writeSNAFUAlloc(arena.allocator(), 7));
    try std.testing.expectEqualStrings("2=", try writeSNAFUAlloc(arena.allocator(), 8));
    try std.testing.expectEqualStrings("2-", try writeSNAFUAlloc(arena.allocator(), 9));
    try std.testing.expectEqualStrings("20", try writeSNAFUAlloc(arena.allocator(), 10));
    try std.testing.expectEqualStrings("1=0", try writeSNAFUAlloc(arena.allocator(), 15));
    try std.testing.expectEqualStrings("1-0", try writeSNAFUAlloc(arena.allocator(), 20));
    try std.testing.expectEqualStrings("1=11-2", try writeSNAFUAlloc(arena.allocator(), 2022));
    try std.testing.expectEqualStrings("1-0---0", try writeSNAFUAlloc(arena.allocator(), 12345));
    try std.testing.expectEqualStrings("1121-1110-1=0", try writeSNAFUAlloc(arena.allocator(), 314159265));
}

pub fn main() !void {
    const ctx = try util.Context.init(.{ .title = @src().file });
    defer ctx.deinit();

    const stdout = std.io.getStdOut();

    const answer1 = try challenge1(ctx.allocator, DATA);
    defer ctx.allocator.free(answer1);
    try stdout.writer().print("{s}\n", .{answer1});

    // const answer2 = try challenge2(ctx.allocator, DATA);
    // try stdout.writer().print("{}\n", .{answer2});

    while (!ctx.window.shouldClose()) {
        try ctx.beginFrame();

        try ctx.endFrame();
    }

    try ctx.flush();
}
