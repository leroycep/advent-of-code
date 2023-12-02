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

    try stdout.print("part 1 solution = {}\n", .{try possibleGamesSum(gpa, input, &.{
        .{ .color = "red", .amount = 12 },
        .{ .color = "green", .amount = 13 },
        .{ .color = "blue", .amount = 14 },
    })});

    try stdout.print("part 2 solution = {}\n", .{try gamesPowerSum(gpa, input)});

    try bw.flush();
}

const CubeCount = struct {
    color: []const u8,
    amount: i64,
};

pub fn possibleGamesSum(gpa: std.mem.Allocator, text: []const u8, cubes_in_bag_list: []const CubeCount) !i64 {
    var cubes_in_bag = std.StringHashMap(i64).init(gpa);
    defer cubes_in_bag.deinit();
    for (cubes_in_bag_list) |cube_count| {
        try cubes_in_bag.put(cube_count.color, cube_count.amount);
    }

    var sum: i64 = 0;

    var line_iter = std.mem.splitAny(u8, text, "\n");
    check_games: while (line_iter.next()) |line| {
        const index_of_colon = std.mem.indexOfScalarPos(u8, line, 5, ':') orelse continue;
        const id = try std.fmt.parseInt(i64, line[5..index_of_colon], 10);

        var set_iter = std.mem.splitScalar(u8, line[index_of_colon + 1 ..], ';');
        while (set_iter.next()) |set| {
            var token_iter = std.mem.tokenizeAny(u8, set, " ,");
            const is_possible = while (true) {
                const amount_str = token_iter.next() orelse break true;
                const color = token_iter.next() orelse break true;

                errdefer std.debug.print("amount = {s}\n", .{amount_str});
                const amount = try std.fmt.parseInt(i64, amount_str, 10);

                const amount_in_bag = cubes_in_bag.get(color) orelse break false;
                if (amount_in_bag < amount) break false;
            };

            if (!is_possible) {
                continue :check_games;
            }
        }

        sum += id;
    }

    return sum;
}

test possibleGamesSum {
    const input =
        \\Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green
        \\Game 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue
        \\Game 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red
        \\Game 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red
        \\Game 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green
        \\
    ;
    try std.testing.expectEqual(@as(i64, 8), try possibleGamesSum(std.testing.allocator, input, &.{
        .{ .color = "red", .amount = 12 },
        .{ .color = "green", .amount = 13 },
        .{ .color = "blue", .amount = 14 },
    }));
}

pub fn gamesPowerSum(gpa: std.mem.Allocator, text: []const u8) !i64 {
    var cubes_in_bag = std.StringHashMap(i64).init(gpa);
    defer cubes_in_bag.deinit();

    var sum: i64 = 0;

    var line_iter = std.mem.splitAny(u8, text, "\n");
    while (line_iter.next()) |line| {
        cubes_in_bag.clearRetainingCapacity();

        const index_of_colon = std.mem.indexOfScalarPos(u8, line, 5, ':') orelse continue;

        var set_iter = std.mem.splitScalar(u8, line[index_of_colon + 1 ..], ';');
        while (set_iter.next()) |set| {
            var token_iter = std.mem.tokenizeAny(u8, set, " ,");
            while (true) {
                const amount_str = token_iter.next() orelse break;
                const color = token_iter.next() orelse break;

                const amount = try std.fmt.parseInt(i64, amount_str, 10);

                const min_required_gop = try cubes_in_bag.getOrPut(color);
                if (!min_required_gop.found_existing) {
                    min_required_gop.value_ptr.* = amount;
                } else {
                    min_required_gop.value_ptr.* = @max(amount, min_required_gop.value_ptr.*);
                }
            }
        }

        var power: i64 = 1;

        var bag_iter = cubes_in_bag.valueIterator();
        while (bag_iter.next()) |amount| {
            power *= amount.*;
        }

        sum += power;
    }

    return sum;
}

test gamesPowerSum {
    const input =
        \\Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green
        \\Game 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue
        \\Game 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red
        \\Game 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red
        \\Game 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green
        \\
    ;
    try std.testing.expectEqual(@as(i64, 2286), try gamesPowerSum(std.testing.allocator, input));
}
