const std = @import("std");

const DATA = @embedFile("data/day02.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(arena.allocator(), DATA)});
    try out.print("{}\n", .{try challenge2(arena.allocator(), DATA)});
}

pub fn challenge1(allocator: std.mem.Allocator, input: []const u8) !i64 {
    _ = allocator;

    var total_score: i64 = 0;

    var lines = std.mem.split(u8, input, "\n");
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var choices_iterator = std.mem.split(u8, line, " ");
        const opponent_choice_string = choices_iterator.next().?;
        const player_choice_string = choices_iterator.next().?;
        std.debug.assert(opponent_choice_string.len == 1);
        std.debug.assert(player_choice_string.len == 1);
        std.debug.assert(choices_iterator.next() == null);

        const opponent_choice = opponent_choice_string[0] - 'A';
        const player_choice = player_choice_string[0] - 'X';
        const win_state = (player_choice + 3 - opponent_choice) % 3;
        switch (win_state) {
            0 => total_score += 3,
            1 => total_score += 6,
            2 => total_score += 0,
            else => unreachable,
        }
        total_score += player_choice + 1;
    }

    return total_score;
}

test challenge1 {
    const INPUT =
        \\A Y
        \\B X
        \\C Z
        \\
    ;
    try std.testing.expectEqual(@as(i64, 15), try challenge1(std.testing.allocator, INPUT));
}

pub fn challenge2(allocator: std.mem.Allocator, input: []const u8) !i64 {
    _ = allocator;

    var total_score: i64 = 0;

    var lines = std.mem.split(u8, input, "\n");
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var choices_iterator = std.mem.split(u8, line, " ");
        const opponent_choice_string = choices_iterator.next().?;
        const player_outcome_string = choices_iterator.next().?;
        std.debug.assert(opponent_choice_string.len == 1);
        std.debug.assert(player_outcome_string.len == 1);
        std.debug.assert(choices_iterator.next() == null);

        const opponent_choice = opponent_choice_string[0] - 'A';
        const player_outcome = (player_outcome_string[0] - 'X' + 2) % 3;
        const player_choice = (opponent_choice + player_outcome) % 3;
        switch (player_outcome) {
            0 => total_score += 3,
            1 => total_score += 6,
            2 => total_score += 0,
            else => unreachable,
        }
        total_score += player_choice + 1;
    }

    return total_score;
}

test challenge2 {
    const INPUT =
        \\A Y
        \\B X
        \\C Z
        \\
    ;
    try std.testing.expectEqual(@as(i64, 12), try challenge2(std.testing.allocator, INPUT));
}
