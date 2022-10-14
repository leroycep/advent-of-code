const std = @import("std");

const DATA = @embedFile("./data/day10.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(arena.allocator(), DATA)});
    try out.print("{}\n", .{try challenge2(arena.allocator(), DATA)});
}

pub fn challenge1(allocator: std.mem.Allocator, data: []const u8) !u64 {
    var syntax_error_score: u64 = 0;

    var stack = std.ArrayList(u8).init(allocator);
    defer stack.deinit();

    var line_iter = std.mem.tokenize(u8, data, "\n");

    iterate_lines: while (line_iter.next()) |line| {
        stack.shrinkRetainingCapacity(0);
        for (line) |character| {
            switch (character) {
                '(', '[', '{', '<' => try stack.append(character),
                ')', ']', '}', '>' => {
                    if (stack.popOrNull()) |open| {
                        if (!closeMatchesOpen(character, open)) {
                            syntax_error_score += getSyntaxErrorValue(character);
                            continue :iterate_lines;
                        }
                    }
                },
                else => std.debug.panic("Unexpected character: '{'}' (0x{x})", .{ std.zig.fmtEscapes(&.{character}), character }),
            }
        }
    }

    return syntax_error_score;
}

pub fn closeMatchesOpen(close: u8, open: u8) bool {
    if (open == '(' and close == ')') return true;
    if (open == '[' and close == ']') return true;
    if (open == '{' and close == '}') return true;
    if (open == '<' and close == '>') return true;
    return false;
}

pub fn getSyntaxErrorValue(character: u8) u64 {
    return switch (character) {
        ')' => 3,
        ']' => 57,
        '}' => 1197,
        '>' => 25137,
        else => std.debug.panic("No score for character: '{'}' (0x{x})", .{ std.zig.fmtEscapes(&.{character}), character }),
    };
}

test challenge1 {
    try std.testing.expectEqual(@as(u64, 26397), try challenge1(std.testing.allocator,
        \\[({(<(())[]>[[{[]{<()<>>
        \\[(()[<>])]({[<{<<[]>>(
        \\{([(<{}[<>[]}>{[]{[(<()>
        \\(((({<>}<{<{<>}{[]{[]{}
        \\[[<[([]))<([[{}[[()]]]
        \\[{[{({}]{}}([{[{{{}}([]
        \\{<[[]]>}<{[{[{[]{()[[[]
        \\[<(<(<(<{}))><([]([]()
        \\<{([([[(<>()){}]>(<<{{
        \\<{([{{}}[<[[[<>{}]]]>[]]
        \\
    ));
}

pub fn challenge2(allocator: std.mem.Allocator, data: []const u8) !u64 {
    var scores = std.ArrayList(u64).init(allocator);
    defer scores.deinit();

    var stack = std.ArrayList(u8).init(allocator);
    defer stack.deinit();

    var line_iter = std.mem.tokenize(u8, data, "\n");

    iterate_lines: while (line_iter.next()) |line| {
        stack.shrinkRetainingCapacity(0);
        for (line) |character| {
            switch (character) {
                '(', '[', '{', '<' => try stack.append(character),
                ')', ']', '}', '>' => {
                    if (stack.popOrNull()) |open| {
                        if (!closeMatchesOpen(character, open)) {
                            continue :iterate_lines;
                        }
                    }
                },
                else => std.debug.panic("Unexpected character: '{'}' (0x{x})", .{ std.zig.fmtEscapes(&.{character}), character }),
            }
        }

        var score: u64 = 0;
        while (stack.popOrNull()) |open| {
            score *= 5;
            score += switch (open) {
                '(' => 1,
                '[' => 2,
                '{' => 3,
                '<' => 4,
                else => std.debug.panic("Unexpected open: '{'}' (0x{x})", .{ std.zig.fmtEscapes(&.{open}), open }),
            };
        }
        try scores.append(score);
    }

    std.sort.sort(u64, scores.items, {}, std.sort.asc(u64));

    if (false) {
        for (scores.items) |score, i| {
            std.debug.print("score[{}] = {}\n", .{ i, score });
        }
    }

    return scores.items[scores.items.len / 2];
}

test challenge2 {
    try std.testing.expectEqual(@as(u64, 288957), try challenge2(std.testing.allocator,
        \\[({(<(())[]>[[{[]{<()<>>
        \\[(()[<>])]({[<{<<[]>>(
        \\{([(<{}[<>[]}>{[]{[(<()>
        \\(((({<>}<{<{<>}{[]{[]{}
        \\[[<[([]))<([[{}[[()]]]
        \\[{[{({}]{}}([{[{{{}}([]
        \\{<[[]]>}<{[{[{[]{()[[[]
        \\[<(<(<(<{}))><([]([]()
        \\<{([([[(<>()){}]>(<<{{
        \\<{([{{}}[<[[[<>{}]]]>[]]
        \\
    ));
}
