const std = @import("std");
const util = @import("util");
const glfw = @import("util").glfw;
const gl = @import("util").gl;
const nanovg = @import("util").nanovg;
const Grid = @import("util").Grid;
const ConstGrid = @import("util").ConstGrid;

const DATA = @embedFile("data/day21.txt");

pub fn challenge1(allocator: std.mem.Allocator, input: []const u8) !i64 {
    var monkeys = std.AutoHashMap([4]u8, Node).init(allocator);
    defer monkeys.deinit();

    var line_iter = std.mem.tokenize(u8, input, "\n");
    while (line_iter.next()) |line| {
        const name = line[0..4].*;
        if (line.len < 10) {
            try monkeys.put(name, .{ .literal = try std.fmt.parseInt(i64, line[6..], 10) });
        } else {
            const operands = [2][4]u8{ line[6..10].*, line[13..17].* };
            switch (line[11]) {
                '+' => try monkeys.put(name, .{ .add = operands }),
                '-' => try monkeys.put(name, .{ .sub = operands }),
                '*' => try monkeys.put(name, .{ .mul = operands }),
                '/' => try monkeys.put(name, .{ .div = operands }),
                else => return error.InvalidFormat,
            }
        }
    }

    return getMonkeyNumber(monkeys, "root".*);
}

pub fn getMonkeyNumber(monkeys: std.AutoHashMap([4]u8, Node), monkey_name: [4]u8) !i64 {
    const node = monkeys.get(monkey_name) orelse return error.InvalidMonkey;
    switch (node) {
        .literal => |value| return value,
        .add => |operands| return try getMonkeyNumber(monkeys, operands[0]) + try getMonkeyNumber(monkeys, operands[1]),
        .sub => |operands| return try getMonkeyNumber(monkeys, operands[0]) - try getMonkeyNumber(monkeys, operands[1]),
        .mul => |operands| return try getMonkeyNumber(monkeys, operands[0]) * try getMonkeyNumber(monkeys, operands[1]),
        .div => |operands| return @divFloor(try getMonkeyNumber(monkeys, operands[0]), try getMonkeyNumber(monkeys, operands[1])),
    }
}

const Node = union(enum) {
    literal: i64,
    add: [2][4]u8,
    sub: [2][4]u8,
    mul: [2][4]u8,
    div: [2][4]u8,
};

const TEST_DATA =
    \\root: pppw + sjmn
    \\dbpl: 5
    \\cczh: sllz + lgvd
    \\zczc: 2
    \\ptdq: humn - dvpt
    \\dvpt: 3
    \\lfqf: 4
    \\humn: 5
    \\ljgn: 2
    \\sjmn: drzm * dbpl
    \\sllz: 4
    \\pppw: cczh / lfqf
    \\lgvd: ljgn * ptdq
    \\drzm: hmdt - zczc
    \\hmdt: 32
    \\
;

test "challenge 1" {
    const output = try challenge1(std.testing.allocator, TEST_DATA);
    try std.testing.expectEqual(@as(i64, 152), output);
}

pub fn main() !void {
    const ctx = try util.Context.init(.{ .title = "Advent of Code - Day 21" });
    defer ctx.deinit();

    const stdout = std.io.getStdOut();
    try stdout.writer().print("{}\n", .{try challenge1(ctx.allocator, DATA)});

    while (!ctx.window.shouldClose()) {
        try ctx.beginFrame();
        try ctx.endFrame();
    }

    try ctx.flush();
}
