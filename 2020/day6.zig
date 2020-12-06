const std = @import("std");

fn decodeAnswers(text: []const u8) u26 {
    var answers: u26 = 0;

    const BASE = 'a';
    for (text) |char| {
        if (char < 'a' or char > 'z') continue;
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

const INPUT = @embedFile("./day6.txt");

pub fn main() !void {
    var num_answers: u64 = 0;

    var group_iter = std.mem.split(INPUT, "\n\n");
    while (group_iter.next()) |group| {
        var shared_answers: u26 = std.math.maxInt(u26);

        var num_persons: usize = 0;
        var person_iter = std.mem.tokenize(group, "\n");
        while (person_iter.next()) |person| {
            const answers = decodeAnswers(person);
            shared_answers &= answers;
            num_persons += 1;
        }

        if (num_persons == 0) {
            std.log.debug("Empty group, skipping count", .{});
            continue;
        }

        num_answers += @popCount(u26, shared_answers);
    }

    const out = std.io.getStdOut().writer();
    try out.print("In total, there are {} yes answers\n", .{num_answers});
}
