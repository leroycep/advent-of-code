const std = @import("std");

const DATA = @embedFile("./data/day3.txt");

pub fn main() !void {
    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(DATA)});
}

pub fn challenge1(data: []const u8) !i64 {
    const N = std.meta.bitCount(i64);
    var num_of_zeroes = [_]i64{0} ** N;
    var num_of_ones = [_]i64{0} ** N;
    var len_of_line: ?usize = null;

    var line_iter = std.mem.tokenize(u8, data, "\n\r");
    while (line_iter.next()) |line| {
        if (len_of_line) |prev_len_of_line| {
            std.debug.assert(prev_len_of_line == line.len);
        } else {
            len_of_line = line.len;
        }

        //const number = try std.fmt.parseInt(i64, line, 2);
        for (line) |c, i| {
            switch (c) {
                '0' => num_of_zeroes[i] += 1,
                '1' => num_of_ones[i] += 1,
                else => unreachable,
            }
        }
    }

    var gamma: i64 = 0;
    var epsilon: i64 = 0;
    for (num_of_zeroes[0..len_of_line.?]) |ctz, i| {
        gamma <<= 1;
        epsilon <<= 1;
        if (num_of_ones[i] >= ctz) {
            gamma |= 1;
        } else {
            epsilon |= 1;
        }
    }

    std.log.debug("", .{});
    std.log.debug("ctz {any}", .{num_of_zeroes[0..len_of_line.?]});
    std.log.debug("cto {any}", .{num_of_ones[0..len_of_line.?]});
    std.log.debug("", .{});
    std.log.debug("gamma   {b: >12} {}", .{ gamma, gamma });
    std.log.debug("epsilon {b: >12} {}", .{ epsilon, epsilon });

    return gamma * epsilon;
}

test "" {
    try std.testing.expectEqual(@as(i64, 198), try challenge1(
        \\00100
        \\11110
        \\10110
        \\10111
        \\10101
        \\01111
        \\00111
        \\11100
        \\10000
        \\11001
        \\00010
        \\01010
    ));
}
