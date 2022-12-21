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

pub fn challenge2(allocator: std.mem.Allocator, input: []const u8) !i64 {
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

    std.debug.assert(monkeys.remove("humn".*));

    var value_needed: std.math.big.Rational = undefined;
    defer value_needed.deinit();

    try getValueForHuman(allocator, monkeys, "root".*, undefined, &value_needed);
    return @floatToInt(i64, try value_needed.toFloat(f64));
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

pub fn getValueForHuman(allocator: std.mem.Allocator, monkeys: std.AutoHashMap([4]u8, Node), monkey_name: [4]u8, expected: std.math.big.Rational, value_needed: *std.math.big.Rational) !void {
    if (std.mem.eql(u8, &monkey_name, "humn")) {
        value_needed.p = try expected.p.clone();
        value_needed.q = try expected.q.clone();
        return;
    }

    const node = monkeys.get(monkey_name) orelse return error.Invalid;

    if (std.mem.eql(u8, &monkey_name, "root")) {
        const left = getMonkeyNumber(monkeys, node.add[0]) catch null;
        const right = getMonkeyNumber(monkeys, node.add[1]) catch null;

        var sub_expected = try std.math.big.Rational.init(allocator);
        defer sub_expected.deinit();

        if (left) |l| {
            try sub_expected.setInt(l);
            try getValueForHuman(allocator, monkeys, node.add[1], sub_expected, value_needed);
        } else if (right) |r| {
            try sub_expected.setInt(r);
            try getValueForHuman(allocator, monkeys, node.add[0], sub_expected, value_needed);
        }
        return;
    }

    var sub_monkey: [4]u8 = undefined;

    var sub_expected = try std.math.big.Rational.init(allocator);
    defer sub_expected.deinit();

    switch (node) {
        .literal => return,
        .add => |operands| {
            const left = getMonkeyNumber(monkeys, operands[0]) catch null;
            const right = getMonkeyNumber(monkeys, operands[1]) catch null;
            if (left) |l| {
                sub_monkey = operands[1];
                try sub_expected.setInt(l);
            } else if (right) |r| {
                sub_monkey = operands[0];
                try sub_expected.setInt(r);
            } else {
                return;
            }
            try sub_expected.sub(expected, sub_expected);
        },
        .mul => |operands| {
            const left = getMonkeyNumber(monkeys, operands[0]) catch null;
            const right = getMonkeyNumber(monkeys, operands[1]) catch null;

            var other_value = try std.math.big.Rational.init(allocator);
            defer other_value.deinit();

            if (left) |l| {
                sub_monkey = operands[1];
                try other_value.setInt(l);
            } else if (right) |r| {
                sub_monkey = operands[0];
                try other_value.setInt(r);
            } else {
                return;
            }
            try sub_expected.div(expected, other_value);
        },
        .sub => |operands| {
            const left = getMonkeyNumber(monkeys, operands[0]) catch null;
            const right = getMonkeyNumber(monkeys, operands[1]) catch null;
            if (left) |l| {
                sub_monkey = operands[1];
                try sub_expected.setInt(l);
                try sub_expected.sub(sub_expected, expected);
            } else if (right) |r| {
                sub_monkey = operands[0];
                try sub_expected.setInt(r);
                try sub_expected.add(expected, sub_expected);
            } else {
                return;
            }
        },
        .div => |operands| {
            const left = getMonkeyNumber(monkeys, operands[0]) catch null;
            const right = getMonkeyNumber(monkeys, operands[1]) catch null;
            if (left) |l| {
                sub_monkey = operands[1];
                try sub_expected.setInt(l);
                try sub_expected.div(sub_expected, expected);
            } else if (right) |r| {
                sub_monkey = operands[0];
                try sub_expected.setInt(r);
                try sub_expected.mul(expected, sub_expected);
            } else {
                return;
            }
        },
    }

    try getValueForHuman(allocator, monkeys, sub_monkey, sub_expected, value_needed);
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

test "challenge 2" {
    const output = try challenge2(std.testing.allocator, TEST_DATA);
    try std.testing.expectEqual(@as(i64, 301), output);
}

pub fn main() !void {
    const ctx = try util.Context.init(.{ .title = "Advent of Code - Day 21" });
    defer ctx.deinit();

    const stdout = std.io.getStdOut();

    const answer1 = try challenge1(ctx.allocator, DATA);
    try stdout.writer().print("{}\n", .{answer1});

    const answer2 = try challenge2(ctx.allocator, DATA);
    try stdout.writer().print("{}\n", .{answer2});

    while (!ctx.window.shouldClose()) {
        try ctx.beginFrame();

        var buf: [200]u8 = undefined;
        const string = try std.fmt.bufPrint(&buf, "challenge 1 answer = {}\nchallenge 2 answer = {}", .{ answer1, answer2 });

        var line_height: f32 = undefined;
        ctx.vg.fontFace("sans");
        ctx.vg.textMetrics(null, null, &line_height);

        var lines = std.mem.split(u8, string, "\n");
        var y: f32 = 512;
        while (lines.next()) |line| : (y += line_height) {
            ctx.vg.beginPath();
            ctx.vg.fillColor(nanovg.rgba(0xFF, 0xFF, 0xFF, 0xFF));
            ctx.vg.textAlign(.{ .horizontal = .center, .vertical = .middle });
            _ = ctx.vg.text(512, y, line);
        }

        try ctx.endFrame();
    }

    try ctx.flush();
}
