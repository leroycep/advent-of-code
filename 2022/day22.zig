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

pub fn challenge2(allocator: std.mem.Allocator, input: []const u8, face_size: usize) !i64 {
    var data = try parseData(allocator, input);
    defer {
        data.map.free(allocator);
    }

    const cube = try findFaces(allocator, data.map.asConst(), face_size);

    var transform = Transform{
        .pos = @Vector(3, i64){ 0, 0, -1 },
        .direction = .{ 1, 0, 0 },
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
                    const next_pos = oneForward(face_size, transform);
                    const next_tile = cube.getPos(next_pos.pos);
                    switch (next_tile) {
                        '.' => transform = next_pos,
                        '#' => break,
                        else => unreachable,
                    }
                }
                number = 0;
                transform.direction = mat3.mulVec3(mat3.rotateAboutAxis(cube.getUpAxis(transform.pos)), transform.direction);
            },
            'R' => {
                var i: i64 = 0;
                while (i < number) : (i += 1) {
                    const next_pos = oneForward(face_size, transform);
                    const next_tile = cube.getPos(next_pos.pos);
                    switch (next_tile) {
                        '.' => transform = next_pos,
                        '#' => break,
                        else => unreachable,
                    }
                }
                number = 0;
                transform.direction = mat3.mulVec3(mat3.rotateAboutAxis(-cube.getUpAxis(transform.pos)), transform.direction);
            },
            else => return error.InvalidFormat,
        }
    }
    var i: i64 = 0;
    while (i < number) : (i += 1) {
        const next_pos = oneForward(face_size, transform);
        const next_tile = cube.getPos(next_pos.pos);
        switch (next_tile) {
            '.' => transform = next_pos,
            '#' => break,
            else => unreachable,
        }
    }
    number = 0;

    const map_pos = cube.posOnMap(transform.pos);
    const rotation = cube.transformToRotation(transform);

    return (@intCast(i64, map_pos[1]) + 1) * 1000 + (@intCast(i64, map_pos[0]) + 1) * 4 + rotation;
}

const Transform = struct {
    pos: @Vector(3, i64),
    direction: @Vector(3, i64),
};

fn oneForward(face_size_u: usize, transform: Transform) Transform {
    const face_size = @intCast(i64, face_size_u);

    // should only go off one direction at a time
    const up_mask = @mod(transform.pos, @splat(3, face_size + 1)) >= @splat(3, face_size);
    const horizontal_mask = @mod(transform.pos, @splat(3, face_size + 1)) < @splat(3, face_size);

    const up = @select(i64, up_mask, std.math.sign(transform.pos), .{ 0, 0, 0 });

    var next_pos = transform.pos + transform.direction;
    var next_direction = transform.direction;
    if (@reduce(.Or, @select(i64, horizontal_mask, next_pos, .{ 0, 0, 0 }) < @Vector(3, i64){ 0, 0, 0 }) or @reduce(.Or, @select(i64, horizontal_mask, next_pos, .{ 0, 0, 0 }) >= @splat(3, face_size))) {
        next_pos -= up;
        next_direction = -up;
    }

    return Transform{
        .pos = next_pos,
        .direction = next_direction,
    };
}

test oneForward {
    try std.testing.expectEqual(Transform{ .pos = .{ 0, -1, 3 }, .direction = .{ 0, 0, -1 } }, oneForward(4, .{ .pos = .{ 0, 0, 4 }, .direction = .{ 0, -1, 0 } }));
    try std.testing.expectEqual(Transform{ .pos = .{ 4, 0, 1 }, .direction = .{ 0, 1, 0 } }, oneForward(4, .{ .pos = .{ 3, -1, 1 }, .direction = .{ 1, 0, 0 } }));
    try std.testing.expectEqual(Transform{ .pos = .{ -1, 3, 2 }, .direction = .{ 0, -1, 0 } }, oneForward(4, .{ .pos = .{ 0, 4, 2 }, .direction = .{ -1, 0, 0 } }));
    try std.testing.expectEqual(Transform{ .pos = .{ 0, 4, 2 }, .direction = .{ 1, 0, 0 } }, oneForward(4, .{ .pos = .{ -1, 3, 2 }, .direction = .{ 0, 1, 0 } }));
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
    switch (dir[0]) {
        -1 => switch (dir[1]) {
            0 => return 2,
            else => {},
        },
        0 => switch (dir[1]) {
            -1 => return 3,
            1 => return 1,
            else => {},
        },
        1 => switch (dir[1]) {
            0 => return 0,
            else => {},
        },
        else => {},
    }
    std.debug.panic("Not a valid direction: {}", .{dir});
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
            std.debug.panic("Not a valid face direction: {any}", .{dir});
        }
    }
};

const Cube = struct {
    face_size: usize,
    pos: [6]@Vector(2, usize),
    grids: [6]ConstGrid(u8),
    rot: [6][2]u2,

    fn getUpAxis(this: @This(), pos: @Vector(3, i64)) @Vector(3, i64) {
        const face_size = @intCast(i64, this.face_size);
        const up_mask = @mod(pos, @splat(3, face_size + 1)) >= @splat(3, face_size);
        if (!@reduce(.Or, up_mask)) {
            std.debug.panic("Invalid position on cube! {}", .{pos});
        }
        return @select(i64, up_mask, std.math.sign(pos), .{ 0, 0, 0 });
    }

    fn faceAndSubGridPos(this: @This(), pos: @Vector(3, i64)) @Vector(3, usize) {
        const face_size = @intCast(i64, this.face_size);
        const up = this.getUpAxis(pos);
        const face = Face.fromDirection(up);

        const right = rotateVec3ByRot2(.{ 1, 0, 0 }, this.rot[@enumToInt(face)]);
        const down = rotateVec3ByRot2(.{ 0, 1, 0 }, this.rot[@enumToInt(face)]);

        const sub_right: i64 = if (@reduce(.Add, right) < 0) 1 else 0;
        const sub_down: i64 = if (@reduce(.Add, down) < 0) 1 else 0;

        return .{
            @enumToInt(face),
            @intCast(usize, @mod(@reduce(.Add, pos * right) - sub_right + face_size, face_size)),
            @intCast(usize, @mod(@reduce(.Add, pos * down) - sub_down + face_size, face_size)),
        };
    }

    fn transformToRotation(this: @This(), transform: Transform) u2 {
        const face = Face.fromDirection(this.getUpAxis(transform.pos));

        const right = rotateVec3ByRot2(.{ 1, 0, 0 }, this.rot[@enumToInt(face)]);
        const down = rotateVec3ByRot2(.{ 0, 1, 0 }, this.rot[@enumToInt(face)]);

        return vec2ToRotation(.{
            @reduce(.Add, transform.direction * right),
            @reduce(.Add, transform.direction * down),
        });
    }

    fn posOnMap(this: @This(), pos: @Vector(3, i64)) @Vector(2, usize) {
        const face_and_subgrid_pos = this.faceAndSubGridPos(pos);
        return this.pos[face_and_subgrid_pos[0]] + @Vector(2, usize){
            face_and_subgrid_pos[1],
            face_and_subgrid_pos[2],
        };
    }

    fn getPos(this: @This(), pos: @Vector(3, i64)) u8 {
        const face_and_subgrid_pos = this.faceAndSubGridPos(pos);
        return this.grids[face_and_subgrid_pos[0]].getPos(@Vector(2, usize){
            face_and_subgrid_pos[1],
            face_and_subgrid_pos[2],
        });
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

    for (face_is_set) |f| {
        if (!f) return error.InvalidFormat;
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
    const output = try challenge2(std.testing.allocator, TEST_DATA, 4);
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

    try std.testing.expectEqual(@as(u8, '.'), cube.getPos(.{ 4, 0, 0 }));
    try std.testing.expectEqual(@as(u8, '.'), cube.getPos(.{ 4, 3, 0 }));
    try std.testing.expectEqual(@as(u8, '#'), cube.getPos(.{ 4, 0, 1 }));
    try std.testing.expectEqual(@as(u8, '#'), cube.getPos(.{ 4, 2, 2 }));
}

pub fn main() !void {
    const ctx = try util.Context.init(.{ .title = "Advent of Code - Day 21" });
    defer ctx.deinit();

    const stdout = std.io.getStdOut();

    const answer1 = try challenge1(ctx.allocator, DATA);
    try stdout.writer().print("{}\n", .{answer1});

    const answer2 = try challenge2(ctx.allocator, DATA, 50);
    try stdout.writer().print("{}\n", .{answer2});

    var data = try parseData(ctx.allocator, TEST_DATA);
    defer data.map.free(ctx.allocator);

    const face_size = 4;
    const cube = try findFaces(ctx.allocator, data.map.asConst(), 4);

    var cube_image = ColormappedGrid.init(ctx.vg, data.map.asConst(), .{});
    defer cube_image.deinit();

    var transform = Transform{
        .pos = @Vector(3, i64){ 0, 0, -1 },
        .direction = .{ 1, 0, 0 },
    };
    var path = std.ArrayList(Transform).init(ctx.allocator);
    defer path.deinit();

    var directions_index: usize = 0;
    var forward_steps_left: i64 = 0;
    var turn: i2 = 0;
    var number: i64 = 0;

    while (!ctx.window.shouldClose()) {
        if (turn == 0 and directions_index < data.directions.len) {
            defer directions_index += 1;
            const character = data.directions[directions_index];
            switch (character) {
                '0'...'9' => {
                    number *= 10;
                    number += character - '0';
                },
                'L' => {
                    forward_steps_left = number;
                    turn = -1;
                    number = 0;
                },
                'R' => {
                    forward_steps_left = number;
                    turn = 1;
                    number = 0;
                },
                else => return error.InvalidFormat,
            }
        }

        if (forward_steps_left > 0) {
            forward_steps_left -= 1;
            const next_pos = oneForward(face_size, transform);
            const next_tile = cube.getPos(next_pos.pos);
            switch (next_tile) {
                '.' => {
                    try path.append(transform);
                    transform = next_pos;
                },
                '#' => {},
                else => unreachable,
            }
        } else {
            switch (turn) {
                0 => {},
                -1 => {
                    transform.direction = mat3.mulVec3(mat3.rotateAboutAxis(cube.getUpAxis(transform.pos)), transform.direction);
                },
                1 => {
                    transform.direction = mat3.mulVec3(mat3.rotateAboutAxis(-cube.getUpAxis(transform.pos)), transform.direction);
                },
                else => unreachable,
            }
            turn = 0;
        }

        try ctx.beginFrame();

        const window_size = try ctx.window.getSize();
        const tile_scale = std.math.floor(std.math.max(1, std.math.min(
            @intToFloat(f32, window_size.width) / @intToFloat(f32, data.map.size[0]),
            @intToFloat(f32, window_size.height) / @intToFloat(f32, data.map.size[1]),
        )));

        const map_size = @splat(2, tile_scale) * vectorIntToFloat(2, f32, data.map.size);

        cube_image.drawRegion(.{ 0, 0 }, map_size, .{ 0, 0 }, data.map.size);

        for (path.items) |step| {
            const pos_on_map = @splat(2, tile_scale) * (vectorIntToFloat(2, f32, cube.posOnMap(step.pos)) + @splat(2, @as(f32, 0.5)));
            ctx.vg.beginPath();
            ctx.vg.circle(pos_on_map[0], pos_on_map[1], tile_scale * 0.25);
            ctx.vg.strokeColor(intToColor(0xFF0000FF));
            ctx.vg.stroke();
        }

        ctx.vg.beginPath();
        ctx.vg.moveTo(0, 0);
        for (path.items) |step| {
            const pos_on_map = @splat(2, tile_scale) * (vectorIntToFloat(2, f32, cube.posOnMap(step.pos)) + @splat(2, @as(f32, 0.5)));
            ctx.vg.lineTo(pos_on_map[0], pos_on_map[1]);
        }
        ctx.vg.strokeColor(intToColor(0x00FF00FF));
        ctx.vg.stroke();

        for (path.items) |step, step_index| {
            var buf: [64]u8 = undefined;
            const text = try std.fmt.bufPrint(&buf, "{}\n{}\n{}", .{ step_index, step.pos, step.direction });

            const pos_on_map = cube.posOnMap(step.pos);
            const offset: @Vector(2, f32) = if (pos_on_map[0] % 2 == 0) .{ 0.5, 0.25 } else .{ 0.5, 0.75 };
            const render_pos = @splat(2, tile_scale) * (vectorIntToFloat(2, f32, pos_on_map) + offset);

            ctx.vg.beginPath();
            ctx.vg.fontFace("sans");
            ctx.vg.fillColor(intToColor(0xFFFFFFFF));
            ctx.vg.textAlign(.{ .horizontal = .center, .vertical = .middle });
            _ = ctx.vg.textBox(render_pos[0], render_pos[1], tile_scale, text);
        }

        try ctx.endFrame();
    }

    try ctx.flush();
}

fn intToColor(int: u32) nanovg.Color {
    return .{
        .r = @intToFloat(f32, (int & 0xFF_000000) >> 24) / 0xFF,
        .g = @intToFloat(f32, (int & 0x00_FF_0000) >> 16) / 0xFF,
        .b = @intToFloat(f32, (int & 0x0000_FF_00) >> 8) / 0xFF,
        .a = @intToFloat(f32, (int & 0x000000_FF)) / 0xFF,
    };
}

fn vectorIntToFloat(comptime len: comptime_int, comptime F: type, veci: anytype) @Vector(len, F) {
    return .{
        @intToFloat(F, veci[0]),
        @intToFloat(F, veci[1]),
    };
}

const ColormappedGrid = struct {
    vg: nanovg,
    colormap: nanovg.Image,
    grid: ConstGrid(u8),
    grid_image: nanovg.Image,

    const Options = struct {
        palette: []const [4]u8 = &DEFAULT_PALETTE,
    };

    const DEFAULT_PALETTE = generate_palette: {
        var palette: [256][4]u8 = undefined;
        palette[0] = .{ 0, 0, 0, 0 };
        // ROY G BIV
        palette[1] = .{ 0xFF, 0xFF, 0xFF, 0xFF };
        palette[2] = .{ 0xFF, 0x00, 0x00, 0xFF };
        palette[3] = .{ 0xFF, 0xAA, 0x00, 0xFF };
        palette[4] = .{ 0xFF, 0xFF, 0x00, 0xFF };
        palette[5] = .{ 0x00, 0xFF, 0x00, 0xFF };
        palette[6] = .{ 0x00, 0x00, 0xFF, 0xFF };
        palette[7] = .{ 0x4B, 0x00, 0x82, 0xFF };
        palette[8] = .{ 0x80, 0x00, 0xFF, 0xFF };
        palette['#'] = .{ 0xFF, 0xFF, 0xFF, 0xFF };
        palette['.'] = .{ 0xAA, 0xAA, 0xAA, 0xFF };
        palette[' '] = .{ 0x00, 0x00, 0x00, 0xFF };
        break :generate_palette palette;
    };

    fn init(vg: nanovg, grid: ConstGrid(u8), options: Options) @This() {
        const colormap = vg.createImageRGBA(@intCast(u32, options.palette.len), 1, .{ .nearest = true }, std.mem.sliceAsBytes(options.palette));

        const grid_image = vg.createImageAlpha(
            @intCast(u32, grid.stride),
            @intCast(u32, grid.size[1]),
            .{ .nearest = true },
            std.mem.sliceAsBytes(grid.data),
        );

        return @This(){
            .vg = vg,
            .colormap = colormap,
            .grid = grid,
            .grid_image = grid_image,
        };
    }

    fn updateImage(this: *@This(), grid: ConstGrid(u8)) void {
        std.debug.assert(grid.stride == this.grid.stride);
        std.debug.assert(std.mem.eql(usize, &this.grid.size, &grid.size));
        this.vg.updateImage(this.grid_image, std.mem.sliceAsBytes(grid.data));
        this.grid = grid;
    }

    fn deinit(this: *@This()) void {
        this.vg.deleteImage(this.colormap);
        this.vg.deleteImage(this.grid_image);
    }

    pub fn draw(this: @This(), offset: @Vector(2, f32), size: @Vector(2, f32)) void {
        this.drawRegion(offset, size, .{ 0, 0 }, this.grid.size);
    }

    pub fn drawRegion(this: @This(), offset: @Vector(2, f32), size: @Vector(2, f32), regionPos: [2]usize, regionSize: [2]usize) void {
        this.vg.beginPath();
        this.vg.rect(offset[0], offset[1], size[0], size[1]);
        const image_size = .{
            size[0] * @intToFloat(f32, this.grid.stride) / @intToFloat(f32, regionSize[0]),
            size[1] * @intToFloat(f32, this.grid.size[1]) / @intToFloat(f32, regionSize[1]),
        };
        const image_offset = .{
            size[0] * @intToFloat(f32, regionPos[0]) / @intToFloat(f32, regionSize[0]),
            size[1] * @intToFloat(f32, regionPos[1]) / @intToFloat(f32, regionSize[1]),
        };
        this.vg.fillPaint(this.vg.indexedImagePattern(
            offset[0] - image_offset[0],
            offset[1] - image_offset[1],
            image_size[0],
            image_size[1],
            0,
            this.grid_image,
            this.colormap,
            1,
        ));
        this.vg.fill();
    }
};
