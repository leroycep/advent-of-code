const std = @import("std");

const DATA = @embedFile("data/day09.txt");

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
    var tiles_visited = std.AutoHashMap([2]i64, void).init(allocator);
    defer tiles_visited.deinit();

    var head_pos = @Vector(2, i64){ 0, 0 };
    var tail_pos = @Vector(2, i64){ 0, 0 };

    var max_pos = @Vector(2, i64){ 0, 0 };
    var min_pos = @Vector(2, i64){ 0, 0 };

    var lines_iterator = std.mem.split(u8, input, "\n");
    while (lines_iterator.next()) |line| {
        if (line.len == 0) continue;
        var word_iterator = std.mem.split(u8, line, " ");
        const direction_string = word_iterator.next().?;
        const amount_string = word_iterator.next().?;

        const amount = try std.fmt.parseInt(i64, amount_string, 10);

        const direction = switch (direction_string[0]) {
            'U' => [2]i64{ 0, -1 },
            'R' => [2]i64{ 1, 0 },
            'D' => [2]i64{ 0, 1 },
            'L' => [2]i64{ -1, 0 },
            else => return error.InvalidFormat,
        };

        var i: i64 = 0;
        while (i < amount) : (i += 1) {
            head_pos += direction;

            if (distance(head_pos, tail_pos) > 1) {
                tail_pos += std.math.sign(head_pos - tail_pos);
            }

            try tiles_visited.put(tail_pos, {});

            max_pos[0] = std.math.max(max_pos[0], head_pos[0]);
            max_pos[1] = std.math.max(max_pos[1], head_pos[1]);
            min_pos[0] = std.math.min(min_pos[0], head_pos[0]);
            min_pos[1] = std.math.min(min_pos[1], head_pos[1]);
        }
    }

    dump(tiles_visited, min_pos, max_pos, tail_pos, head_pos);

    return tiles_visited.count();
}

fn distance(a: [2]i64, b: [2]i64) i64 {
    return std.math.max(std.math.absInt(b[0] - a[0]) catch unreachable, std.math.absInt(b[1] - a[1]) catch unreachable);
}

fn dump(tiles_visited: std.AutoHashMap([2]i64, void), min_pos: @Vector(2, i64), max_pos: @Vector(2, i64), tail_pos: @Vector(2, i64), head_pos: @Vector(2, i64)) void {
    std.debug.print("\n", .{});
    std.debug.print("count = {}\n", .{tiles_visited.count()});
    std.debug.print("min_pos = {any}\n", .{min_pos});
    std.debug.print("max_pos = {any}\n", .{max_pos});
    std.debug.print("head_pos = {any}\n", .{head_pos});
    std.debug.print("tail_pos = {any}\n", .{tail_pos});
    var print_pos = min_pos;
    while (print_pos[1] <= max_pos[1]) : (print_pos[1] += 1) {
        print_pos[0] = min_pos[0];
        while (print_pos[0] <= max_pos[0]) : (print_pos[0] += 1) {
            if (@reduce(.And, print_pos == head_pos)) {
                std.debug.print("H", .{});
            } else if (@reduce(.And, print_pos == tail_pos)) {
                std.debug.print("T", .{});
            } else if (tiles_visited.contains(print_pos)) {
                std.debug.print("#", .{});
            } else {
                std.debug.print(".", .{});
            }
        }
        std.debug.print("\n", .{});
    }
}

const TEST_INPUT =
    \\R 4
    \\U 4
    \\L 3
    \\D 1
    \\R 4
    \\D 1
    \\L 5
    \\R 2
    \\
;

test challenge1 {
    const output = try challenge1(std.testing.allocator, TEST_INPUT);
    try std.testing.expectEqual(@as(i64, 13), output);
}

pub fn challenge2(allocator: std.mem.Allocator, input: []const u8) !i64 {
    var tiles_visited = std.AutoHashMap([2]i64, void).init(allocator);
    defer tiles_visited.deinit();

    var knot_positions: [10][2]i64 = [_][2]i64{.{ 0, 0 }} ** 10;

    var lines_iterator = std.mem.split(u8, input, "\n");
    while (lines_iterator.next()) |line| {
        if (line.len == 0) continue;
        var word_iterator = std.mem.split(u8, line, " ");
        const direction_string = word_iterator.next().?;
        const amount_string = word_iterator.next().?;

        const amount = try std.fmt.parseInt(i64, amount_string, 10);

        const direction = switch (direction_string[0]) {
            'U' => @Vector(2, i64){ 0, -1 },
            'R' => @Vector(2, i64){ 1, 0 },
            'D' => @Vector(2, i64){ 0, 1 },
            'L' => @Vector(2, i64){ -1, 0 },
            else => return error.InvalidFormat,
        };

        var i: i64 = 0;
        while (i < amount) : (i += 1) {
            knot_positions[0] = direction + knot_positions[0];

            for (knot_positions[1..]) |*position, index| {
                const leading_knot = knot_positions[index];
                if (distance(leading_knot, position.*) > 1) {
                    position.* = position.* + std.math.sign(@as(@Vector(2, i64), leading_knot) - position.*);
                }
            }

            try tiles_visited.put(knot_positions[knot_positions.len - 1], {});
        }
    }

    dump2(tiles_visited, &knot_positions);

    return tiles_visited.count();
}

fn dump2(tiles_visited: std.AutoHashMap([2]i64, void), knots: []const [2]i64) void {
    var max_pos = @Vector(2, i64){ 0, 0 };
    var min_pos = @Vector(2, i64){ 0, 0 };
    var iterator = tiles_visited.keyIterator();
    while (iterator.next()) |pos| {
        min_pos = @min(min_pos, @as(@Vector(2, i64), pos.*));
        max_pos = @max(max_pos, @as(@Vector(2, i64), pos.*));
    }
    for (knots) |pos| {
        min_pos = @min(min_pos, @as(@Vector(2, i64), pos));
        max_pos = @max(max_pos, @as(@Vector(2, i64), pos));
    }
    std.debug.print("\n", .{});
    std.debug.print("count = {}\n", .{tiles_visited.count()});
    std.debug.print("min_pos = {any}\n", .{min_pos});
    std.debug.print("max_pos = {any}\n", .{max_pos});
    var print_pos = min_pos;
    while (print_pos[1] <= max_pos[1]) : (print_pos[1] += 1) {
        print_pos[0] = min_pos[0];
        while (print_pos[0] <= max_pos[0]) : (print_pos[0] += 1) {
            for (knots) |knot_pos, knot_index| {
                if (@reduce(.And, print_pos == knot_pos)) {
                    std.debug.print("{}", .{knot_index});
                    break;
                }
            } else if (tiles_visited.contains(print_pos)) {
                std.debug.print("#", .{});
            } else {
                std.debug.print(".", .{});
            }
        }
        std.debug.print("\n", .{});
    }
}

test "challenge 2 with initial data" {
    const output = try challenge2(std.testing.allocator, TEST_INPUT);
    try std.testing.expectEqual(@as(i64, 1), output);
}

test challenge2 {
    const output = try challenge2(std.testing.allocator,
        \\R 5
        \\U 8
        \\L 8
        \\D 3
        \\R 17
        \\D 10
        \\L 25
        \\U 20
        \\
    );
    try std.testing.expectEqual(@as(i64, 36), output);
}
