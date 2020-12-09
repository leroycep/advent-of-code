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
        const window = numbers[i - windowSize..i];
        const total = numbers[i];
        if(!(try isSumOfAny(allocator, window, total))) {
            return i;
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
}
