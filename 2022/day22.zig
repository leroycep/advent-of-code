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

    var map = try Grid(u8).alloc(allocator, .{ map_width, map_height });
    map.set(' ');
    {
        var lines_iter = std.mem.tokenize(u8, map_section, "\n");
        var row_index: usize = 0;
        while (lines_iter.next()) |line| {
            std.mem.copy(u8, map.getRow(row_index), line);
            row_index += 1;
        }
    }

    return Data{
        .map = map,
        .directions = std.mem.trim(u8, directions_section, " \n"),
    };
}

pub fn challenge2(allocator: std.mem.Allocator, input: []const u8) !i64 {
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

const Face = enum(u8) {
    front = 0,
    top = 1,
    left = 2,
    bottom = 3,
    back = 4,
    right = 5,

    fn fromDirection(dir: [4]i64) @This() {
        if (std.mem.eql(i64, &.{ 0, 0, -1, 0 }, &dir)) {
            return .front;
        } else if (std.mem.eql(i64, &.{ 0, 0, 1, 0 }, &dir)) {
            return .back;
        } else if (std.mem.eql(i64, &.{ 0, -1, 0, 0 }, &dir)) {
            return .top;
        } else if (std.mem.eql(i64, &.{ 0, 1, 0, 0 }, &dir)) {
            return .bottom;
        } else if (std.mem.eql(i64, &.{ -1, 0, 0, 0 }, &dir)) {
            return .left;
        } else if (std.mem.eql(i64, &.{ 1, 0, 0, 0 }, &dir)) {
            return .right;
        } else {
            unreachable;
        }
    }
};

const FaceGrid = struct {
    pos: @Vector(2, usize),
    grid: ConstGrid(u8),
};

fn findFaces(allocator: std.mem.Allocator, map: ConstGrid(u8), face_size: usize) ![6]FaceGrid {
    var faces: [6]FaceGrid = undefined;

    var face_is_set: [6]bool = undefined;
    std.mem.set(bool, &face_is_set, false);

    const FaceToTry = struct {
        pos: @Vector(2, usize),
        vrot: u2,
        hrot: u2,
    };

    var next_face_to_try = std.ArrayList(FaceToTry).init(allocator);
    defer next_face_to_try.deinit();

    try next_face_to_try.append(.{
        .pos = .{ std.mem.indexOf(u8, map.data, ".").?, 0 },
        .vrot = 0,
        .hrot = 0,
    });

    while (next_face_to_try.popOrNull()) |face_to_try| {
        var dir = @Vector(4, i64){ 0, 0, -1, 0 };
        {
            var i: u2 = 0;
            while (i < face_to_try.hrot) : (i += 1) {
                dir = rotateVec4Y_CCW(dir);
            }

            i = 0;
            while (i < face_to_try.vrot) : (i += 1) {
                dir = rotateVec4X_CCW(dir);
            }
        }
        const face_index = @enumToInt(Face.fromDirection(dir));
        if (face_is_set[face_index]) continue;
        switch (map.getPos(face_to_try.pos)) {
            '.', '#' => {},
            '1'...'6' => continue,
            else => continue,
        }
        faces[face_index] = .{
            .pos = face_to_try.pos,
            .grid = map.getRegion(face_to_try.pos, .{ face_size, face_size }),
        };
        face_is_set[face_index] = true;

        if (face_to_try.pos[0] > 0) {
            try next_face_to_try.append(.{
                .pos = @Vector(2, usize){ face_to_try.pos[0] - face_size, face_to_try.pos[1] },
                .vrot = face_to_try.vrot,
                .hrot = face_to_try.hrot -% 1,
            });
        }
        if (face_to_try.pos[0] + face_size < map.size[0]) {
            try next_face_to_try.append(.{
                .pos = @Vector(2, usize){ face_to_try.pos[0] + face_size, face_to_try.pos[1] },
                .vrot = face_to_try.vrot,
                .hrot = face_to_try.hrot +% 1,
            });
        }

        if (face_to_try.pos[1] > 0) {
            try next_face_to_try.append(.{
                .pos = @Vector(2, usize){ face_to_try.pos[0], face_to_try.pos[1] - face_size },
                .vrot = face_to_try.vrot -% 1,
                .hrot = face_to_try.hrot,
            });
        }
        if (face_to_try.pos[1] + face_size < map.size[1]) {
            try next_face_to_try.append(.{
                .pos = @Vector(2, usize){ face_to_try.pos[0], face_to_try.pos[1] + face_size },
                .vrot = face_to_try.vrot +% 1,
                .hrot = face_to_try.hrot,
            });
        }
    }

    return faces;
}

fn rotateVec4Z_CW(v: @Vector(4, i64)) @Vector(4, i64) {
    return .{ v[1], -v[0], v[2], v[3] };
}

fn rotateVec4Z_CCW(v: @Vector(4, i64)) @Vector(4, i64) {
    return .{ -v[1], v[0], v[2], v[3] };
}

fn rotateVec4Y_CW(v: @Vector(4, i64)) @Vector(4, i64) {
    return .{ v[2], v[1], -v[0], v[3] };
}

fn rotateVec4Y_CCW(v: @Vector(4, i64)) @Vector(4, i64) {
    return .{ -v[2], v[1], v[0], v[3] };
}

fn rotateVec4X_CW(v: @Vector(4, i64)) @Vector(4, i64) {
    return .{ v[0], v[2], -v[1], v[3] };
}

fn rotateVec4X_CCW(v: @Vector(4, i64)) @Vector(4, i64) {
    return .{ v[0], -v[2], v[1], v[3] };
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

test "challenge 2" {
    const output = try challenge2(std.testing.allocator, TEST_DATA);
    try std.testing.expectEqual(@as(i64, 5031), output);
}

test "find faces of TEST_DATA" {
    var data = try parseData(std.testing.allocator, TEST_DATA);
    defer data.map.free(std.testing.allocator);

    const faces = try findFaces(std.testing.allocator, data.map.asConst(), 4);
    for (faces) |face, index| {
        data.map.getRegion(face.pos, .{ 4, 4 }).set(@intCast(u8, '1' + index));
    }

    const expected = ConstGrid(u8){
        .data = 
        \\        1111    
        \\        1111    
        \\        1111    
        \\        1111    
        \\222233334444    
        \\222233334444    
        \\222233334444    
        \\222233334444    
        \\        55556666
        \\        55556666
        \\        55556666
        \\        55556666
        \\
        ,
        .stride = 17,
        .size = .{ 16, 12 },
    };
    var expected_rows = expected.iterateRows();
    var actual_rows = data.map.iterateRows();
    while (true) {
        const expected_row = expected_rows.next() orelse break;
        const actual_row = actual_rows.next().?;
        try std.testing.expectEqualSlices(u8, expected_row, actual_row);
    }
}

pub fn main() !void {
    const ctx = try util.Context.init(.{ .title = "Advent of Code - Day 21" });
    defer ctx.deinit();

    const stdout = std.io.getStdOut();

    const answer1 = try challenge1(ctx.allocator, DATA);
    try stdout.writer().print("{}\n", .{answer1});

    const answer2 = try challenge2(ctx.allocator, DATA);
    try stdout.writer().print("{}\n", .{answer2});
}
