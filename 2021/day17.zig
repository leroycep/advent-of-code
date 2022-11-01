const std = @import("std");

const DATA = "target area: x=48..70, y=-189..-148";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(arena.allocator(), .{ 48, -189 }, .{ 70, -148 })});
    try out.print("{}\n", .{challenge2(.{ 48, -189 }, .{ 70, -148 })});
}

const GRAVITY = [2]i64{ 0, -1 };

pub fn challenge1(allocator: std.mem.Allocator, min: [2]i64, max: [2]i64) !i64 {
    _ = allocator;

    var max_y: i64 = std.math.minInt(i64);

    var y: i64 = -1000;
    while (y <= 1000) : (y += 1) {
        var x: i64 = -1000;
        while (x <= 1000) : (x += 1) {
            const velocity = .{ x, y };
            if (passesThroughArea(velocity, min, max)) |result| {
                max_y = std.math.max(max_y, result.max_y);
                std.debug.print("velocity {} passes through area on step {}\n", .{ velocity, result.step });
            }
        }
    }

    return max_y;
}

const PassesThroughAreaResult = struct {
    step: u32,
    max_y: i64,
};

fn passesThroughArea(initial_velocity: [2]i64, min: [2]i64, max: [2]i64) ?PassesThroughAreaResult {
    var pos: @Vector(2, i64) = initial_velocity;
    var prev_pos = @Vector(2, i64){ 0, 0 };

    var max_y = prev_pos[1];
    var step: u32 = 1;
    while (true) : (step += 1) {
        max_y = std.math.max(pos[1], max_y);
        if (@reduce(.And, min <= pos) and @reduce(.And, pos <= max)) {
            std.debug.print("step {}, pos = {}\n", .{ step, pos });
            return PassesThroughAreaResult{
                .step = step,
                .max_y = max_y,
            };
        }
        const velocity = pos - prev_pos;
        if (velocity[1] < 0 and pos[1] < min[1]) {
            return null;
        }
        if (velocity[0] >= 0 and pos[0] > max[0]) {
            return null;
        }
        if (velocity[0] <= 0 and pos[0] < min[0]) {
            return null;
        }

        prev_pos = pos;

        pos += velocity;
        pos += GRAVITY;
        // Apply drag
        if (velocity[0] > 0) {
            pos[0] -= 1;
        } else if (velocity[0] < 0) {
            pos[0] += 1;
        }
    }
}

test challenge1 {
    try std.testing.expectEqual(@as(i64, 45), try challenge1(std.testing.allocator, .{ 20, -10 }, .{ 30, -5 }));
}

test passesThroughArea {
    var res = passesThroughArea(.{ 6, 9 }, .{ 20, -10 }, .{ 30, -5 }) orelse return error.ExpectedSome;
    try std.testing.expectEqual(@as(u32, 20), res.step);
    try std.testing.expectEqual(@as(i64, 45), res.max_y);
}

pub fn challenge2(min: [2]i64, max: [2]i64) u64 {
    var number_of_velocities: u64 = 0;

    var y: i64 = -1000;
    while (y <= 1000) : (y += 1) {
        var x: i64 = -1000;
        while (x <= 1000) : (x += 1) {
            const velocity = .{ x, y };
            if (passesThroughArea(velocity, min, max)) |result| {
                _ = result;
                number_of_velocities += 1;
            }
        }
    }

    return number_of_velocities;
}

test challenge2 {
    try std.testing.expectEqual(@as(u64, 112), challenge2(.{ 20, -10 }, .{ 30, -5 }));
}
