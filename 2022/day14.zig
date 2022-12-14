const std = @import("std");

const DATA = @embedFile("data/day14.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(arena.allocator(), DATA)});
    try out.print("{}\n", .{try challenge2(arena.allocator(), DATA)});
}

pub fn challenge1(allocator: std.mem.Allocator, input: []const u8) !u64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    std.debug.print("input = {s}\n", .{input});
    var map = try inputToMap(arena.allocator(), input);
    var map_out = try map.clone(arena.allocator());

    const stderr = std.io.getStdErr();

    while (true) {
        switch (mapStepSand(map, &map_out)) {
            .static => {
                try map_out.print(stderr.writer());
                try stderr.writeAll("\n");

                var num_sand_sources: usize = 0;
                for (map.tiles) |tile_in, tile_index| {
                    if (tile_in == '+') {
                        num_sand_sources += 1;

                        const pos = @Vector(2, i64){ @intCast(i64, tile_index % map.width), @intCast(i64, tile_index / map.width) };
                        const one_tile_down = pos + @Vector(2, i64){ 0, 1 };

                        if (map.get(one_tile_down) == '.') {
                            map_out.set(one_tile_down, 'o');
                        } else {
                            break;
                        }
                    }
                }
                if (num_sand_sources == 0) {
                    return error.NoSandSources;
                }
            },
            .sand_fell => {},
            .sand_fell_into_darkness => {
                std.mem.swap(Map, &map, &map_out);
                try map_out.print(stderr.writer());
                try stderr.writeAll("\n");
                break;
            },
        }

        std.mem.swap(Map, &map, &map_out);
    }

    return std.mem.count(u8, map.tiles, "o");
}

pub fn challenge2(allocator: std.mem.Allocator, input: []const u8) !u64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var min = @Vector(2, i64){ 500, 0 };
    var max = @Vector(2, i64){ 500, 0 };
    var rock_paths = std.ArrayList([][2]i64).init(arena.allocator());
    var lines_iterator = std.mem.split(u8, input, "\n");
    while (lines_iterator.next()) |line| {
        if (line.len == 0) continue;
        const path = try parseRockPath(arena.allocator(), line);
        for (path) |segment| {
            min = @minimum(min, @as(@Vector(2, i64), segment));
            max = @maximum(max, @as(@Vector(2, i64), segment));
        }
        try rock_paths.append(path);
    }

    // add an "infinite" floor
    try rock_paths.append(&.{ .{ min[0] - max[1], max[1] + 2 }, .{ max[0] + max[1], max[1] + 2 } });

    var map = try rockPathsToMap(arena.allocator(), rock_paths.items);

    const stderr = std.io.getStdErr();

    while (true) {
        // Start sand at 500, 0
        var pos = @Vector(2, i64){ 500, 0 };
        switch (map.get(pos - map.offset)) {
            '.', '+' => {},
            'o' => break,
            else => {},
        }

        const POTENTIAL_MOVES = [_][2]i64{
            .{ 0, 1 },
            .{ -1, 1 },
            .{ 1, 1 },
        };
        // Move sand down
        move_one_unit: while (true) {
            for (POTENTIAL_MOVES) |move_offset| {
                const new_pos = pos + move_offset;
                const new_pos_offset = new_pos - map.offset;
                if (@reduce(.Or, new_pos_offset < @splat(2, @as(i64, 0))) or @reduce(.Or, new_pos_offset >= map.size())) {
                    return error.SandOutOfBounds;
                }

                switch (map.get(new_pos_offset)) {
                    '.', '+' => {
                        pos = new_pos;
                        break;
                    },
                    else => {},
                }
            } else {
                break :move_one_unit;
            }
        }

        map.set(pos - map.offset, 'o');
    }

    try map.print(stderr.writer());
    try stderr.writeAll("\n");

    return std.mem.count(u8, map.tiles, "o");
}

pub const StepResult = enum {
    static,
    sand_fell,
    sand_fell_into_darkness,
};

fn mapStepSand(map_in: Map, map_out: *Map) StepResult {
    std.mem.set(u8, map_out.tiles, '.');
    // Copy over static objects
    for (map_in.tiles) |tile_in, tile_index| {
        switch (tile_in) {
            '#', '+' => |c| map_out.tiles[tile_index] = c,
            else => {},
        }
    }

    const size = map_in.size();

    // Update sand units
    var moved_sand = false;
    var sand_fell_into_darkness = false;
    for (map_in.tiles) |tile_in, tile_index| {
        if (tile_in == 'o') {
            const pos = @Vector(2, i64){ @intCast(i64, tile_index % map_in.width), @intCast(i64, tile_index / map_in.width) };
            const one_tile_down = pos + @Vector(2, i64){ 0, 1 };
            const one_tile_down_left = pos + @Vector(2, i64){ -1, 1 };
            const one_tile_down_right = pos + @Vector(2, i64){ 1, 1 };

            if (one_tile_down[1] >= size[1]) {
                sand_fell_into_darkness = true;
                continue;
            }
            if (map_in.get(one_tile_down) == '.') {
                moved_sand = true;
                map_out.set(one_tile_down, 'o');
            } else if (one_tile_down_left[0] < 0 or one_tile_down_left[1] >= size[1]) {
                moved_sand = true;
                sand_fell_into_darkness = true;
            } else if (map_in.get(one_tile_down_left) == '.') {
                moved_sand = true;
                map_out.set(one_tile_down_left, 'o');
            } else if (one_tile_down_right[0] < 0 or one_tile_down_right[1] >= size[1]) {
                moved_sand = true;
                sand_fell_into_darkness = true;
            } else if (map_in.get(one_tile_down_right) == '.') {
                moved_sand = true;
                map_out.set(one_tile_down_right, 'o');
            } else {
                // in a stable spot, just copy it over
                map_out.set(pos, 'o');
            }
        }
    }

    if (sand_fell_into_darkness) {
        return .sand_fell_into_darkness;
    } else if (moved_sand) {
        return .sand_fell;
    } else {
        return .static;
    }
}

fn inputToMap(allocator: std.mem.Allocator, input: []const u8) !Map {
    var rock_paths = std.ArrayList([][2]i64).init(allocator);
    var lines_iterator = std.mem.split(u8, input, "\n");
    while (lines_iterator.next()) |line| {
        if (line.len == 0) continue;
        try rock_paths.append(try parseRockPath(allocator, line));
    }

    const map = try rockPathsToMap(allocator, rock_paths.items);

    return map;
}

const TEST_DATA =
    \\498,4 -> 498,6 -> 496,6
    \\503,4 -> 502,4 -> 502,9 -> 494,9
    \\
;

test challenge1 {
    const output = try challenge1(std.testing.allocator, TEST_DATA);
    try std.testing.expectEqual(@as(u64, 24), output);
}

test challenge2 {
    const output = try challenge2(std.testing.allocator, TEST_DATA);
    try std.testing.expectEqual(@as(u64, 93), output);
}

fn parseRockPath(allocator: std.mem.Allocator, input: []const u8) ![][2]i64 {
    var path = std.ArrayList([2]i64).init(allocator);
    defer path.deinit();

    var segment_iter = std.mem.split(u8, input, "->");
    while (segment_iter.next()) |segment_text| {
        if (segment_text.len == 0) continue;
        var coordinate_iterator = std.mem.tokenize(u8, segment_text, ", ");
        const x = try std.fmt.parseInt(i64, coordinate_iterator.next() orelse return error.InvalidFormat, 10);
        const y = try std.fmt.parseInt(i64, coordinate_iterator.next() orelse return error.InvalidFormat, 10);
        try path.append(.{ x, y });
    }

    return path.toOwnedSlice();
}

test parseRockPath {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectEqualSlices([2]i64, &.{ .{ 498, 4 }, .{ 498, 6 }, .{ 496, 6 } }, try parseRockPath(arena.allocator(), "498,4 -> 498,6 -> 496,6"));
    try std.testing.expectEqualSlices([2]i64, &.{ .{ 503, 4 }, .{ 502, 4 }, .{ 502, 9 }, .{ 494, 9 } }, try parseRockPath(arena.allocator(), "503,4 -> 502,4 -> 502,9 -> 494,9"));
}

const Map = struct {
    allocator: std.mem.Allocator,
    offset: [2]i64 = .{ 0, 0 },
    tiles: []u8,
    width: usize,

    pub fn init(allocator: std.mem.Allocator, map_size: [2]i64) !@This() {
        const tiles = try allocator.alloc(u8, @intCast(usize, map_size[0] * map_size[1]));
        return @This(){
            .allocator = allocator,
            .tiles = tiles,
            .width = @intCast(usize, map_size[0]),
        };
    }

    pub fn clone(this: @This(), allocator: std.mem.Allocator) !@This() {
        const tiles = try allocator.dupe(u8, this.tiles);
        return @This(){
            .allocator = allocator,
            .offset = this.offset,
            .tiles = tiles,
            .width = this.width,
        };
    }

    pub fn deinit(this: @This()) void {
        this.allocator.free(this.tiles);
    }

    pub fn size(this: @This()) [2]i64 {
        return .{ @intCast(i64, this.width), @intCast(i64, this.tiles.len / this.width) };
    }

    pub fn get(this: @This(), pos: [2]i64) u8 {
        return this.tiles[@intCast(usize, pos[1]) * this.width + @intCast(usize, pos[0])];
    }

    pub fn set(this: *@This(), pos: [2]i64, value: u8) void {
        this.tiles[@intCast(usize, pos[1]) * this.width + @intCast(usize, pos[0])] = value;
    }

    fn print(this: @This(), output: anytype) !void {
        var i: usize = 0;
        while (i < this.tiles.len) : (i += this.width) {
            try output.writeAll(this.tiles[i..][0..this.width]);
            try output.writeAll("\n");
        }
    }
};

fn rockPathsToMap(allocator: std.mem.Allocator, rock_paths: []const []const [2]i64) !Map {
    var min = @Vector(2, i64){ 500, 0 };
    var max = @Vector(2, i64){ 500, 0 };
    for (rock_paths) |path| {
        for (path) |segment| {
            min = @minimum(min, @as(@Vector(2, i64), segment));
            max = @maximum(max, @as(@Vector(2, i64), segment));
        }
    }

    std.debug.print("min, max = {}, {}\n", .{ min, max });
    std.debug.print("size = {}\n", .{max - min});

    var map = try Map.init(allocator, max - min + @splat(2, @as(i64, 1)));
    errdefer map.deinit();
    map.offset = min;
    std.mem.set(u8, map.tiles, '.');

    for (rock_paths) |path| {
        var pos = @as(@Vector(2, i64), path[0]);
        for (path[1..]) |segment| {
            var dir = std.math.sign(segment - pos);
            while (true) {
                map.set(pos - map.offset, '#');
                if (@reduce(.And, pos == segment)) break;
                pos += dir;
            }
        }
    }

    // Add sand source
    map.set(@Vector(2, i64){ 500, 0 } - map.offset, '+');

    return map;
}

test rockPathsToMap {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var map = try inputToMap(arena.allocator(), TEST_DATA);

    var map_string = std.ArrayList(u8).init(arena.allocator());
    try map.print(map_string.writer());

    try std.testing.expectEqualStrings(
        \\......+...
        \\..........
        \\..........
        \\..........
        \\....#...##
        \\....#...#.
        \\..###...#.
        \\........#.
        \\........#.
        \\#########.
        \\
    , map_string.items);
}
