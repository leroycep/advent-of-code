const std = @import("std");

const DATA = @embedFile("data/day03.txt");

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

    var accumulator: i64 = 0;

    var lines_iterator = std.mem.split(u8, input, "\n");
    while (lines_iterator.next()) |line| {
        if (line.len == 0) continue;
        const rucksacks = [2][]const u8{ line[0 .. line.len / 2], line[line.len / 2 ..] };
        var items = [2]u64{ 0, 0 };
        for (rucksacks) |rucksack, rucksack_index| {
            for (rucksack) |item| {
                items[rucksack_index] |= (@as(u64, 1) << @intCast(u6, item - 'A'));
            }
        }
        const shared_item_bit = items[0] & items[1];
        const item = 'A' + @ctz(shared_item_bit);
        switch (item) {
            'a'...'z' => {
                accumulator += item - 'a' + 1;
            },
            'A'...'Z' => {
                accumulator += item - 'A' + 27;
            },
            else => unreachable,
        }
    }

    return accumulator;
}

test challenge1 {
    const INPUT =
        \\vJrwpWtwJgWrhcsFMMfFFhFp
        \\jqHRNqRjqzjGDLGLrsFMfFZSrLrFZsSL
        \\PmmdzqPrVvPwwTWBwg
        \\wMqvLMZHhHMvwLHjbvcjnnSBnvTQFn
        \\ttgJtRGJQctTZtZT
        \\CrZsJsPPZsGzwwsLwLmpwMDw
        \\
    ;
    try std.testing.expectEqual(@as(i64, 157), try challenge1(std.testing.allocator, INPUT));
}

pub fn challenge2(allocator: std.mem.Allocator, input: []const u8) !i64 {
    _ = allocator;

    var accumulator: i64 = 0;

    var lines_iterator = std.mem.split(u8, input, "\n");
    main_loop: while (true) {
        var i: usize = 0;
        var contained_in_all: u64 = std.math.maxInt(u64);
        while (i < 3) : (i += 1) {
            const rucksack = lines_iterator.next() orelse break :main_loop;
            if (rucksack.len == 0) break :main_loop;

            var items: u64 = 0;
            for (rucksack) |item| {
                items |= (@as(u64, 1) << @intCast(u6, item - 'A'));
            }
            contained_in_all &= items;
        }
        const item = 'A' + @ctz(contained_in_all);
        switch (item) {
            'a'...'z' => {
                accumulator += item - 'a' + 1;
            },
            'A'...'Z' => {
                accumulator += item - 'A' + 27;
            },
            else => unreachable,
        }
    }
    return accumulator;
}

test challenge2 {
    const INPUT =
        \\vJrwpWtwJgWrhcsFMMfFFhFp
        \\jqHRNqRjqzjGDLGLrsFMfFZSrLrFZsSL
        \\PmmdzqPrVvPwwTWBwg
        \\wMqvLMZHhHMvwLHjbvcjnnSBnvTQFn
        \\ttgJtRGJQctTZtZT
        \\CrZsJsPPZsGzwwsLwLmpwMDw
        \\
    ;
    try std.testing.expectEqual(@as(i64, 70), try challenge2(std.testing.allocator, INPUT));
}
