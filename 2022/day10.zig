const std = @import("std");

const DATA = @embedFile("data/day10.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(arena.allocator(), DATA)});
}

pub fn challenge1(allocator: std.mem.Allocator, input: []const u8) !i64 {
    _ = allocator;

    var lines_iterator = std.mem.split(u8, input, "\n");

    const State = union(enum) {
        read_instruction,
        add_value: i64,
    };

    var accumulator: i64 = 0;

    std.debug.print("\n", .{});

    var state = State{ .read_instruction = {} };
    var register: i64 = 1;
    var cycle: i64 = 1;
    while (true) : (cycle += 1) {
        switch (cycle) {
            20, 60, 100, 140, 180, 220 => accumulator += register * cycle,
            else => {},
        }

        switch (state) {
            .read_instruction => {
                const line = lines_iterator.next() orelse break;
                if (line.len == 0) break;

                var word_iterator = std.mem.split(u8, line, " ");
                const command = word_iterator.next().?;
                if (std.mem.eql(u8, command, "noop")) {} else if (std.mem.eql(u8, command, "addx")) {
                    const value = try std.fmt.parseInt(i64, word_iterator.next().?, 10);
                    state = .{ .add_value = value };
                } else {
                    std.debug.panic("Unknown command: {s}", .{command});
                }
            },
            .add_value => |value| {
                register += value;
                state = .read_instruction;
            },
        }

        const scan_x = @mod(cycle, 40);
        if (scan_x - register >= -1 and scan_x - register <= 1) {
            std.debug.print("#", .{});
        } else {
            std.debug.print(" ", .{});
        }
        if (@mod(cycle, 40) == 0) {
            std.debug.print("\n", .{});
        }
    }

    return accumulator;
}

test challenge1 {
    const output = try challenge1(std.testing.allocator,
        \\addx 15
        \\addx -11
        \\addx 6
        \\addx -3
        \\addx 5
        \\addx -1
        \\addx -8
        \\addx 13
        \\addx 4
        \\noop
        \\addx -1
        \\addx 5
        \\addx -1
        \\addx 5
        \\addx -1
        \\addx 5
        \\addx -1
        \\addx 5
        \\addx -1
        \\addx -35
        \\addx 1
        \\addx 24
        \\addx -19
        \\addx 1
        \\addx 16
        \\addx -11
        \\noop
        \\noop
        \\addx 21
        \\addx -15
        \\noop
        \\noop
        \\addx -3
        \\addx 9
        \\addx 1
        \\addx -3
        \\addx 8
        \\addx 1
        \\addx 5
        \\noop
        \\noop
        \\noop
        \\noop
        \\noop
        \\addx -36
        \\noop
        \\addx 1
        \\addx 7
        \\noop
        \\noop
        \\noop
        \\addx 2
        \\addx 6
        \\noop
        \\noop
        \\noop
        \\noop
        \\noop
        \\addx 1
        \\noop
        \\noop
        \\addx 7
        \\addx 1
        \\noop
        \\addx -13
        \\addx 13
        \\addx 7
        \\noop
        \\addx 1
        \\addx -33
        \\noop
        \\noop
        \\noop
        \\addx 2
        \\noop
        \\noop
        \\noop
        \\addx 8
        \\noop
        \\addx -1
        \\addx 2
        \\addx 1
        \\noop
        \\addx 17
        \\addx -9
        \\addx 1
        \\addx 1
        \\addx -3
        \\addx 11
        \\noop
        \\noop
        \\addx 1
        \\noop
        \\addx 1
        \\noop
        \\noop
        \\addx -13
        \\addx -19
        \\addx 1
        \\addx 3
        \\addx 26
        \\addx -30
        \\addx 12
        \\addx -1
        \\addx 3
        \\addx 1
        \\noop
        \\noop
        \\noop
        \\addx -9
        \\addx 18
        \\addx 1
        \\addx 2
        \\noop
        \\noop
        \\addx 9
        \\noop
        \\noop
        \\noop
        \\addx -1
        \\addx 2
        \\addx -37
        \\addx 1
        \\addx 3
        \\noop
        \\addx 15
        \\addx -21
        \\addx 22
        \\addx -6
        \\addx 1
        \\noop
        \\addx 2
        \\addx 1
        \\noop
        \\addx -10
        \\noop
        \\noop
        \\addx 20
        \\addx 1
        \\addx 2
        \\addx 2
        \\addx -6
        \\addx -11
        \\noop
        \\noop
        \\noop        
        \\
    );
    try std.testing.expectEqual(@as(i64, 13140), output);
}
