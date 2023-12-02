const std = @import("std");

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = general_purpose_allocator.deinit();
    const gpa = general_purpose_allocator.allocator();

    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    const input_filepath = args[1];

    std.debug.print("Reading input data from {s}\n", .{input_filepath});

    const cwd = std.fs.cwd();
    const input = try cwd.readFileAlloc(gpa, input_filepath, 5 * 1024 * 1024);
    defer gpa.free(input);

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("part 1 solution = {}\n", .{calibrationSum(input)});
    try stdout.print("part 2 solution = {}\n", .{try wordyCalibrationSum(gpa, input)});

    try bw.flush(); // don't forget to flush!
}

pub fn calibrationSum(text: []const u8) i64 {
    var sum: i64 = 0;

    var line_iter = std.mem.splitAny(u8, text, "\n");
    while (line_iter.next()) |line| {
        const first_digit = std.mem.indexOfAny(u8, line, "0123456789") orelse continue;
        const last_digit = std.mem.lastIndexOfAny(u8, line, "0123456789") orelse continue;

        sum += @as(i64, line[first_digit] - '0') * 10 + @as(i64, line[last_digit] - '0');
    }

    return sum;
}

test calibrationSum {
    const input =
        \\1abc2
        \\pqr3stu8vwx
        \\a1b2c3d4e5f
        \\treb7uchet
    ;
    try std.testing.expectEqual(@as(i64, 142), calibrationSum(input));
}

pub fn wordyCalibrationSum(gpa: std.mem.Allocator, text: []const u8) !i64 {
    var sum: i64 = 0;

    var digits = std.ArrayList(u8).init(gpa);
    defer digits.deinit();

    var line_iter = std.mem.splitAny(u8, text, "\n");
    while (line_iter.next()) |line| {
        digits.shrinkRetainingCapacity(0);

        try parseWordyDigits(line, &digits);

        if (digits.items.len == 0) continue;

        const first_digit = digits.items[0];
        const last_digit = digits.items[digits.items.len - 1];

        // std.debug.print("{s} => {}, {}\n", .{ line, first_digit, last_digit });

        sum += @as(i64, first_digit) * 10 + @as(i64, last_digit);
    }

    return sum;
}

pub fn parseWordyDigits(line: []const u8, digits: *std.ArrayList(u8)) !void {
    const digit_words = [_][]const u8{
        "zero",
        "one",
        "two",
        "three",
        "four",
        "five",
        "six",
        "seven",
        "eight",
        "nine",
    };
    var index: usize = 0;
    while (index < line.len) {
        if (std.ascii.isDigit(line[index])) {
            try digits.append(line[index] - '0');
            index += 1;
            continue;
        }
        for (digit_words, 0..) |digit_word, i| {
            if (std.mem.startsWith(u8, line[index..], digit_word)) {
                // Only increment by one because the digit words can overlap
                index += 1;
                try digits.append(@intCast(i));
                break;
            }
        } else {
            index += 1;
        }
    }
}

test wordyCalibrationSum {
    const input =
        \\two1nine
        \\eightwothree
        \\abcone2threexyz
        \\xtwone3four
        \\4nineeightseven2
        \\zoneight234
        \\7pqrstsixteen
    ;
    try std.testing.expectEqual(@as(i64, 281), try wordyCalibrationSum(std.testing.allocator, input));
}

test "overlapping words" {
    try std.testing.expectEqual(@as(i64, 88), try wordyCalibrationSum(std.testing.allocator, "8kgplfhvtvqpfsblddnineoneighthg"));
}
