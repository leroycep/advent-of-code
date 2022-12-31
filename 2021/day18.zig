const std = @import("std");

const Digit = enum(u5) {
    pair = std.math.maxInt(u5),
    _,
};

pub fn main() void {}

fn snailfish(comptime list: anytype) []const Digit {
    comptime var result: [list.len]Digit = undefined;
    inline for (list) |item, index| {
        switch (@TypeOf(item)) {
            comptime_int => result[index] = @intToEnum(Digit, item),
            @Type(.EnumLiteral) => result[index] = item,
            else => unreachable,
        }
    }
    return result[0..];
}

fn parse(allocator: std.mem.Allocator, text: []const u8) ![]Digit {
    var digits = std.ArrayList(Digit).init(allocator);
    defer digits.deinit();
    for (text) |c| {
        switch (c) {
            '[' => try digits.append(.pair),
            '0'...'9' => try digits.append(@intToEnum(Digit, c - '0')),
            ',', ']' => {},
            else => return error.InvalidFormat,
        }
    }
    return digits.toOwnedSlice();
}

test parse {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    try std.testing.expectEqualSlices(Digit, snailfish(.{ .pair, 1, 2 }), try parse(alloc, "[1,2]"));
    try std.testing.expectEqualSlices(Digit, snailfish(.{ .pair, .pair, 1, 2, 3 }), try parse(alloc, "[[1,2],3]"));
    try std.testing.expectEqualSlices(Digit, snailfish(.{ .pair, 9, .pair, 8, 7 }), try parse(alloc, "[9,[8,7]]"));
    try std.testing.expectEqualSlices(Digit, snailfish(.{ .pair, .pair, 1, 9, .pair, 8, 5 }), try parse(alloc, "[[1,9],[8,5]]"));
    try std.testing.expectEqualSlices(Digit, snailfish(.{
        .pair,
        .pair,
        .pair,
        .pair,
        1,
        2,
        .pair,
        3,
        4,
        .pair,
        .pair,
        5,
        6,
        .pair,
        7,
        8,
        9,
    }), try parse(alloc, "[[[[1,2],[3,4]],[[5,6],[7,8]]],9]"));
    try std.testing.expectEqualSlices(Digit, snailfish(.{
        .pair,
        .pair,
        .pair,
        9,
        .pair,
        3,
        8,
        .pair,
        .pair,
        0,
        9,
        6,
        .pair,
        .pair,
        .pair,
        3,
        7,
        .pair,
        4,
        9,
        3,
    }), try parse(alloc, "[[[9,[3,8]],[[0,9],6]],[[[3,7],[4,9]],3]]"));
    try std.testing.expectEqualSlices(Digit, snailfish(.{
        .pair,
        .pair,
        .pair,
        .pair,
        1,
        3,
        .pair,
        5,
        3,
        .pair,
        .pair,
        1,
        3,
        .pair,
        8,
        7,
        .pair,
        .pair,
        .pair,
        4,
        9,
        .pair,
        6,
        9,
        .pair,
        .pair,
        8,
        2,
        .pair,
        7,
        3,
    }), try parse(alloc, "[[[[1,3],[5,3]],[[1,3],[8,7]]],[[[4,9],[6,9]],[[8,2],[7,3]]]]"));
}

pub fn parseList(allocator: std.mem.Allocator, text: []const u8) ![][]Digit {
    var list = std.ArrayList([]Digit).init(allocator);
    defer {
        for (list.items) |digits| {
            allocator.free(digits);
        }
        list.deinit();
    }
    var lines = std.mem.tokenize(u8, text, "\n");
    while (lines.next()) |line| {
        const digits = try parse(allocator, line);
        try list.append(digits);
    }
    return list.toOwnedSlice();
}

pub fn parseListFree(allocator: std.mem.Allocator, list: [][]Digit) void {
    for (list) |digits| {
        allocator.free(digits);
    }
    allocator.free(list);
}

test parseList {
    const parsed = try parseList(std.testing.allocator, TEST_DATA);
    defer parseListFree(std.testing.allocator, parsed);
    try std.testing.expectEqualSlices(
        Digit,
        snailfish(.{ .pair, .pair, .pair, 0, .pair, 5, 8, .pair, .pair, 1, 7, .pair, 9, 6, .pair, .pair, 4, .pair, 1, 2, .pair, .pair, 1, 4, 2 }),
        parsed[0],
    );

    try std.testing.expectEqualSlices(
        Digit,
        snailfish(.{ .pair, .pair, .pair, 5, .pair, 2, 8, 4, .pair, 5, .pair, .pair, 9, 9, 0 }),
        parsed[1],
    );
}

pub fn add(allocator: std.mem.Allocator, left: []const Digit, right: []const Digit) ![]Digit {
    var digits = std.ArrayList(Digit).init(allocator);
    defer digits.deinit();

    try digits.append(.pair);
    try digits.appendSlice(left);
    try digits.appendSlice(right);

    return digits.toOwnedSlice();
}

test add {
    const left = snailfish(.{ .pair, 1, 2 });
    const right = snailfish(.{ .pair, .pair, 3, 4, 5 });
    const expected = snailfish(.{ .pair, .pair, 1, 2, .pair, .pair, 3, 4, 5 });

    const result = try add(std.testing.allocator, left, right);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualSlices(Digit, expected, result);
}

fn snailfishDigitSlices(list: []const Digit) [2][]const Digit {
    var elements_remaining: usize = 1;
    for (list[1..]) |element, element_index| {
        switch (element) {
            .pair => elements_remaining += 1,
            else => elements_remaining -|= 1,
        }
        if (elements_remaining == 0) {
            return .{
                list[1 .. element_index + 2],
                list[element_index + 2 ..],
            };
        }
    }
    std.debug.panic("invalid snailfish number: {any}, elements remaining: {}\n", .{ list, elements_remaining });
}

fn expectDigitSlices(expected: [2][]const Digit, actual: [2][]const Digit) !void {
    try std.testing.expectEqualSlices(Digit, expected[0], actual[0]);
    try std.testing.expectEqualSlices(Digit, expected[1], actual[1]);
}

test snailfishDigitSlices {
    try expectDigitSlices(
        .{
            snailfish(.{ .pair, 9, 1 }),
            snailfish(.{ .pair, 1, 9 }),
        },
        snailfishDigitSlices(snailfish(.{ .pair, .pair, 9, 1, .pair, 1, 9 })),
    );
    try expectDigitSlices(
        .{
            snailfish(.{ .pair, .pair, 0, .pair, 5, 8, .pair, .pair, 1, 7, .pair, 9, 6 }),
            snailfish(.{ .pair, .pair, 4, .pair, 1, 2, .pair, .pair, 1, 4, 2 }),
        },
        snailfishDigitSlices(
            snailfish(.{ .pair, .pair, .pair, 0, .pair, 5, 8, .pair, .pair, 1, 7, .pair, 9, 6, .pair, .pair, 4, .pair, 1, 2, .pair, .pair, 1, 4, 2 }),
        ),
    );
}

fn snailfishDigitMagnitude(list: []const Digit) u64 {
    switch (list[0]) {
        .pair => {
            const parts = snailfishDigitSlices(list);
            const left_magnitude = snailfishDigitMagnitude(parts[0]);
            const right_magnitude = snailfishDigitMagnitude(parts[1]);
            return 3 * left_magnitude + 2 * right_magnitude;
        },
        else => |n| return @enumToInt(n),
    }
}

test snailfishDigitMagnitude {
    try std.testing.expectEqual(@as(u64, 29), snailfishDigitMagnitude(snailfish(.{ .pair, 9, 1 })));
    try std.testing.expectEqual(@as(u64, 21), snailfishDigitMagnitude(snailfish(.{ .pair, 1, 9 })));
    try std.testing.expectEqual(@as(u64, 129), snailfishDigitMagnitude(snailfish(.{ .pair, .pair, 9, 1, .pair, 1, 9 })));
}

pub fn challenge1(allocator: std.mem.Allocator, input: []const u8) !u64 {
    var sum_of_magnitudes: u64 = 0;

    var lines_iter = std.mem.tokenize(u8, input, "\n");
    while (lines_iter.next()) |line| {
        const list = try parse(allocator, line);
        defer allocator.free(list);

        sum_of_magnitudes += snailfishDigitMagnitude(list);
    }

    return sum_of_magnitudes;
}

const TEST_DATA =
    \\[[[0,[5,8]],[[1,7],[9,6]]],[[4,[1,2]],[[1,4],2]]]
    \\[[[5,[2,8]],4],[5,[[9,9],0]]]
    \\[6,[[[6,2],[5,6]],[[7,6],[4,7]]]]
    \\[[[6,[0,7]],[0,9]],[4,[9,[9,0]]]]
    \\[[[7,[6,4]],[3,[1,3]]],[[[5,5],1],9]]
    \\[[6,[[7,3],[3,2]]],[[[3,8],[5,7]],4]]
    \\[[[[5,4],[7,7]],8],[[8,3],8]]
    \\[[9,3],[[9,9],[6,[4,9]]]]
    \\[[2,[[7,7],7]],[[5,8],[[9,3],[0,2]]]]
    \\[[[[5,2],5],[8,[3,7]]],[[5,[7,5]],[4,4]]]
    \\
;

test "challenge 1" {
    try std.testing.expectEqual(@as(u64, 4140), try challenge1(std.testing.allocator, TEST_DATA));
}
