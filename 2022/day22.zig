const std = @import("std");
const util = @import("util");
const glfw = @import("util").glfw;
const gl = @import("util").gl;
const nanovg = @import("util").nanovg;
const Grid = @import("util").Grid;
const ConstGrid = @import("util").ConstGrid;

const DATA = @embedFile("data/day22.txt");

pub fn challenge1(allocator: std.mem.Allocator, input: []const u8) !i64 {
    var data = try parseData(allocator, input);
    defer {
        data.map.free(allocator);
    }

    var pos = @Vector(2, i64){ @intCast(i64, std.mem.indexOf(u8, data.map.data, ".").?), 0 };
    var dir = @Vector(2, i64){ 1, 0 };

    var number: i64 = 0;
    for (data.directions) |character| {
        switch (character) {
            '0'...'9' => {
                number *= 10;
                number += character - '0';
            },
            'L' => {
                pos = moveNTimes(data.map.asConst(), pos, dir, number);
                dir = rotateCW(dir);
                number = 0;
            },
            'R' => {
                pos = moveNTimes(data.map.asConst(), pos, dir, number);
                dir = rotateCCW(dir);
                number = 0;
            },
            else => return error.InvalidFormat,
        }
    }
    pos = moveNTimes(data.map.asConst(), pos, dir, number);
    number = 0;

    const facing: i64 = if (dir[0] == 1 and dir[1] == 0)
        0
    else if (dir[0] == 0 and dir[1] == 1)
        1
    else if (dir[0] == -1 and dir[1] == 0)
        2
    else if (dir[0] == 0 and dir[1] == -1)
        3
    else
        unreachable;

    return (pos[1] + 1) * 1000 + (pos[0] + 1) * 4 + facing;
}

fn moveNTimes(map: ConstGrid(u8), pos: @Vector(2, i64), dir: @Vector(2, i64), n: i64) @Vector(2, i64) {
    const map_size = @Vector(2, i64){
        @intCast(i64, map.size[0]),
        @intCast(i64, map.size[1]),
    };
    var new_pos = pos;
    var i: i64 = 0;
    while (i < n) : (i += 1) {
        var next = new_pos;
        look_nonblank_tile: while (true) {
            next = @mod(next + map_size + dir, map_size);
            const next_tile = map.getPos(.{
                @intCast(usize, next[0]),
                @intCast(usize, next[1]),
            });
            switch (next_tile) {
                ' ' => continue :look_nonblank_tile,
                '.' => break :look_nonblank_tile,
                '#' => return new_pos,
                else => unreachable,
            }
        }
        new_pos = next;
    }
    return new_pos;
}

fn rotateCW(v: @Vector(2, i64)) @Vector(2, i64) {
    return .{ v[1], -v[0] };
}

fn rotateCCW(v: @Vector(2, i64)) @Vector(2, i64) {
    return .{ -v[1], v[0] };
}

const Data = struct {
    map: Grid(u8),
    directions: []const u8,
};

pub fn parseData(allocator: std.mem.Allocator, input: []const u8) !Data {
    var section_iter = std.mem.split(u8, input, "\n\n");

    const map_section = section_iter.next() orelse return error.InvalidFormat;
    const directions_section = section_iter.next() orelse return error.InvalidFormat;

    var map_width = std.mem.indexOfScalar(u8, map_section, '\n') orelse return error.InvalidFormat;
    var map_height: usize = 0;
    {
        var lines_iter = std.mem.tokenize(u8, map_section, "\n");
        while (lines_iter.next()) |line| : (map_height += 1) {
            map_width = @max(map_width, line.len);
        }
    }

    const map = try Grid(u8).alloc(allocator, .{ map_width, map_height });
    map.set(' ');
    {
        var lines_iter = std.mem.tokenize(u8, map_section, "\n");
        var row_index: usize = 0;
        while (lines_iter.next()) |line| {
            std.mem.copy(u8, map.getRow(row_index), std.mem.trim(u8, line, "\n"));
            row_index += 1;
        }
    }

    return Data{
        .map = map,
        .directions = std.mem.trim(u8, directions_section, " \n"),
    };
}

const TEST_DATA =
    \\        ...# 
    \\        .#.. 
    \\        #... 
    \\        .... 
    \\...#.......# 
    \\........#... 
    \\..#....#.... 
    \\..........#.
    \\        ...#....
    \\        .....#..
    \\        .#......
    \\        ......#.
    \\
    \\10R5L5R10L4R5L5
    \\
;

test "challenge 1" {
    const output = try challenge1(std.testing.allocator, TEST_DATA);
    try std.testing.expectEqual(@as(i64, 6032), output);
}

pub fn main() !void {
    const ctx = try util.Context.init(.{ .title = "Advent of Code - Day 21" });
    defer ctx.deinit();

    const stdout = std.io.getStdOut();

    const answer1 = try challenge1(ctx.allocator, DATA);
    try stdout.writer().print("{}\n", .{answer1});
}
