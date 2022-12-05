const std = @import("std");

const DATA = @embedFile("data/day05.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{s}\n", .{try challenge1(arena.allocator(), DATA)});
    try out.print("{s}\n", .{try challenge2(arena.allocator(), DATA)});
}

pub fn challenge1(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var stacks = std.ArrayList(std.ArrayListUnmanaged(u8)).init(allocator);
    defer {
        for (stacks.items) |*stack| {
            stack.deinit(stacks.allocator);
        }
        stacks.deinit();
    }

    var lines_iterator = std.mem.split(u8, input, "\n");
    while (lines_iterator.next()) |line| {
        if (line.len == 0) break;

        if (stacks.items.len == 0) {
            try stacks.appendNTimes(.{}, line.len / 4 + 1);
        }

        if (line[1] == '1') continue;

        var i: usize = 1;
        while (i < line.len) : (i += 4) {
            if (line[i] == ' ') continue;
            try stacks.items[i / 4].append(allocator, line[i]);
        }
    }

    // Reverse the stacks so we can pop items off the top
    for (stacks.items) |*stack, i| {
        std.mem.reverse(u8, stack.items);
        std.debug.print("stacks[{}] = {s}\n", .{ i, stack.items });
    }

    // Carry out the instruction lines
    while (lines_iterator.next()) |line| {
        if (line.len == 0) break;

        // Ignore all the words and just get the digits
        var number_string_iterator = std.mem.tokenize(u8, line, "move from to");
        const amount_to_move = try std.fmt.parseInt(usize, number_string_iterator.next().?, 10);
        const input_stack = try std.fmt.parseInt(usize, number_string_iterator.next().?, 10);
        const output_stack = try std.fmt.parseInt(usize, number_string_iterator.next().?, 10);

        var i: usize = 0;
        while (i < amount_to_move) : (i += 1) {
            try stacks.items[output_stack - 1].append(allocator, stacks.items[input_stack - 1].pop());
        }
    }

    var message = std.ArrayList(u8).init(allocator);
    defer message.deinit();
    for (stacks.items) |*stack, i| {
        std.debug.print("stacks[{}] = {s}\n", .{ i, stack.items });
        try message.append(stack.items[stack.items.len - 1]);
    }

    return message.toOwnedSlice();
}

test challenge1 {
    const INPUT =
        \\    [D]    
        \\[N] [C]    
        \\[Z] [M] [P]
        \\ 1   2   3 
        \\
        \\move 1 from 2 to 1
        \\move 3 from 1 to 3
        \\move 2 from 2 to 1
        \\move 1 from 1 to 2
        \\
    ;
    const output = try challenge1(std.testing.allocator, INPUT);
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("CMZ", output);
}

pub fn challenge2(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var stacks = std.ArrayList(std.ArrayListUnmanaged(u8)).init(allocator);
    defer {
        for (stacks.items) |*stack| {
            stack.deinit(stacks.allocator);
        }
        stacks.deinit();
    }

    var lines_iterator = std.mem.split(u8, input, "\n");
    while (lines_iterator.next()) |line| {
        if (line.len == 0) break;

        if (stacks.items.len == 0) {
            try stacks.appendNTimes(.{}, line.len / 4 + 1);
        }

        if (line[1] == '1') continue;

        var i: usize = 1;
        while (i < line.len) : (i += 4) {
            if (line[i] == ' ') continue;
            try stacks.items[i / 4].append(allocator, line[i]);
        }
    }

    // Reverse the stacks so we can pop items off the top
    for (stacks.items) |*stack, i| {
        std.mem.reverse(u8, stack.items);
        std.debug.print("stacks[{}] = {s}\n", .{ i, stack.items });
    }

    // Carry out the instruction lines
    while (lines_iterator.next()) |line| {
        if (line.len == 0) break;

        // Ignore all the words and just get the digits
        var number_string_iterator = std.mem.tokenize(u8, line, "move from to");
        const amount_to_move = try std.fmt.parseInt(usize, number_string_iterator.next().?, 10);
        const input_stack = try std.fmt.parseInt(usize, number_string_iterator.next().?, 10);
        const output_stack = try std.fmt.parseInt(usize, number_string_iterator.next().?, 10);

        const in = &stacks.items[input_stack - 1];
        try stacks.items[output_stack - 1].appendSlice(allocator, in.items[in.items.len - amount_to_move ..]);
        in.shrinkRetainingCapacity(in.items.len - amount_to_move);
    }

    var message = std.ArrayList(u8).init(allocator);
    defer message.deinit();
    for (stacks.items) |*stack, i| {
        std.debug.print("stacks[{}] = {s}\n", .{ i, stack.items });
        try message.append(stack.items[stack.items.len - 1]);
    }

    return message.toOwnedSlice();
}

test challenge2 {
    const INPUT =
        \\    [D]    
        \\[N] [C]    
        \\[Z] [M] [P]
        \\ 1   2   3 
        \\
        \\move 1 from 2 to 1
        \\move 3 from 1 to 3
        \\move 2 from 2 to 1
        \\move 1 from 1 to 2
        \\
    ;
    const output = try challenge2(std.testing.allocator, INPUT);
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("MCD", output);
}
