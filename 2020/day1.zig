const std = @import("std");

const CHALLENGE1 = @embedFile("./challenge1.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = &gpa.allocator;

    const challenge1_input = try textLinesToIntList(allocator, CHALLENGE1);
    defer allocator.free(challenge1_input);

    const entries = try findEntriesThatSumTo(allocator, challenge1_input, 2020);
    const numbers = [_]u32{
        challenge1_input[entries[0]],
        challenge1_input[entries[1]],
    };

    std.log.info("Entries {} and {} sum to 2020: {} + {}", .{ entries[0], entries[1], numbers[0], numbers[1] });
    std.log.info("Multiplied, the give: {} * {} = {}", .{ numbers[0], numbers[1], numbers[0] * numbers[1] });
}

fn textLinesToIntList(allocator: *std.mem.Allocator, text: []const u8) ![]u32 {
    var numbers = std.ArrayList(u32).init(allocator);
    errdefer numbers.deinit();

    var line_iter = std.mem.tokenize(text, "\n\r");
    while (line_iter.next()) |line| {
        const num = try std.fmt.parseInt(u32, line, 10);
        try numbers.append(num);
    }

    return numbers.toOwnedSlice();
}

fn findEntriesThatSumTo(allocator: *std.mem.Allocator, numbers: []const u32, value: u32) ![2]usize {
    var seen = std.AutoHashMap(u32, usize).init(allocator);
    defer seen.deinit();
    
    for (numbers) |num, idx| {
        const complement = value - num;
        if (seen.get(complement)) |complement_idx| {
            return [2]usize{complement_idx, idx};
        }
        try seen.put(num, idx);
    }
    
    return error.EntriesNotFound;
}
