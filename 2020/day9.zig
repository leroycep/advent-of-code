const std = @import("std");

fn parseIntegerList(allocator: *std.mem.Allocator, text: []const u8) ![]u64 {
    var numbers = std.ArrayList(u64).init(allocator);
    errdefer numbers.deinit();

    var lines_iter = std.mem.tokenize(text, "\n\r ");
    while (lines_iter.next()) |line| {
        try numbers.append(try std.fmt.parseInt(u64, line, 10));
    }

    return numbers.toOwnedSlice();
}

fn isSumOfAny(allocator: *std.mem.Allocator, numberList: []const u64, total: u64) !bool {
    var seen = std.AutoHashMap(u64, usize).init(allocator);
    defer seen.deinit();

    for (numberList) |number, idx| {
        const complement = total -% number;
        if (seen.get(complement)) |_complement_idx| {
            return true;
        }
        try seen.put(number, idx);
    }
    return false;
}

fn findFirstInvalidXMAS(allocator: *std.mem.Allocator, numbers: []const u64, windowSize: usize) !?usize {
    var i: usize = windowSize;
    while (i < numbers.len) : (i += 1) {
        const window = numbers[i - windowSize .. i];
        const total = numbers[i];
        if (!(try isSumOfAny(allocator, window, total))) {
            return i;
        }
    }
    return null;
}

fn getEncryptionWeakness(numbers: []const u64, numberToSumTo: u64) ?u64 {
    if (numberToSumTo == 0) return null;

    var total: u64 = 0;
    var start: usize = 0;
    var end: usize = 0;
    while (true) {
        if (total < numberToSumTo) {
            if (end + 1 > numbers.len) return null;
            total += numbers[end];
            end += 1;
        } else if (total > numberToSumTo) {
            total -= numbers[start];
            start += 1;
        } else {
            std.log.warn("numbers: {} {}", .{ numbers[start], numbers[end - 1] });
            var smallest: u64 = std.math.maxInt(u64);
            var largest: u64 = 0;
            for (numbers[start..end]) |value| {
                smallest = std.math.min(smallest, value);
                largest = std.math.max(largest, value);
            }
            return smallest + largest;
        }
    }
    return null;
}

test "xmas sliding window of 5" {
    const input =
        \\35
        \\20
        \\15
        \\25
        \\47
        \\40
        \\62
        \\55
        \\65
        \\95
        \\102
        \\117
        \\150
        \\182
        \\127
        \\219
        \\299
        \\277
        \\309
        \\576
    ;

    const numbers = try parseIntegerList(std.testing.allocator, input);
    defer std.testing.allocator.free(numbers);

    const first_invalid = try findFirstInvalidXMAS(std.testing.allocator, numbers, 5);

    std.testing.expectEqual(@as(?usize, 14), first_invalid);

    const encryption_weakness = getEncryptionWeakness(numbers, numbers[first_invalid.?]);
    std.testing.expectEqual(@as(usize, 62), encryption_weakness.?);
}

const INPUT = @embedFile("./day9.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = &gpa.allocator;

    const numbers = try parseIntegerList(allocator, INPUT);
    defer allocator.free(numbers);

    const first_invalid_idx = try findFirstInvalidXMAS(std.testing.allocator, numbers, 25);
    const first_invalid = numbers[first_invalid_idx.?];
    const encryption_weakness = getEncryptionWeakness(numbers, first_invalid);

    const out = std.io.getStdOut().writer();
    try out.print("First invalid number at {} is {}\n", .{ first_invalid_idx, first_invalid });
    try out.print("Encryption weakness is {}\n", .{ encryption_weakness });
}
