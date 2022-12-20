const std = @import("std");
const glfw = @import("glfw");
const gl = @import("zgl");
const nanovg = @import("nanovg");
const Grid = @import("util").Grid;
const ConstGrid = @import("util").ConstGrid;

const DATA = @embedFile("data/day20.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(arena.allocator(), DATA)});
    try out.print("{}\n", .{try challenge2(arena.allocator(), DATA)});
}

fn challenge1(allocator: std.mem.Allocator, input: []const u8) !i64 {
    var numbers = std.ArrayList(i64).init(allocator);
    defer numbers.deinit();

    var line_iterator = std.mem.tokenize(u8, input, "\n");
    while (line_iterator.next()) |line| {
        try numbers.append(try std.fmt.parseInt(i64, line, 10));
    }
    std.debug.print("number of numbers: {}\n", .{numbers.items.len});

    const next = try allocator.alloc(usize, numbers.items.len);
    defer allocator.free(next);
    const prev = try allocator.alloc(usize, numbers.items.len);
    defer allocator.free(prev);

    for (next) |*next_element, i| {
        next_element.* = (i +% 1) % numbers.items.len;
    }
    for (prev) |*prev_element, i| {
        prev_element.* = (i + numbers.items.len - 1) % numbers.items.len;
    }
    for (numbers.items) |_, initial_index| {
        mix(numbers.items, next, prev, initial_index);
    }

    const index_of_0 = std.mem.indexOfScalar(i64, numbers.items, 0) orelse return error.InvalidFormat;
    const node_1000 = getNthNode(next, prev, index_of_0, 1000);
    const node_2000 = getNthNode(next, prev, index_of_0, 2000);
    const node_3000 = getNthNode(next, prev, index_of_0, 3000);

    return numbers.items[node_1000] + numbers.items[node_2000] + numbers.items[node_3000];
}

fn challenge2(allocator: std.mem.Allocator, input: []const u8) !i64 {
    var numbers = std.ArrayList(i64).init(allocator);
    defer numbers.deinit();

    const decryption_key = 811589153;

    var line_iterator = std.mem.tokenize(u8, input, "\n");
    while (line_iterator.next()) |line| {
        try numbers.append(decryption_key * (try std.fmt.parseInt(i64, line, 10)));
    }
    std.debug.print("number of numbers: {}\n", .{numbers.items.len});

    const next = try allocator.alloc(usize, numbers.items.len);
    defer allocator.free(next);
    const prev = try allocator.alloc(usize, numbers.items.len);
    defer allocator.free(prev);

    for (next) |*next_element, i| {
        next_element.* = (i +% 1) % numbers.items.len;
    }
    for (prev) |*prev_element, i| {
        prev_element.* = (i + numbers.items.len - 1) % numbers.items.len;
    }

    var number_of_times_mixed: usize = 0;
    while (number_of_times_mixed < 10) : (number_of_times_mixed += 1) {
        for (numbers.items) |_, initial_index| {
            mix(numbers.items, next, prev, initial_index);
        }
    }

    const index_of_0 = std.mem.indexOfScalar(i64, numbers.items, 0) orelse return error.InvalidFormat;
    const node_1000 = getNthNode(next, prev, index_of_0, 1000);
    const node_2000 = getNthNode(next, prev, index_of_0, 2000);
    const node_3000 = getNthNode(next, prev, index_of_0, 3000);

    return numbers.items[node_1000] + numbers.items[node_2000] + numbers.items[node_3000];
}

fn mix(values: []const i64, next: []usize, prev: []usize, initial_index: usize) void {
    if (@rem(values[initial_index], @intCast(i64, values.len - 1)) == 0) return;

    const initial_prev = prev[initial_index];
    const initial_next = next[initial_index];

    next[initial_prev] = initial_next;
    prev[initial_next] = initial_prev;

    if (values[initial_index] < 0) {
        var current_index = initial_index;
        var i: i64 = 0;
        while (i > @rem(values[initial_index], @intCast(i64, values.len - 1))) : (i -= 1) {
            current_index = prev[current_index];
        }

        const new_next = current_index;
        const new_prev = prev[new_next];

        prev[new_next] = initial_index;
        next[new_prev] = initial_index;

        prev[initial_index] = new_prev;
        next[initial_index] = new_next;
    } else if (values[initial_index] > 0) {
        var current_index = initial_index;
        var i: i64 = 0;
        while (i < @rem(values[initial_index], @intCast(i64, values.len - 1))) : (i += 1) {
            current_index = next[current_index];
        }

        const new_prev = current_index;
        const new_next = next[new_prev];

        prev[new_next] = initial_index;
        next[new_prev] = initial_index;

        prev[initial_index] = new_prev;
        next[initial_index] = new_next;
    }
}

fn getNthNode(next: []const usize, prev: []const usize, initial_index: usize, n_initial: i64) usize {
    const n = @mod(n_initial, @intCast(i64, next.len));
    std.debug.assert(next.len == prev.len);
    if (n < 0) {
        var current_index = initial_index;
        var i: i64 = 0;
        while (i > n) : (i -= 1) {
            current_index = prev[current_index];
        }
        return current_index;
    } else if (n > 0) {
        var current_index = initial_index;
        var i: i64 = 0;
        while (i < n) : (i += 1) {
            current_index = next[current_index];
        }
        return current_index;
    } else {
        return initial_index;
    }
}

const TEST_DATA =
    \\1
    \\2
    \\-3
    \\3
    \\-2
    \\0
    \\4
    \\
;

test challenge1 {
    const output = try challenge1(std.testing.allocator, TEST_DATA);
    try std.testing.expectEqual(@as(i64, 3), output);
}

test challenge2 {
    const output = try challenge2(std.testing.allocator, TEST_DATA);
    try std.testing.expectEqual(@as(i64, 1623178306), output);
}

test mix {
    const numbers = [_]i64{ 1, 2, -3, 3, -2, 0, 4 };
    var next: [numbers.len]usize = undefined;
    var prev: [numbers.len]usize = undefined;

    for (next) |*next_element, i| {
        next_element.* = (i +% 1) % numbers.len;
    }
    for (prev) |*prev_element, i| {
        prev_element.* = (i + numbers.len - 1) % numbers.len;
    }
    try std.testing.expectEqualSlices(usize, &.{ 1, 2, 3, 4, 5, 6, 0 }, &next);
    try std.testing.expectEqualSlices(usize, &.{ 6, 0, 1, 2, 3, 4, 5 }, &prev);

    mix(&numbers, &next, &prev, 0);
    try std.testing.expectEqualSlices(usize, &.{ 2, 0, 3, 4, 5, 6, 1 }, &next);
    try std.testing.expectEqualSlices(usize, &.{ 1, 6, 0, 2, 3, 4, 5 }, &prev);

    mix(&numbers, &next, &prev, 1);
    try std.testing.expectEqualSlices(usize, &.{ 2, 3, 1, 4, 5, 6, 0 }, &next);
    try std.testing.expectEqualSlices(usize, &.{ 6, 2, 0, 1, 3, 4, 5 }, &prev);

    mix(&numbers, &next, &prev, 2);
    try std.testing.expectEqualSlices(usize, &.{ 1, 3, 5, 4, 2, 6, 0 }, &next);
    try std.testing.expectEqualSlices(usize, &.{ 6, 0, 4, 1, 3, 2, 5 }, &prev);

    mix(&numbers, &next, &prev, 3);
    try std.testing.expectEqualSlices(usize, &.{ 1, 4, 5, 6, 2, 3, 0 }, &next);
    try std.testing.expectEqualSlices(usize, &.{ 6, 0, 4, 5, 1, 2, 3 }, &prev);

    mix(&numbers, &next, &prev, 4);
    try std.testing.expectEqualSlices(usize, &.{ 1, 2, 5, 6, 0, 3, 4 }, &next);
    try std.testing.expectEqualSlices(usize, &.{ 4, 0, 1, 5, 6, 2, 3 }, &prev);

    mix(&numbers, &next, &prev, 5);
    try std.testing.expectEqualSlices(usize, &.{ 1, 2, 5, 6, 0, 3, 4 }, &next);
    try std.testing.expectEqualSlices(usize, &.{ 4, 0, 1, 5, 6, 2, 3 }, &prev);

    mix(&numbers, &next, &prev, 6);
    try std.testing.expectEqualSlices(usize, &.{ 1, 2, 6, 4, 0, 3, 5 }, &next);
    try std.testing.expectEqualSlices(usize, &.{ 4, 0, 1, 5, 3, 6, 2 }, &prev);
}

test getNthNode {
    const next = [_]usize{ 1, 2, 6, 4, 0, 3, 5 };
    const prev = [_]usize{ 4, 0, 1, 5, 3, 6, 2 };

    try std.testing.expectEqual(@as(usize, 6), getNthNode(&next, &prev, 5, 1000));
    try std.testing.expectEqual(@as(usize, 2), getNthNode(&next, &prev, 5, 2000));
    try std.testing.expectEqual(@as(usize, 1), getNthNode(&next, &prev, 5, 3000));
}
