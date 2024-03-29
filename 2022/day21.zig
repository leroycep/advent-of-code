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

    // Check if any nodes are referenced multiple times
    {
        const times_referenced = try ctx.allocator.alloc(f32, monkeys.count());
        defer ctx.allocator.free(times_referenced);
        std.mem.set(f32, times_referenced, 0);
        for (monkeys.values()) |node| {
            switch (node) {
                .literal => {},
                inline else => |operands| {
                    for (operands) |operand| {
                        const operand_index = monkeys.getIndex(operand) orelse continue;
                        times_referenced[operand_index] += 1;
                    }
                },
            }
        }
        for (times_referenced) |num_times_referenced, i| {
            if (num_times_referenced == 1) continue;
            std.debug.print("{s} referenced {} times\n", .{ monkeys.keys()[i], num_times_referenced });
        }
    }

    const particles = try ctx.allocator.alloc(@Vector(2, f32), monkeys.count());
    defer ctx.allocator.free(particles);
    std.mem.set(@Vector(2, f32), particles, .{ 0, 0 });

    const monkeys_depth = try ctx.allocator.alloc(f32, monkeys.count());
    defer ctx.allocator.free(monkeys_depth);
    std.mem.set(f32, monkeys_depth, 0);
    calculateDepths(monkeys_depth, monkeys, "root".*, 0);
    const max_depth = std.mem.max(f32, monkeys_depth);

    const node_space = 20;

    const elements_per_depth = try calculateElementsPerDepth(ctx.allocator, monkeys_depth);
    defer ctx.allocator.free(elements_per_depth);

    layoutParticles(particles, elements_per_depth, node_space, monkeys, "root".*, .{ 0, 0 }, 0, 0, 0, 1);

    var particles_prev = try ctx.allocator.alloc(@Vector(2, f32), monkeys.count());
    defer ctx.allocator.free(particles_prev);

    var camera_pos = @Vector(2, f32){ 0, 0 };
    var prev_camera_pos = @Vector(2, f32){ 0, 0 };
    var drag_start: ?@Vector(2, f32) = @Vector(2, f32){ 0, 0 };
    ctx.window.setInputModeStickyMouseButtons(true);

    var path = std.ArrayList(usize).init(ctx.allocator);
    defer path.deinit();
    try path.append(monkeys.getIndex("root".*).?);

    var text_buffer = std.ArrayList(u8).init(ctx.allocator);
    defer text_buffer.deinit();

    var depth_added: f32 = 1;

    while (!ctx.window.shouldClose()) {
        try ctx.beginFrame();

        switch (ctx.window.getMouseButton(.left)) {
            .press, .repeat => {
                const mouse_pos_glfw = ctx.window.getCursorPos();
                const mouse_pos = @Vector(2, f32){ @floatCast(f32, mouse_pos_glfw.xpos), @floatCast(f32, mouse_pos_glfw.ypos) };
                if (drag_start) |start_pos| {
                    camera_pos = prev_camera_pos + start_pos - mouse_pos;
                } else {
                    drag_start = mouse_pos;
                }
            },
            .release => {
                drag_start = null;
                prev_camera_pos = camera_pos;
            },
        }

        const current_node = path.items[path.items.len - 1];
        switch (ctx.window.getKey(.left)) {
            .press => {
                switch (monkeys.values()[current_node]) {
                    .literal => {},
                    inline else => |operands| {
                        const next_node = monkeys.getIndex(operands[0]).?;
                        try path.append(next_node);
                        camera_pos = particles[next_node];
                    },
                }
            },
            else => {},
        }
        switch (ctx.window.getKey(.right)) {
            .press => {
                switch (monkeys.values()[current_node]) {
                    .literal => {},
                    inline else => |operands| {
                        const next_node = monkeys.getIndex(operands[1]).?;
                        try path.append(next_node);
                        camera_pos = particles[next_node];
                    },
                }
            },
            else => {},
        }
        switch (ctx.window.getKey(.up)) {
            .press => if (path.items.len > 1) {
                _ = path.pop();
                camera_pos = particles[path.items[path.items.len - 1]];
            } else {
                camera_pos = particles[path.items[0]];
            },
            else => {},
        }

        // Move to node with greatest depth
        if (ctx.window.getKey(.t) == .press) {
            const max_depth_monkey = std.mem.indexOfMax(f32, monkeys_depth);
            const max_depth_monkey_name = monkeys.keys()[max_depth_monkey];

            path.shrinkRetainingCapacity(0);
            _ = try pathTo(monkeys, "root".*, max_depth_monkey_name, &path);
            camera_pos = particles[path.items[path.items.len - 1]];
        }

        const window_size = ctx.window.getSize();
        vg.translate(@intToFloat(f32, window_size.width) / 2 - camera_pos[0], @intToFloat(f32, window_size.height) / 2 - camera_pos[1]);

        var line_height: f32 = undefined;
        ctx.vg.fontFace("sans");
        ctx.vg.textMetrics(null, null, &line_height);

        std.mem.copy(@Vector(2, f32), particles_prev, particles);

        // put root at center
        const root_index = monkeys.getIndex("root".*) orelse return;
        particles[root_index] = .{ 0, 0 };

        // Pull all particles toward the center
        // const GRAVITY = 1.0;
        // for (particles) |*pos| {
        //     if (@reduce(.And, pos.* == @splat(2, @as(f32, 0)))) continue;
        //     const distance = @sqrt(@reduce(.Add, pos.* * pos.*));
        //     const normal = pos.* / @splat(2, distance);
        //     pos.* += normal * -@splat(2, @as(f32, GRAVITY));
        // }

        const BINDING_FORCE = 1.0 / 2.0;
        const REST_LENGTH = 2 * node_space;
        for (particles) |pos, index| {
            if (monkeys_depth[index] > depth_added) continue;

            const node = monkeys.get(monkeys.keys()[index]) orelse continue;
            switch (node) {
                .literal => {},
                inline else => |operands| {
                    for (operands) |operand| {
                        const operand_index = monkeys.getIndex(operand) orelse continue;
                        const operand_pos = &particles[operand_index];
                        if (monkeys_depth[operand_index] > depth_added) continue;

                        const offset = pos - operand_pos.*;
                        if (@reduce(.And, offset == @splat(2, @as(f32, 0)))) continue;
                        const distance = @sqrt(@reduce(.Add, offset * offset));
                        const normal = offset / @splat(2, distance);

                        const diff = distance - REST_LENGTH;
                        if (diff <= 0) continue;

                        operand_pos.* += normal * @splat(2, @sqrt(@fabs(diff)) * BINDING_FORCE);
                    }
                },
            }
        }

        const REPULSIVE_FORCE = 1000;
        for (particles) |*pos, index| {
            if (monkeys_depth[index] > depth_added) continue;

            const prev_pos = particles_prev[index];
            for (particles_prev) |other_pos, other_index| {
                if (other_index == index) continue;
                if (monkeys_depth[other_index] > depth_added) continue;

                const offset = prev_pos - other_pos;
                if (@reduce(.And, offset == @splat(2, @as(f32, 0)))) continue;
                const distance = @sqrt(@reduce(.Add, offset * offset));
                const normal = offset / @splat(2, distance);
                pos.* += normal * @splat(2, REPULSIVE_FORCE / (distance * distance));
            }
        }

        const LAYERING_FORCE = 1.0 / 10.0;
        for (particles) |*pos, index| {
            if (monkeys_depth[index] > depth_added) continue;

            const offset = pos.*;
            if (@reduce(.And, offset == @splat(2, @as(f32, 0)))) continue;
            const distance = @sqrt(@reduce(.Add, offset * offset));
            const normal = offset / @splat(2, distance);

            const diff = (monkeys_depth[index] * 2 * node_space) - distance;
            if (diff <= 0) continue;

            pos.* += normal * @splat(2, @sqrt(@fabs(diff)) * LAYERING_FORCE);
        }

        const previous_depth_added = depth_added;
        depth_added += 0.01;

        for (particles) |pos, index| {
            if (monkeys_depth[index] + 1 > depth_added or monkeys_depth[index] + 1 < previous_depth_added) continue;

            const distance = @sqrt(@reduce(.Add, pos * pos));
            const outward_normal = pos / @splat(2, distance);
            const sideways_normal = @Vector(2, f32){ outward_normal[1], -outward_normal[0] };

            const outwards = outward_normal * @splat(2, @as(f32, distance + node_space));
            const sideways = sideways_normal * @splat(2, @as(f32, node_space));

            const node = monkeys.get(monkeys.keys()[index]) orelse continue;
            switch (node) {
                .literal => {},
                inline else => |operands| {
                    const left = &particles[monkeys.getIndex(operands[0]) orelse continue];
                    const right = &particles[monkeys.getIndex(operands[1]) orelse continue];

                    left.* = outwards - sideways;
                    right.* = outwards + sideways;
                },
            }
        }

        for (particles) |pos, index| {
            if (monkeys_depth[index] + 1 > depth_added) continue;
            const node = monkeys.get(monkeys.keys()[index]) orelse continue;
            switch (node) {
                .literal => {},
                inline else => |operands| {
                    for (operands) |operand| {
                        const operand_index = monkeys.getIndex(operand) orelse continue;
                        const operand_pos = particles[operand_index];
                        vg.beginPath();
                        vg.moveTo(pos[0], pos[1]);
                        vg.lineTo(operand_pos[0], operand_pos[1]);
                        if (std.mem.indexOfScalar(usize, path.items, operand_index)) |_| {
                            vg.strokeColor(nanovg.rgba(0x00, 0xFF, 0x00, 0xFF));
                        } else {
                            vg.strokeColor(nanovg.rgba(0xFF, 0xFF, 0xFF, 0xFF));
                        }
                        vg.stroke();
                    }
                },
            }
        }

        for (particles) |pos, index| {
            if (monkeys_depth[index] > depth_added) continue;
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
            if (std.mem.indexOfScalar(usize, path.items, index)) |_| {
                vg.fillColor(nanovg.rgba(0x00, 0xFF, 0x00, 0xFF));
            } else {
                vg.fillColor(nanovg.rgba(0xFF, 0xFF, 0xFF, 0xFF));
            }
            vg.fill();

            vg.beginPath();
            vg.fillColor(nanovg.rgba(0x00, 0x00, 0x00, 0xFF));
            vg.textAlign(.{ .horizontal = .center, .vertical = .middle });
            _ = vg.text(pos[0], pos[1], &monkeys.keys()[index]);
        }

        vg.resetTransform();

        text_buffer.shrinkRetainingCapacity(0);
        try text_buffer.writer().print(
            \\camera = {d}
            \\monkey = {}/{}
            \\depth = {d}/{d}
            \\path = 
        , .{ camera_pos, path.items[path.items.len - 1], monkeys.count(), monkeys_depth[path.items[path.items.len - 1]], max_depth });
        for (path.items) |monkey_index, path_index| {
            if (path_index > 0) try text_buffer.writer().writeAll(" -> ");
            try text_buffer.writer().writeAll(&monkeys.keys()[monkey_index]);
        }

        vg.beginPath();
        vg.fillColor(nanovg.rgba(0xFF, 0xFF, 0xFF, 0xFF));
        vg.textAlign(.{ .horizontal = .left, .vertical = .top });
        _ = vg.textBox(0, 0, 512, text_buffer.items);

        try ctx.endFrame();
    }

    try ctx.flush();
}

fn calculateDepths(monkeys_depth: []f32, monkeys: std.AutoArrayHashMap([4]u8, Node), name: [4]u8, depth: f32) void {
    const index = monkeys.getIndex(name) orelse return;
    monkeys_depth[index] = depth;

    const node = monkeys.get(name) orelse return;
    switch (node) {
        .literal => {},
        inline else => |operands| {
            calculateDepths(monkeys_depth, monkeys, operands[0], depth + 1);
            calculateDepths(monkeys_depth, monkeys, operands[1], depth + 1);
        },
    }
}

fn calculateElementsPerDepth(allocator: std.mem.Allocator, monkey_depths: []const f32) ![]usize {
    const number_of_circles = @floatToInt(usize, std.mem.max(f32, monkey_depths) + 1);

    const elements_per_depth = try allocator.alloc(usize, number_of_circles);
    errdefer allocator.free(elements_per_depth);
    std.mem.set(usize, elements_per_depth, 0);

    for (monkey_depths) |depth| {
        const depth_usize = @floatToInt(usize, depth);
        elements_per_depth[depth_usize] += 1;
    }

    return elements_per_depth;
}

fn sizeOfTree(monkeys: std.AutoArrayHashMap([4]u8, Node), name: [4]u8) usize {
    const node = monkeys.get(name) orelse return 0;
    switch (node) {
        .literal => return 1,
        inline else => |operands| {
            return 1 + sizeOfTree(monkeys, operands[0]) + sizeOfTree(monkeys, operands[1]);
        },
    }
}

fn layoutParticles(particles: []@Vector(2, f32), elements_per_depth: []usize, node_space: f32, monkeys: std.AutoArrayHashMap([4]u8, Node), name: [4]u8, pos: @Vector(2, f32), depth: usize, prev_radius: f32, min_turn: f32, max_turn: f32) void {
    const index = monkeys.getIndex(name) orelse return;

    const turn = (min_turn + max_turn) / 2;
    const circle_circumference = @intToFloat(f32, elements_per_depth[depth]) * node_space;
    const circle_radius = @max(prev_radius + 2 * node_space, circle_circumference / std.math.pi);

    const direction = @Vector(2, f32){
        @cos(std.math.tau * turn),
        @sin(std.math.tau * turn),
    };
    particles[index] = pos + direction * @splat(2, circle_radius);

    const node = monkeys.get(name) orelse return;
    switch (node) {
        .literal => {},
        inline else => |operands| {
            const elements_to_left = @intToFloat(f32, sizeOfTree(monkeys, operands[0]));
            const elements_to_right = @intToFloat(f32, sizeOfTree(monkeys, operands[1]));
            const ratio = elements_to_left / (elements_to_left + elements_to_right);
            const midpoint = min_turn + (max_turn - min_turn) * ratio;
            layoutParticles(particles, elements_per_depth, node_space, monkeys, operands[0], pos, depth + 1, circle_radius, min_turn, midpoint);
            layoutParticles(particles, elements_per_depth, node_space, monkeys, operands[1], pos, depth + 1, circle_radius, midpoint, max_turn);
        },
    }
}

fn pathTo(monkeys: std.AutoArrayHashMap([4]u8, Node), start_name: [4]u8, dest_name: [4]u8, path_out: *std.ArrayList(usize)) !bool {
    if (std.mem.eql(u8, &start_name, &dest_name)) {
        try path_out.append(monkeys.getIndex(start_name) orelse return error.UnknownMonkey);
        return true;
    }

    const path_len = path_out.items.len;
    try path_out.append(monkeys.getIndex(start_name) orelse return error.UnknownMonkey);

    const node = monkeys.get(start_name) orelse return error.UnknownMonkey;
    switch (node) {
        .literal => {},
        inline else => |operands| {
            for (operands) |operand| {
                if (try pathTo(monkeys, operand, dest_name, path_out)) {
                    return true;
                }
            }
        },
    }

    path_out.shrinkRetainingCapacity(path_len);

    return false;
}
