const std = @import("std");

const DATA = @embedFile("data/day06.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(arena.allocator(), DATA)});
    // try out.print("{}\n", .{try challenge2(arena.allocator(), DATA)});
}

pub fn challenge1(allocator: std.mem.Allocator, input: []const u8) !usize {
    _ = allocator;

    for (input) |character, index| {
        if (character == '\n') break;
        if (index < 4) continue;
        if (@popCount(as_bit_set(input[index - 4 ..][0..4])) == 4) {
            return index;
        }
    }

    unreachable;
}

pub fn as_bit_set(input: []const u8) u256 {
    var bit_set: u256 = 0;
    for (input) |character| {
        bit_set |= (@as(u256, 1) << character);
    }
    return bit_set;
}

test challenge1 {
    const INPUT =
        \\mjqjpqmgbljsphdztnvjfqwrcgsmlb
        \\
    ;
    const output = try challenge1(std.testing.allocator, INPUT);
    try std.testing.expectEqual(@as(usize, 7), output);
}

test {
    try std.testing.expectEqual(@as(usize, 5), try challenge1(std.testing.allocator, "bvwbjplbgvbhsrlpgdmjqwftvncz"));
    try std.testing.expectEqual(@as(usize, 6), try challenge1(std.testing.allocator, "nppdvjthqldpwncqszvftbrmjlhg"));
    try std.testing.expectEqual(@as(usize, 10), try challenge1(std.testing.allocator, "nznrnfrfntjfmvfwmzdfjlvtqnbhcprsg"));
    try std.testing.expectEqual(@as(usize, 11), try challenge1(std.testing.allocator, "zcfzfwzzqfrljwzlrfnpqdbhtmscgvjw"));
}
