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
    var rotation: u2 = 0;

    var number: i64 = 0;
    for (data.directions) |character| {
        switch (character) {
            '0'...'9' => {
                number *= 10;
                number += character - '0';
            },
            'L' => {
                pos = moveNTimes(data.map.asConst(), pos, rotation, number);
                rotation -%= 1;
                number = 0;
            },
            'R' => {
                pos = moveNTimes(data.map.asConst(), pos, rotation, number);
                rotation +%= 1;
                number = 0;
            },
            else => return error.InvalidFormat,
        }
    }
    pos = moveNTimes(data.map.asConst(), pos, rotation, number);
    number = 0;

    return (pos[1] + 1) * 1000 + (pos[0] + 1) * 4 + rotation;
}

fn moveNTimes(map: ConstGrid(u8), pos: @Vector(2, i64), rotation: u2, n: i64) @Vector(2, i64) {
    const dir = rotationToVec2(rotation);
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

    const face_size = data.map.size[0];
    var transform = Transform{
        .pos = @Vector(3, i64){ 0, 0, -1 },
        .rotation = 0,
    };

    var number: i64 = 0;
    for (data.directions) |character| {
        switch (character) {
            '0'...'9' => {
                number *= 10;
                number += character - '0';
            },
            'L' => {
                var i: i64 = 0;
                while (i < number) : (i += 1) {
                    transform = oneForward(face_size, transform);
                }
                number = 0;
                transform.rotation -%= 1;
            },
            'R' => {
                var i: i64 = 0;
                while (i < number) : (i += 1) {
                    transform = oneForward(face_size, transform);
                }
                number = 0;
                transform.rotation +%= 1;
            },
            else => return error.InvalidFormat,
        }
    }
    number = 0;

    return (transform.pos[1] + 1) * 1000 + (transform.pos[0] + 1) * 4 + transform.rotation;
}

const Transform = struct {
    pos: @Vector(3, i64),
    rotation: u2,
};

fn oneForward(face_size_u: usize, transform: Transform) Transform {
    const face_size = @intCast(i64, face_size_u);

    // should only go off one direction at a time
    const up_mask = @mod(transform.pos, @splat(3, face_size + 1)) >= @splat(3, face_size);
    const horizontal_mask = @mod(transform.pos, @splat(3, face_size + 1)) < @splat(3, face_size);

    const up = @select(i64, up_mask, std.math.sign(transform.pos), .{ 0, 0, 0 });
    const right: @Vector(3, i64) = if (transform.pos[0] < 0) .{ 0, 0, -1 } else if (transform.pos[0] > face_size) .{ 0, 0, 1 } else .{ 1, 0, 0 };

    var dir = right;
    {
        var i: i64 = 0;
        while (i < transform.rotation) : (i += 1) {
            dir = mat3.mulVec3(mat3.rotateAboutAxis(up), dir);
        }
    }

    var next_pos = transform.pos + dir;
    if (@reduce(.Or, @select(i64, horizontal_mask, next_pos, .{ 0, 0, 0 }) < @Vector(3, i64){ 0, 0, 0 })) {
        next_pos -= up;
    } else if (@reduce(.Or, @select(i64, horizontal_mask, next_pos, .{ 0, 0, 0 }) >= @splat(3, face_size))) {
        next_pos += up;
    }

    return Transform{
        .pos = next_pos,
        .rotation = transform.rotation,
    };
}

test oneForward {
    const actual = oneForward(4, .{
        .pos = .{ 0, 0, 4 },
        .rotation = 3,
    });
    const expected = Transform{ .pos = .{ 0, -1, 3 }, .rotation = 3 };
    try std.testing.expectEqual(expected.pos, actual.pos);
    try std.testing.expectEqual(expected.rotation, actual.rotation);
}

fn vec2ToVec3(vec2: @Vector(2, i64)) @Vector(3, i64) {
    return @Vector(3, i64){ vec2[0], vec2[1], 0 };
}

fn rotationToVec2(rot: u2) @Vector(2, i64) {
    return switch (rot) {
        0 => .{ 1, 0 },
        1 => .{ 0, 1 },
        2 => .{ -1, 0 },
        3 => .{ 0, -1 },
    };
}

fn vec2ToRotation(dir: @Vector(2, i64)) u2 {
    return switch (dir[0]) {
        -1 => switch (dir[1]) {
            0 => 2,
            else => unreachable,
        },
        0 => switch (dir[1]) {
            -1 => 3,
            1 => 1,
            else => unreachable,
        },
        1 => switch (dir[1]) {
            0 => 0,
            else => unreachable,
        },
        else => unreachable,
    };
}

fn rot2ToVec3(rot: @Vector(2, u2)) @Vector(3, i64) {
    return rotateVec3ByRot2(@Vector(3, i64){ 0, 0, -1 }, rot);
}

fn rotateVec3ByRot2(vec3: @Vector(3, i64), rot: @Vector(2, u2)) @Vector(3, i64) {
    var result = vec3;
    {
        var i: u2 = 0;
        while (i < rot[0]) : (i += 1) {
            result = mat3.mulVec3(mat3.ROTATE_Y_CCW, result);
        }

        i = 0;
        while (i < rot[1]) : (i += 1) {
            result = mat3.mulVec3(mat3.ROTATE_X_CCW, result);
        }
    }
    return result;
}

fn rotU2AddI2(a_u2: @Vector(2, u2), b_i2: @Vector(2, i2)) @Vector(2, u2) {
    const a_i4 = @as(@Vector(2, i4), a_u2);
    const b_i4 = @as(@Vector(2, i4), b_i2);
    const rot_max = @Vector(2, i4){ 4, 4 };
    const result_i4 = @mod(a_i4 +% b_i4 +% rot_max, rot_max);
    return .{
        @intCast(u2, result_i4[0]),
        @intCast(u2, result_i4[1]),
    };
}

const Face = enum(u8) {
    front = 0,
    top = 1,
    left = 2,
    bottom = 3,
    back = 4,
    right = 5,

    fn fromRotation(rot: @Vector(2, u2)) @This() {
        return fromDirection(rot2ToVec3(rot));
    }

    fn fromDirection(dir: [3]i64) @This() {
        if (std.mem.eql(i64, &.{ 0, 0, -1 }, &dir)) {
            return .front;
        } else if (std.mem.eql(i64, &.{ 0, 0, 1 }, &dir)) {
            return .back;
        } else if (std.mem.eql(i64, &.{ 0, -1, 0 }, &dir)) {
            return .top;
        } else if (std.mem.eql(i64, &.{ 0, 1, 0 }, &dir)) {
            return .bottom;
        } else if (std.mem.eql(i64, &.{ -1, 0, 0 }, &dir)) {
            return .left;
        } else if (std.mem.eql(i64, &.{ 1, 0, 0 }, &dir)) {
            return .right;
        } else {
            unreachable;
        }
    }
};

const Cube = struct {
    face_size: usize,
    pos: [6]@Vector(2, usize),
    grids: [6]ConstGrid(u8),
    rot: [6][2]u2,

    fn getPos(this: @This(), pos: @Vector(3, i64)) u8 {
        const face_size = @intCast(i64, this.face_size);
        const up_mask = @mod(pos, @splat(3, face_size + 1)) >= @splat(3, face_size);
        const up = @select(i64, up_mask, std.math.sign(pos), .{ 0, 0, 0 });
        const face = Face.fromDirection(up);
        std.debug.print("up {}\n", .{up});

        const right = rotateVec3ByRot2(.{ 1, 0, 0 }, this.rot[@enumToInt(face)]);
        const down = rotateVec3ByRot2(.{ 0, 1, 0 }, this.rot[@enumToInt(face)]);

        const grid_pos = @Vector(2, usize){
            @intCast(usize, @reduce(.Add, pos * right)),
            @intCast(usize, @reduce(.Add, pos * down)),
        };

        return this.grids[@enumToInt(face)].getPos(grid_pos);
    }
};

fn findFaces(allocator: std.mem.Allocator, map: ConstGrid(u8), face_size: usize) !Cube {
    var cube: Cube = undefined;
    cube.face_size = face_size;

    var face_is_set: [6]bool = undefined;
    std.mem.set(bool, &face_is_set, false);

    const FaceToTry = struct {
        pos: @Vector(2, usize),
        rot: @Vector(2, u2),
    };

    var next_face_to_try = std.ArrayList(FaceToTry).init(allocator);
    defer next_face_to_try.deinit();

    try next_face_to_try.append(.{
        .pos = .{ std.mem.indexOf(u8, map.data, ".").?, 0 },
        .rot = .{ 0, 0 },
    });

    while (next_face_to_try.popOrNull()) |face_to_try| {
        const face_index = @enumToInt(Face.fromRotation(face_to_try.rot));
        if (face_is_set[face_index]) continue;
        switch (map.getPos(face_to_try.pos)) {
            '.', '#' => {},
            '1'...'6' => continue,
            else => continue,
        }
        cube.pos[face_index] = face_to_try.pos;
        cube.grids[face_index] = map.getRegion(face_to_try.pos, .{ face_size, face_size });
        cube.rot[face_index] = face_to_try.rot;

        face_is_set[face_index] = true;

        if (face_to_try.pos[0] > 0) {
            try next_face_to_try.append(.{
                .pos = @Vector(2, usize){ face_to_try.pos[0] - face_size, face_to_try.pos[1] },
                .rot = face_to_try.rot -% @Vector(2, u2){ 1, 0 },
            });
        }
        if (face_to_try.pos[0] + face_size < map.size[0]) {
            try next_face_to_try.append(.{
                .pos = @Vector(2, usize){ face_to_try.pos[0] + face_size, face_to_try.pos[1] },
                .rot = face_to_try.rot +% @Vector(2, u2){ 1, 0 },
            });
        }

        if (face_to_try.pos[1] > 0) {
            try next_face_to_try.append(.{
                .pos = @Vector(2, usize){ face_to_try.pos[0], face_to_try.pos[1] - face_size },
                .rot = face_to_try.rot -% @Vector(2, u2){ 0, 1 },
            });
        }
        if (face_to_try.pos[1] + face_size < map.size[1]) {
            try next_face_to_try.append(.{
                .pos = @Vector(2, usize){ face_to_try.pos[0], face_to_try.pos[1] + face_size },
                .rot = face_to_try.rot +% @Vector(2, u2){ 0, 1 },
            });
        }
    }

    return cube;
}

const mat3 = struct {
    const ROTATE_Z_CW = [3]@Vector(3, i64){
        .{ 0, 1, 0 },
        .{ -1, 0, 0 },
        .{ 0, 0, 1 },
    };
    const ROTATE_Z_CCW = [3]@Vector(3, i64){
        .{ 0, -1, 0 },
        .{ 1, 0, 0 },
        .{ 0, 0, 1 },
    };
    const ROTATE_Y_CW = [3]@Vector(3, i64){
        .{ 0, 0, 1 },
        .{ 0, 1, 0 },
        .{ -1, 0, 0 },
    };
    const ROTATE_Y_CCW = [3]@Vector(3, i64){
        .{ 0, 0, -1 },
        .{ 0, 1, 0 },
        .{ 1, 0, 0 },
    };

    const ROTATE_X_CW = [3]@Vector(3, i64){
        .{ 1, 0, 0 },
        .{ 0, 0, 1 },
        .{ 0, -1, 0 },
    };
    const ROTATE_X_CCW = [3]@Vector(3, i64){
        .{ 1, 0, 0 },
        .{ 0, 0, -1 },
        .{ 0, 1, 0 },
    };

    pub fn mulVec3(matrix: [3]@Vector(3, i64), vec3: @Vector(3, i64)) @Vector(3, i64) {
        var result: [3]i64 = undefined;
        for (result) |*elem, i| {
            elem.* = @reduce(.Add, vec3 * matrix[i]);
        }
        return result;
    }

    pub fn rotateAboutAxis(u: @Vector(3, i64)) [3]@Vector(3, i64) {
        return .{
            .{ 0, -u[2], u[1] },
            .{ u[2], 0, -u[0] },
            .{ -u[1], u[0], 0 },
        };
    }
};

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

    const cube = try findFaces(std.testing.allocator, data.map.asConst(), 4);
    for (cube.pos) |face_pos, index| {
        data.map.getRegion(face_pos, .{ 4, 4 }).set(@intCast(u8, '1' + index));
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

test "get positions on cube" {
    var data = try parseData(std.testing.allocator, TEST_DATA);
    defer data.map.free(std.testing.allocator);

    const cube = try findFaces(std.testing.allocator, data.map.asConst(), 4);

    try std.testing.expectEqual(@as(u8, '.'), cube.getPos(.{ 0, 0, -1 }));
    try std.testing.expectEqual(@as(u8, '#'), cube.getPos(.{ 3, 0, -1 }));
    try std.testing.expectEqual(@as(u8, '#'), cube.getPos(.{ 1, 1, -1 }));
    try std.testing.expectEqual(@as(u8, '#'), cube.getPos(.{ 3, 4, 0 }));
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
