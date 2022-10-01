const std = @import("std");

const DATA = @embedFile("./data/day7.txt");

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
    var subs = std.ArrayList(u32).init(allocator);
    defer subs.deinit();

    var sub_iter = std.mem.tokenize(u8, data, ",\n");
    var min_pos: u32 = std.math.maxInt(u32);
    var max_pos: u32 = std.math.minInt(u32);
    while (sub_iter.next()) |initial_sub_str| {
        const initial_sub = try std.fmt.parseInt(u32, initial_sub_str, 10);
        try subs.append(initial_sub);
        min_pos = std.math.min(initial_sub, min_pos);
        max_pos = std.math.max(initial_sub, max_pos);
    }

    var min_fuel: u32 = std.math.maxInt(u32);
    var align_to = min_pos;
    while (align_to <= max_pos) : (align_to += 1) {
        var min_fuel_for_this_align: u32 = 0;
        for (subs.items) |start_pos| {
            const min = std.math.min(start_pos, align_to);
            const max = std.math.max(start_pos, align_to);
            min_fuel_for_this_align += max - min;
        }
        min_fuel = std.math.min(min_fuel_for_this_align, min_fuel);
    }

    return min_fuel;
}

pub fn challenge2(allocator: std.mem.Allocator, data: []const u8) !u64 {
    var subs = std.ArrayList(u32).init(allocator);
    defer subs.deinit();

    var cache = std.ArrayList(u32).init(allocator);
    defer cache.deinit();
    try cache.append(0);

    var sub_iter = std.mem.tokenize(u8, data, ",\n");
    var min_pos: u32 = std.math.maxInt(u32);
    var max_pos: u32 = std.math.minInt(u32);
    while (sub_iter.next()) |initial_sub_str| {
        const initial_sub = try std.fmt.parseInt(u32, initial_sub_str, 10);
        try subs.append(initial_sub);
        min_pos = std.math.min(initial_sub, min_pos);
        max_pos = std.math.max(initial_sub, max_pos);
    }

    var min_fuel: u32 = std.math.maxInt(u32);
    var align_to = min_pos;
    while (align_to <= max_pos) : (align_to += 1) {
        var min_fuel_for_this_align: u32 = 0;
        for (subs.items) |start_pos| {
            const min = std.math.min(start_pos, align_to);
            const max = std.math.max(start_pos, align_to);
            min_fuel_for_this_align += try calculate_fuel_required(&cache, max - min);
        }
        min_fuel = std.math.min(min_fuel_for_this_align, min_fuel);
    }

    return min_fuel;
}

fn calculate_fuel_required(cache: *std.ArrayList(u32), distance: u32) !u32 {
    if (cache.items.len - 1 < distance) {
        const value = try calculate_fuel_required(cache, distance - 1) + distance;
        std.debug.assert(cache.items.len == distance);
        try cache.append(value);
    }
    return cache.items[distance];
}

test {
    try std.testing.expectEqual(@as(u64, 37), try challenge1(std.testing.allocator, "16,1,2,0,4,2,7,1,2,14"));
}

test {
    try std.testing.expectEqual(@as(u64, 168), try challenge2(std.testing.allocator, "16,1,2,0,4,2,7,1,2,14"));
}
