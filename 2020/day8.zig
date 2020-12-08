const std = @import("std");

const Op = enum {
    nop,
    acc,
    jmp,
};

const Instruction = struct {
    op: Op,
    data: i64,
};

pub fn parseInstructions(allocator: *std.mem.Allocator, text: []const u8) ![]Instruction {
    var instructions = std.ArrayList(Instruction).init(allocator);
    errdefer instructions.deinit();

    var lines_iter = std.mem.tokenize(text, "\n\r");
    while (lines_iter.next()) |line| {
        var instruction_iter = std.mem.tokenize(line, " \t");

        const op_text = instruction_iter.next() orelse continue;
        const data_text = instruction_iter.next() orelse continue;

        const op = if (std.mem.eql(u8, "nop", op_text)) @as(Op, .nop) //
        else if (std.mem.eql(u8, "acc", op_text)) @as(Op, .acc) //
        else if (std.mem.eql(u8, "jmp", op_text)) @as(Op, .jmp) //
        else return error.InvalidFormat;

        const data = try std.fmt.parseInt(i64, data_text, 10);

        try instructions.append(.{ .op = op, .data = data });
    }

    return instructions.toOwnedSlice();
}

pub fn executeUntilLoop(allocator: *std.mem.Allocator, program: []const Instruction) !?i64 {
    var visited = try allocator.alloc(bool, program.len);
    defer allocator.free(visited);
    std.mem.set(bool, visited, false);

    var accumulator: i64 = 0;
    var pci: i64 = 0;
    while (pci < program.len) {
        const pc = @intCast(usize, pci);

        if (visited[pc]) {
            return accumulator;
        }
        visited[pc] = true;

        var should_increment_pc = true;
        switch (program[pc].op) {
            .nop => {},
            .acc => {
                accumulator += program[pc].data;
            },
            .jmp => {
                pci += program[pc].data;
                should_increment_pc = false;
            },
        }

        if (should_increment_pc) {
            pci += 1;
        }
    }

    return null;
}

test "parsing instructions" {
    const input =
        \\ nop +0
        \\ acc +1
        \\ jmp +4
        \\ acc +3
        \\ jmp -3
        \\ acc -99
        \\ acc +1
        \\ jmp -4
        \\ acc +6
    ;

    const code = try parseInstructions(std.testing.allocator, input);
    defer std.testing.allocator.free(code);

    std.testing.expectEqual(Instruction{ .op = .nop, .data = 0 }, code[0]);
}

test "detecting loop" {
    const input =
        \\ nop +0
        \\ acc +1
        \\ jmp +4
        \\ acc +3
        \\ jmp -3
        \\ acc -99
        \\ acc +1
        \\ jmp -4
        \\ acc +6
    ;

    const code = try parseInstructions(std.testing.allocator, input);
    defer std.testing.allocator.free(code);

    const accum_value = try executeUntilLoop(std.testing.allocator, code);

    std.testing.expectEqual(@as(?i64, 5), accum_value);
}

const INPUT = @embedFile("./day8.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = &gpa.allocator;

    const out = std.io.getStdOut().writer();

    const code = try parseInstructions(allocator, INPUT);
    defer allocator.free(code);

    const accum_value = try executeUntilLoop(std.testing.allocator, code);

    try out.print("Accumulator value was {} when loop was detected\n", .{accum_value});
}
