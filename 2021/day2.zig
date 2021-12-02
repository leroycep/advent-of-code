const std = @import("std");

const DATA = @embedFile("./data/day2.txt");

const Command = enum {
    up,
    down,
    forward,
};

pub fn main() !void {
    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1()});
    try out.print("{}\n", .{try challenge2()});
}

const Pos = struct {
    depth: i32 = 0,
    position: i32 = 0,
};

pub fn challenge1() !Pos {
    var pos = Pos{};

    var line_iter = std.mem.tokenize(u8, DATA, "\n\r");
    while (line_iter.next()) |line| {
        var word_iter = std.mem.tokenize(u8, line, " ");
        const cmd_str = word_iter.next() orelse return error.InvalidFormat;
        const number_str = word_iter.next() orelse return error.InvalidFormat;
        std.debug.assert(word_iter.next() == null);

        const cmd = std.meta.stringToEnum(Command, cmd_str) orelse return error.UnknownCommand;
        const number = try std.fmt.parseInt(i32, number_str, 10);

        switch (cmd) {
            .up => pos.depth -= number,
            .down => pos.depth += number,
            .forward => pos.position += number,
        }
    }

    return pos;
}

pub fn challenge2() !Pos {
    var pos = Pos{};
    var aim: i32 = 0;

    var line_iter = std.mem.tokenize(u8, DATA, "\n\r");
    while (line_iter.next()) |line| {
        var word_iter = std.mem.tokenize(u8, line, " ");
        const cmd_str = word_iter.next() orelse return error.InvalidFormat;
        const number_str = word_iter.next() orelse return error.InvalidFormat;
        std.debug.assert(word_iter.next() == null);

        const cmd = std.meta.stringToEnum(Command, cmd_str) orelse return error.UnknownCommand;
        const number = try std.fmt.parseInt(i32, number_str, 10);

        switch (cmd) {
            .up => aim -= number,
            .down => aim += number,
            .forward => {
                pos.position += number;
                pos.depth += aim * number;
            },
        }
    }

    return pos;
}
