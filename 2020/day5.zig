const std = @import("std");

const FIRST_ROW = 0;
const LAST_ROW = 127;
const FIRST_COL = 0;
const LAST_COL = 7;

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
