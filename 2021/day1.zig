const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(&gpa.allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const contents = try std.fs.cwd().readFileAlloc(allocator, "day1.txt", 400_000);

    var numbers = std.ArrayList(u32).init(allocator);
    var line_iter = std.mem.tokenize(u8, contents, " \n\r");
    while (line_iter.next()) |line| {
        const number = try std.fmt.parseUnsigned(u32, line, 10);
        try numbers.append(number);
    }

    const stdout = std.io.getStdOut();
    const out = stdout.writer();

    try out.print("[Single Values] Measurements greater the previous: {}\n", .{
        challenge1(numbers.items),
    });
    try out.print("[Sliding Window] Measurements greater the previous: {}\n", .{
        challenge2(numbers.items),
    });
}

fn challenge1(numbers: []const u32) u32 {
    var num_lines_greater: u32 = 0;
    for (numbers) |number, i| {
        if (number > numbers[i -| 1]) {
            num_lines_greater += 1;
        }
    }

    return num_lines_greater;
}

fn challenge2(numbers: []const u32) u32 {
    var num_lines_greater: u32 = 0;
    for (numbers[0..numbers.len -| 3]) |number, i| {
        if (numbers[i + 3] > number) {
            num_lines_greater += 1;
        }
    }

    return num_lines_greater;
}
