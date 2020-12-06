const std = @import("std");

fn decodeAnswers(text: []const u8) u26 {
    var answers: u26 = 0;

    const BASE = 'a';
    for (text) |char| {
        const offset = @intCast(u5, char - BASE);
        const mask = @as(u26, 1) << offset;
        answers |= mask;
    }

    return answers;
}

test "decode answers" {
    std.testing.expectEqual(@as(u26, 0b1), decodeAnswers("a"));
    std.testing.expectEqual(@as(u26, 0b110), decodeAnswers("bc"));
    std.testing.expectEqual(@as(u26, 0b10000000000000000000000000), decodeAnswers("z"));
}
