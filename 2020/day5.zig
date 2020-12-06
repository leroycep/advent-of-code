const std = @import("std");

fn decodePartitionSequence(sequence: []const u8) u10 {
    var seatid: u10 = 0;
    for (sequence[0..7]) |char| {
        seatid <<= 1;
        const bit: u1 = switch (char) {
            'F' => 0,
            'B' => 1,
            else => unreachable,
        };
        seatid |= bit;
    }
    for (sequence[7..]) |char| {
        seatid <<= 1;
        const bit: u1 = switch (char) {
            'L' => 0,
            'R' => 1,
            else => unreachable,
        };
        seatid |= bit;
    }
    return seatid;
}

test "get correct seat id from binary partition sequence" {
    std.testing.expectEqual(@as(u64, 357), decodePartitionSequence("FBFBBFFRLR"));
    std.testing.expectEqual(@as(u64, 567), decodePartitionSequence("BFFFBBFRRR"));
    std.testing.expectEqual(@as(u64, 119), decodePartitionSequence("FFFBBBFRRR"));
    std.testing.expectEqual(@as(u64, 820), decodePartitionSequence("BBFFBBFRLL"));
}

const INPUT = @embedFile("./day5.txt");

pub fn main() !void {
    const out = std.io.getStdOut().writer();

    var highest_seatid: ?u10 = null;

    var line_iter = std.mem.tokenize(INPUT, "\n\r ");
    while (line_iter.next()) |line| {
        const seatid = decodePartitionSequence(line);

        if (highest_seatid) |highest| {
            highest_seatid = std.math.max(seatid, highest);
        } else {
            highest_seatid = seatid;
        }
    }

    try out.print("The highest seatid is {}\n", .{highest_seatid});
}
