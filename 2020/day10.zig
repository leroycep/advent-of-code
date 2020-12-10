const std = @import("std");

const INPUT = @embedFile("./day10.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = &gpa.allocator;

    const numbers = try parseIntegerList(allocator, INPUT);
    defer allocator.free(numbers);

    std.sort.sort(u64, numbers, {}, intLessThan);

    var num_1jolt_diffs: usize = 0;
    var num_3jolt_diffs: usize = 1; // starts at 1 because the highest voltage is defined as 4 above highest

    var prev_joltage: u64 = 0;
    for (numbers) |joltage| {
        switch(joltage - prev_joltage) {
            1 => num_1jolt_diffs += 1,
            2 => {},
            3 => num_3jolt_diffs += 1,
            else => return error.UnexpectedJoltDiff,
        }
        prev_joltage = joltage;
    }

    const out = std.io.getStdOut().writer();
    try out.print("Number of 1 jolt differences: {}\n", .{ num_1jolt_diffs });
    try out.print("Number of 3 jolt differences: {}\n", .{ num_3jolt_diffs });
    try out.print("Multiplied: {}\n", .{ num_1jolt_diffs * num_3jolt_diffs });
}

fn intLessThan(context: void, lhs: u64, rhs: u64) bool {
    return lhs < rhs;
}

fn parseIntegerList(allocator: *std.mem.Allocator, text: []const u8) ![]u64 {
    var numbers = std.ArrayList(u64).init(allocator);
    errdefer numbers.deinit();

    var lines_iter = std.mem.tokenize(text, "\n\r ");
    while (lines_iter.next()) |line| {
        try numbers.append(try std.fmt.parseInt(u64, line, 10));
    }

    return numbers.toOwnedSlice();
}
