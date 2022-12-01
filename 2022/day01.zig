const std = @import("std");

const DATA = @embedFile("data/day01.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(arena.allocator(), DATA)});
    // try out.print("{}\n", .{challenge2(.{ 48, -189 }, .{ 70, -148 })});
}

pub fn challenge1(allocator: std.mem.Allocator, input: []const u8) !i64 {
    _ = allocator;

    var max_number_of_calories: i64 = 0;
    var number_of_calories: i64 = 0;
    var lines = std.mem.split(u8, input, "\n");
    while (lines.next()) |line| {
        if (line.len == 0) {
            max_number_of_calories = std.math.max(number_of_calories, max_number_of_calories);
            number_of_calories = 0;
            continue;
        }
        number_of_calories += try std.fmt.parseInt(i64, line, 10);
    }
    max_number_of_calories = std.math.max(number_of_calories, max_number_of_calories);

    return max_number_of_calories;
}

test challenge1 {
    const INPUT =
        \\1000
        \\2000
        \\3000
        \\
        \\4000
        \\
        \\5000
        \\6000
        \\
        \\7000
        \\8000
        \\9000
        \\
        \\10000
        \\
    ;
    try std.testing.expectEqual(@as(i64, 24000), try challenge1(std.testing.allocator, INPUT));
}
