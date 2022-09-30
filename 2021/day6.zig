const std = @import("std");

const DATA = @embedFile("./data/day6.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(arena.allocator(), DATA)});
    try out.print("{}\n", .{try challenge2(DATA)});
}

pub fn challenge1(allocator: std.mem.Allocator, data: []const u8) !u64 {
    var fishies = std.ArrayList(u8).init(allocator);
    defer fishies.deinit();

    var age_iter = std.mem.tokenize(u8, data, ",");
    while (age_iter.next()) |initial_fish_str| {
        const initial_fish = try std.fmt.parseInt(u8, initial_fish_str, 10);
        try fishies.append(initial_fish);
    }

    var i: usize = 0;
    while (i < 80) : (i += 1) {
        var number_of_new_fishies: usize = 0;
        for (fishies.items) |*fish| {
            if (fish.* == 0) {
                fish.* = 6;
                number_of_new_fishies += 1;
            } else {
                fish.* -= 1;
            }
        }

        try fishies.appendNTimes(8, number_of_new_fishies);
    }

    return fishies.items.len;
}

pub fn challenge2(data: []const u8) !u64 {
    var fishies = [9]u64{ 0, 0, 0, 0, 0, 0, 0, 0, 0 };

    var age_iter = std.mem.tokenize(u8, data, ",");
    while (age_iter.next()) |initial_fish_str| {
        const initial_fish = try std.fmt.parseInt(u8, initial_fish_str, 10);
        fishies[initial_fish] += 1;
    }

    var i: usize = 0;
    while (i < 256) : (i += 1) {
        var next_fishies: [9]u64 = undefined;
        for (next_fishies) |*next_fish, index| {
            next_fish.* = fishies[(index + 1) % 9];
        }
        next_fishies[6] += fishies[0];

        fishies = next_fishies;
    }

    var sum: u64 = 0;
    for (fishies) |population_at_age| {
        sum += population_at_age;
    }
    return sum;
}

test {
    try std.testing.expectEqual(@as(u64, 5934), try challenge1(std.testing.allocator, "3,4,3,1,2"));
}
