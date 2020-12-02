const std = @import("std");

const CHALLENGE1 = @embedFile("./day2-challenge1.txt");

pub fn main() !void {
    var number_of_valid_passwords: usize = 0;
    var number_of_valid_toboggan_passwords: usize = 0;
    var number_of_passwords: usize = 0;

    var line_number: usize = 0;
    var line_iter = std.mem.tokenize(CHALLENGE1, "\n\r");
    while (line_iter.next()) |line| : (line_number += 1) {
        var entry_iter = std.mem.split(line, ":");

        const rule_text = entry_iter.next() orelse {
            std.log.warn("Line {} is empty", .{line_number});
            continue;
        };
        const password = std.mem.trim(u8, entry_iter.rest(), " \n\r");

        const rule = Rule.parse(rule_text) catch |e| {
            std.log.warn("Couldn't parse rule \"{}\" on line {}: {}", .{ rule_text, line_number, e });
            continue;
        };

        number_of_passwords += 1;
        if (rule.verifyPassword(password)) {
            number_of_valid_passwords += 1;
        }
        if (rule.verifyTobogganPassword(password)) {
            number_of_valid_toboggan_passwords += 1;
        }
    }

    std.log.info("{} out of {} passwords were valid", .{ number_of_valid_passwords, number_of_passwords });
    std.log.info("{} out of {} passwords were valid toboggan passwords", .{ number_of_valid_toboggan_passwords, number_of_passwords });

    const stdout = std.io.getStdOut().writer();
    try stdout.print("{}\n", .{number_of_valid_passwords});
    try stdout.print("{}\n", .{number_of_valid_toboggan_passwords});
}

const Rule = struct {
    // The character that has it number of appearances restricted
    char: u8,

    // The minimum number of appearances
    min: usize,

    // The maximum number of appearances
    max: usize,

    pub fn init(char: u8, min: usize, max: usize) @This() {
        return @This(){
            .char = char,
            .min = min,
            .max = max,
        };
    }

    pub fn parse(text: []const u8) !@This() {
        var token_iter = std.mem.tokenize(text, "- ");

        const min_text = token_iter.next() orelse return error.InvalidFormat;
        const max_text = token_iter.next() orelse return error.InvalidFormat;
        const char_text = token_iter.rest();

        if (char_text.len < 1) {
            return error.InvalidFormat;
        }

        const min = try std.fmt.parseInt(usize, min_text, 10);
        const max = try std.fmt.parseInt(usize, max_text, 10);

        return @This(){
            .char = char_text[0],
            .min = min,
            .max = max,
        };
    }

    pub fn verifyPassword(this: @This(), password: []const u8) bool {
        var appearances: usize = 0;
        for (password) |char| {
            if (char == this.char) {
                appearances += 1;
            }
        }
        return this.min <= appearances and appearances <= this.max;
    }

    pub fn verifyTobogganPassword(this: @This(), password: []const u8) bool {
        var appearances: usize = 0;
        if (this.min > 0 and this.min - 1 < password.len and password[this.min - 1] == this.char) appearances += 1;
        if (this.max > 0 and this.max - 1 < password.len and password[this.max - 1] == this.char) appearances += 1;
        return appearances == 1;
    }
};

test "verify password" {
    std.testing.expectEqual(true, Rule.init('a', 1, 3).verifyPassword("abcde"));
    std.testing.expectEqual(false, Rule.init('b', 1, 3).verifyPassword("cdefg"));
    std.testing.expectEqual(true, Rule.init('c', 2, 9).verifyPassword("ccccccccc"));
}

test "verify toboggan password" {
    std.testing.expectEqual(true, Rule.init('a', 1, 3).verifyTobogganPassword("abcde"));
    std.testing.expectEqual(false, Rule.init('b', 1, 3).verifyTobogganPassword("cdefg"));
    std.testing.expectEqual(false, Rule.init('c', 2, 9).verifyTobogganPassword("ccccccccc"));
}

test "parse rule" {
    std.testing.expectEqual(Rule.init('a', 1, 3), try Rule.parse("1-3 a"));
    std.testing.expectEqual(Rule.init('b', 1, 3), try Rule.parse("1-3 b"));
    std.testing.expectEqual(Rule.init('c', 2, 9), try Rule.parse("2-9 c"));
}
