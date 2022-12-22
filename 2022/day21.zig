const std = @import("std");
const util = @import("util");
const glfw = @import("util").glfw;
const gl = @import("util").gl;
const nanovg = @import("util").nanovg;
const Grid = @import("util").Grid;
const ConstGrid = @import("util").ConstGrid;

const DATA = @embedFile("data/day21.txt");

pub fn challenge1(allocator: std.mem.Allocator, input: []const u8) !i64 {
    var monkeys = try parseMonkeyFile(allocator, input);
    defer monkeys.deinit();

    return getMonkeyNumber(monkeys, "root".*);
}

pub fn challenge2(allocator: std.mem.Allocator, input: []const u8) !i64 {
    var monkeys = try parseMonkeyFile(allocator, input);
    defer monkeys.deinit();

    std.debug.assert(monkeys.swapRemove("humn".*));

    var value_needed: std.math.big.Rational = undefined;
    defer value_needed.deinit();

    try getValueForHuman(allocator, monkeys, "root".*, undefined, &value_needed);
    return @floatToInt(i64, try value_needed.toFloat(f64));
}

pub fn parseMonkeyFile(allocator: std.mem.Allocator, input: []const u8) !std.AutoArrayHashMap([4]u8, Node) {
    var monkeys = std.AutoArrayHashMap([4]u8, Node).init(allocator);
    errdefer monkeys.deinit();

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

    return monkeys;
}

pub fn getMonkeyNumber(monkeys: std.AutoArrayHashMap([4]u8, Node), monkey_name: [4]u8) !i64 {
    const node = monkeys.get(monkey_name) orelse return error.InvalidMonkey;
    switch (node) {
        .literal => |value| return value,
        .add => |operands| return try getMonkeyNumber(monkeys, operands[0]) + try getMonkeyNumber(monkeys, operands[1]),
        .sub => |operands| return try getMonkeyNumber(monkeys, operands[0]) - try getMonkeyNumber(monkeys, operands[1]),
        .mul => |operands| return try getMonkeyNumber(monkeys, operands[0]) * try getMonkeyNumber(monkeys, operands[1]),
        .div => |operands| return @divFloor(try getMonkeyNumber(monkeys, operands[0]), try getMonkeyNumber(monkeys, operands[1])),
    }
}

pub fn getValueForHuman(allocator: std.mem.Allocator, monkeys: std.AutoArrayHashMap([4]u8, Node), monkey_name: [4]u8, expected: std.math.big.Rational, value_needed: *std.math.big.Rational) !void {
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
    const vg = ctx.vg;

    const stdout = std.io.getStdOut();

    const answer1 = try challenge1(ctx.allocator, DATA);
    try stdout.writer().print("{}\n", .{answer1});

    const answer2 = try challenge2(ctx.allocator, DATA);
    try stdout.writer().print("{}\n", .{answer2});

    var monkeys = try parseMonkeyFile(ctx.allocator, DATA);
    defer monkeys.deinit();

    var prng = std.rand.DefaultPrng.init(std.crypto.random.int(u64));

    var particles = try ctx.allocator.alloc(@Vector(2, f32), monkeys.count());
    defer ctx.allocator.free(particles);
    for (particles) |*pos| {
        pos.* = .{
            prng.random().float(f32) * 1024,
            prng.random().float(f32) * 1024,
        };
    }
    layoutParticles(particles, monkeys, "root".*, .{ 0, 0 }, 0, 50, 0);

    var particles_prev = try ctx.allocator.alloc(@Vector(2, f32), monkeys.count());
    defer ctx.allocator.free(particles_prev);

    var camera_pos = @Vector(2, f32){ 0, 0 };
    var prev_camera_pos = @Vector(2, f32){ 0, 0 };
    var drag_start: ?@Vector(2, f32) = @Vector(2, f32){ 0, 0 };
    ctx.window.setInputModeStickyMouseButtons(true) catch {};

    while (!ctx.window.shouldClose()) {
        try ctx.beginFrame();

        blk: {
            switch (ctx.window.getMouseButton(.left)) {
                .press, .repeat => {
                    const mouse_pos_glfw = ctx.window.getCursorPos() catch break :blk;
                    const mouse_pos = @Vector(2, f32){ @floatCast(f32, mouse_pos_glfw.xpos), @floatCast(f32, mouse_pos_glfw.ypos) };
                    if (drag_start) |start_pos| {
                        camera_pos = prev_camera_pos + mouse_pos - start_pos;
                    } else {
                        drag_start = mouse_pos;
                    }
                },
                .release => {
                    drag_start = null;
                    prev_camera_pos = camera_pos;
                },
            }
        }

        const window_size = ctx.window.getSize() catch glfw.Window.Size{ .width = 1024, .height = 1024 };
        vg.translate(camera_pos[0] + @intToFloat(f32, window_size.width) / 2, camera_pos[1] + @intToFloat(f32, window_size.height) / 2);

        var line_height: f32 = undefined;
        ctx.vg.fontFace("sans");
        ctx.vg.textMetrics(null, null, &line_height);

        std.mem.copy(@Vector(2, f32), particles_prev, particles);

        for (particles) |*pos, index| {
            const prev_pos = particles_prev[index];
            for (particles_prev) |other_pos, other_index| {
                if (other_index == index) continue;
                const offset = prev_pos - other_pos;
                if (@reduce(.And, offset == @splat(2, @as(f32, 0)))) continue;
                const distance = @sqrt(@reduce(.Add, offset * offset));
                const normal = offset / @splat(2, distance);
                pos.* += normal * @splat(2, 50 / (distance * distance));
            }
        }

        const root_index = monkeys.getIndex("root".*) orelse return;
        particles[root_index] = .{ 0, 0 };
        constrainParticles(particles, monkeys, "root".*, .{ 0, 0 });

        for (particles) |pos, index| {
            switch (monkeys.values()[index]) {
                .literal => {},
                inline else => |operands| {
                    for (operands) |operand| {
                        const operand_index = monkeys.getIndex(operand) orelse continue;
                        const operand_pos = particles[operand_index];
                        vg.beginPath();
                        vg.moveTo(pos[0], pos[1]);
                        vg.lineTo(operand_pos[0], operand_pos[1]);
                        vg.strokeColor(nanovg.rgba(0xFF, 0xFF, 0xFF, 0xFF));
                        vg.stroke();
                    }
                },
            }
        }

        for (particles) |pos, index| {
            var bounds: [4]f32 = undefined;

            vg.textAlign(.{ .horizontal = .center, .vertical = .middle });
            _ = vg.textBounds(pos[0], pos[1], &monkeys.keys()[index], &bounds);

            // Add padding
            bounds[0] -= 2;
            bounds[1] -= 2;
            bounds[2] += 2;
            bounds[3] += 2;

            vg.beginPath();
            vg.rect(bounds[0], bounds[1], bounds[2] - bounds[0], bounds[3] - bounds[1]);
            vg.fillColor(nanovg.rgba(0xFF, 0xFF, 0xFF, 0xFF));
            vg.fill();

            vg.beginPath();
            vg.fillColor(nanovg.rgba(0x00, 0x00, 0x00, 0xFF));
            vg.textAlign(.{ .horizontal = .center, .vertical = .middle });
            _ = vg.text(pos[0], pos[1], &monkeys.keys()[index]);
        }

        try ctx.endFrame();
    }

    try ctx.flush();
}

fn constrainParticles(particles: []@Vector(2, f32), monkeys: std.AutoArrayHashMap([4]u8, Node), name: [4]u8, root_pos: @Vector(2, f32)) void {
    const node = monkeys.get(name) orelse return;
    const node_index = monkeys.getIndex(name) orelse return;

    const pos = &particles[node_index];

    const offset = pos.* - root_pos;
    const distance = @sqrt(@reduce(.Add, offset * offset));
    if (distance > 0) {
        const normal = offset / @splat(2, distance);
        const ideal_pos = root_pos + normal * @splat(2, @as(f32, 100));

        const towards_ideal_offset = ideal_pos - pos.*;
        const distance_from_ideal = @sqrt(@reduce(.Add, towards_ideal_offset * towards_ideal_offset));
        if (distance_from_ideal > 0) {
            const towards_ideal = towards_ideal_offset / @splat(2, distance_from_ideal);

            const correction = std.math.clamp(distance_from_ideal * distance_from_ideal, 0, distance_from_ideal);

            pos.* += @splat(2, correction) * towards_ideal;
        }
    }

    switch (node) {
        .literal => {},
        inline else => |operands| {
            for (operands) |operand| {
                constrainParticles(particles, monkeys, operand, pos.*);
            }
        },
    }
}

fn layoutParticles(particles: []@Vector(2, f32), monkeys: std.AutoArrayHashMap([4]u8, Node), name: [4]u8, pos: @Vector(2, f32), depth: f32, layer_size: f32, turns: f32) void {
    const node = monkeys.get(name) orelse return;
    const index = monkeys.getIndex(name) orelse return;

    const direction = @Vector(2, f32){
        @cos(std.math.tau * turns),
        @sin(std.math.tau * turns),
    };
    particles[index] = pos + direction * @splat(2, layer_size * depth * depth);

    switch (node) {
        .literal => {},
        inline else => |operands| {
            const turn_amount = 1 / std.math.pow(f32, 2.0, depth + 2);
            layoutParticles(particles, monkeys, operands[0], pos, depth + 1, layer_size, turns + turn_amount);
            layoutParticles(particles, monkeys, operands[1], pos, depth + 1, layer_size, turns - turn_amount);
        },
    }
}
