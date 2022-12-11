const std = @import("std");

const DATA = @embedFile("data/day10.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(arena.allocator(), &.{
        .{
            .starting_items = &.{ 85, 77, 77 },
            .operation = .{ .multiply = 7 },
            .modulus = 19,
            .on_true = 6,
            .on_false = 7,
        },

        .{
            .starting_items = &.{ 80, 99 },
            .operation = .{ .multiply = 11 },
            .modulus = 3,
            .on_true = 3,
            .on_false = 5,
        },

        .{
            .starting_items = &.{ 74, 60, 74, 63, 86, 92, 80 },
            .operation = .{ .add = 8 },
            .modulus = 13,
            .on_true = 0,
            .on_false = 6,
        },

        .{
            .starting_items = &.{ 71, 58, 93, 65, 80, 68, 54, 71 },
            .operation = .{ .add = 7 },
            .modulus = 7,
            .on_true = 2,
            .on_false = 4,
        },

        .{
            .starting_items = &.{ 97, 56, 79, 65, 58 },
            .operation = .{ .add = 5 },
            .modulus = 5,
            .on_true = 2,
            .on_false = 0,
        },

        .{
            .starting_items = &.{77},
            .operation = .{ .add = 4 },
            .modulus = 11,
            .on_true = 4,
            .on_false = 3,
        },

        .{
            .starting_items = &.{ 99, 90, 84, 50 },
            .operation = .{ .square = {} },
            .modulus = 17,
            .on_true = 7,
            .on_false = 1,
        },

        .{
            .starting_items = &.{ 50, 66, 61, 92, 64, 78 },
            .operation = .{ .add = 3 },
            .modulus = 2,
            .on_true = 5,
            .on_false = 1,
        },
    })});
}

const Monkey = struct {
    starting_items: []const i64,
    operation: Operation,
    modulus: i64,
    on_true: u32,
    on_false: u32,

    const Operation = union(enum) {
        multiply: i64,
        add: i64,
        square: void,
    };
};

pub fn challenge1(allocator: std.mem.Allocator, input: []const Monkey) !i64 {
    var monkey_seen = std.ArrayListUnmanaged(i64){};
    defer monkey_seen.deinit(allocator);
    try monkey_seen.appendNTimes(allocator, 0, input.len);

    var monkey_inventory = std.ArrayListUnmanaged(std.ArrayListUnmanaged(i64)){};
    defer {
        for (monkey_inventory.items) |*monkey_inv| {
            monkey_inv.deinit(allocator);
        }
        monkey_inventory.deinit(allocator);
    }

    try monkey_inventory.appendNTimes(allocator, .{}, input.len);
    for (input) |monkey, monkey_index| {
        try monkey_inventory.items[monkey_index].appendSlice(allocator, monkey.starting_items);
    }

    var i: usize = 0;
    while (i < 20) : (i += 1) {
        for (input) |monkey, monkey_index| {
            for (monkey_inventory.items[monkey_index].items) |item_worry| {
                var new_item_worry = switch (monkey.operation) {
                    .add => |b| item_worry + b,
                    .multiply => |b| item_worry * b,
                    .square => item_worry * item_worry,
                };
                new_item_worry = @divFloor(new_item_worry, 3);
                const new_monkey_index = if (@mod(new_item_worry, monkey.modulus) == 0) monkey.on_true else monkey.on_false;
                try monkey_inventory.items[new_monkey_index].append(allocator, new_item_worry);
            }
            monkey_seen.items[monkey_index] += @intCast(i64, monkey_inventory.items[monkey_index].items.len);
            monkey_inventory.items[monkey_index].shrinkRetainingCapacity(0);
        }
    }

    for (monkey_inventory.items) |inventory, monkey_index| {
        std.debug.print("monkey[{}] inventory = {any}\n", .{ monkey_index, inventory.items });
    }

    for (monkey_seen.items) |seen, monkey_index| {
        std.debug.print("monkey[{}] seen = {}\n", .{ monkey_index, seen });
    }

    std.sort.sort(i64, monkey_seen.items, {}, std.sort.desc(i64));

    return monkey_seen.items[0] * monkey_seen.items[1];
}

const TEST_INPUT = [_]Monkey{
    .{
        .starting_items = &.{ 79, 98 },
        .operation = .{ .multiply = 19 },
        .modulus = 23,
        .on_true = 2,
        .on_false = 3,
    },
    .{
        .starting_items = &.{ 54, 65, 75, 74 },
        .operation = .{ .add = 6 },
        .modulus = 19,
        .on_true = 2,
        .on_false = 0,
    },
    .{
        .starting_items = &.{ 79, 60, 97 },
        .operation = .{ .square = {} },
        .modulus = 13,
        .on_true = 1,
        .on_false = 3,
    },
    .{
        .starting_items = &.{74},
        .operation = .{ .add = 3 },
        .modulus = 17,
        .on_true = 0,
        .on_false = 1,
    },
};

const TEST_INPUT_STRING =
    \\Monkey 0:
    \\  Starting items: 79, 98
    \\  Operation: new = old * 19
    \\  Test: divisible by 23
    \\    If true: throw to monkey 2
    \\    If false: throw to monkey 3
    \\
    \\Monkey 1:
    \\  Starting items: 54, 65, 75, 74
    \\  Operation: new = old + 6
    \\  Test: divisible by 19
    \\    If true: throw to monkey 2
    \\    If false: throw to monkey 0
    \\
    \\Monkey 2:
    \\  Starting items: 79, 60, 97
    \\  Operation: new = old * old
    \\  Test: divisible by 13
    \\    If true: throw to monkey 1
    \\    If false: throw to monkey 3
    \\
    \\Monkey 3:
    \\  Starting items: 74
    \\  Operation: new = old + 3
    \\  Test: divisible by 17
    \\    If true: throw to monkey 0
    \\    If false: throw to monkey 1
    \\
;

test challenge1 {
    const output = try challenge1(std.testing.allocator, &TEST_INPUT);
    try std.testing.expectEqual(@as(i64, 10605), output);
}

pub fn challenge2(allocator: std.mem.Allocator, input: []const u8) !i64 {
    _ = allocator;
    _ = input;
    return 0;
}

test challenge2 {
    if (true) return error.SkipZigTest;
    const output = try challenge2(std.testing.allocator, "");
    try std.testing.expectEqual(@as(i64, 23240), output);
}
