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

    var map = try inputToMap(arena.allocator(), input);

    loop_until_sand_out_of_bounds: while (true) {
        // Start sand at 500, 0
        var pos = @Vector(2, i64){ 500, 0 };
        switch (map.getOpt(pos).?) {
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
                const new_pos_tile = map.getOpt(new_pos) orelse break :loop_until_sand_out_of_bounds;

                switch (new_pos_tile) {
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

        map.set(pos, 'o');
    }

    return std.mem.count(u8, map.grid.data, "o");
}

pub fn challenge2(allocator: std.mem.Allocator, input: []const u8) !u64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var min = @Vector(2, i64){ 500, 0 };
    var max = @Vector(2, i64){ 500, 0 };
    var rock_paths = std.ArrayList([]const [2]i64).init(arena.allocator());
    var lines_iterator = std.mem.split(u8, input, "\n");
    while (lines_iterator.next()) |line| {
        if (line.len == 0) continue;
        const path = try parseRockPath(arena.allocator(), line);
        for (path) |segment| {
            min = @min(min, @as(@Vector(2, i64), segment));
            max = @max(max, @as(@Vector(2, i64), segment));
        }
        try rock_paths.append(path);
    }

    // add an "infinite" floor
    try rock_paths.append(&.{ .{ min[0] - max[1], max[1] + 2 }, .{ max[0] + max[1], max[1] + 2 } });

    var map = try rockPathsToMap(arena.allocator(), rock_paths.items);

    while (true) {
        // Start sand at 500, 0
        var pos = @Vector(2, i64){ 500, 0 };
        switch (map.getOpt(pos).?) {
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
                const new_pos_tile = map.getOpt(new_pos) orelse return error.SandOutOfBounds;

                switch (new_pos_tile) {
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

        map.set(pos, 'o');
    }

    return std.mem.count(u8, map.grid.data, "o");
}

fn inputToMap(allocator: std.mem.Allocator, input: []const u8) !Map {
    var rock_paths = std.ArrayList([]const [2]i64).init(allocator);
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
    grid: Grid(u8),
    offset: [2]i64,

    pub fn size(this: *@This()) [2]i64 {
        return .{ @intCast(i64, this.grid.size[0]), @intCast(i64, this.grid.size[1]) };
    }

    pub fn set(this: *@This(), pos: [2]i64, value: u8) void {
        const pos_offset = @as(@Vector(2, i64), pos) - this.offset;
        std.debug.assert(@reduce(.And, pos_offset >= @splat(2, @as(i64, 0))));
        std.debug.assert(@reduce(.And, pos_offset < this.size()));
        return this.grid.setPos(@intCast(@Vector(2, usize), pos_offset), value);
    }

    pub fn getOpt(this: *@This(), pos: [2]i64) ?u8 {
        const pos_offset = @as(@Vector(2, i64), pos) - this.offset;
        if (@reduce(.Or, pos_offset < @splat(2, @as(i64, 0))) or @reduce(.Or, pos_offset >= this.size())) {
            return null;
        }
        const pos_usize = @intCast(@Vector(2, usize), pos_offset);
        return this.grid.getPos(pos_usize);
    }
};

pub fn Grid(comptime T: type) type {
    return struct {
        data: []T,
        stride: usize,
        size: [2]usize,

        pub fn alloc(allocator: std.mem.Allocator, size: [2]usize) !@This() {
            const data = try allocator.alloc(T, size[0] * size[1]);
            return @This(){
                .data = data,
                .stride = size[0],
                .size = size,
            };
        }

        pub fn free(this: *@This(), allocator: std.mem.Allocator) void {
            allocator.free(this.data);
        }

        pub fn asConst(this: @This()) ConstGrid(T) {
            return ConstGrid(T){
                .data = this.data,
                .stride = this.stride,
                .size = this.size,
            };
        }

        pub fn copy(dest: @This(), src: ConstGrid(T)) void {
            std.debug.assert(src.size[0] >= dest.size[0]);
            std.debug.assert(src.size[1] >= dest.size[1]);

            var row_index: usize = 0;
            while (row_index < dest.size[1]) : (row_index += 1) {
                const dest_row = dest.data[row_index * dest.stride ..][0..dest.size[0]];
                const src_row = src.data[row_index * src.stride ..][0..src.size[0]];
                std.mem.copy(T, dest_row, src_row);
            }
        }

        pub fn set(this: @This(), value: T) void {
            var row_index: usize = 0;
            while (row_index < this.size[1]) : (row_index += 1) {
                const row = this.data[row_index * this.stride ..][0..this.size[0]];
                std.mem.set(T, row, value);
            }
        }

        pub fn setPos(this: @This(), pos: [2]usize, value: T) void {
            std.debug.assert(pos[0] < this.size[0] and pos[1] < this.size[1]);
            this.data[pos[1] * this.stride + pos[0]] = value;
        }

        pub fn getPosPtr(this: @This(), pos: [2]usize) *T {
            std.debug.assert(pos[0] < this.size[0] and pos[1] < this.size[1]);
            return &this.tiles[pos[1] * this.stride + pos[0]];
        }

        pub fn getPos(this: @This(), pos: [2]usize) T {
            return this.asConst().getPos(pos);
        }

        pub fn getRegion(this: @This(), pos: [2]usize, size: [2]usize) @This() {
            const posv: @Vector(2, usize) = pos;
            const sizev: @Vector(2, usize) = size;

            std.debug.assert(@reduce(.And, posv < this.size));
            std.debug.assert(@reduce(.And, posv + sizev <= this.size));

            const max_pos = posv + sizev - @Vector(2, usize){ 1, 1 };

            const min_index = posv[1] * this.stride + posv[0];
            const max_index = max_pos[1] * this.stride + max_pos[0];

            std.debug.assert(max_index - min_index + 1 >= size[0] * size[1]);

            return @This(){
                .data = this.data[min_index .. max_index + 1],
                .stride = this.stride,
                .size = size,
            };
        }
    };
}

pub fn ConstGrid(comptime T: type) type {
    return struct {
        data: []const T,
        stride: usize,
        size: [2]usize,

        pub fn getPos(this: @This(), pos: [2]usize) T {
            std.debug.assert(pos[0] < this.size[0] and pos[1] < this.size[1]);
            return this.data[pos[1] * this.stride + pos[0]];
        }

        pub fn getRegion(this: @This(), pos: [2]usize, size: [2]usize) @This() {
            const posv: @Vector(2, usize) = pos;
            const sizev: @Vector(2, usize) = size;

            std.debug.assert(@reduce(.And, posv < this.size));
            std.debug.assert(@reduce(.And, posv + sizev <= this.size));

            const max_pos = posv + sizev - .{ 1, 1 };

            const min_index = posv[1] * this.stride + posv[0];
            const max_index = max_pos[1] * this.stride + max_pos[0];

            return @This(){
                .data = this.data[min_index .. max_index + 1],
                .stride = this.stride,
                .size = size,
            };
        }
    };
}

fn rockPathsToMap(allocator: std.mem.Allocator, rock_paths: []const []const [2]i64) !Map {
    var min = @Vector(2, i64){ 500, 0 };
    var max = @Vector(2, i64){ 500, 0 };
    for (rock_paths) |path| {
        for (path) |segment| {
            min = @min(min, @as(@Vector(2, i64), segment));
            max = @max(max, @as(@Vector(2, i64), segment));
        }
    }

    const size = @intCast(@Vector(2, usize), max - min + @Vector(2, i64){ 1, 1 });

    var map = Map{
        .grid = try Grid(u8).alloc(allocator, size),
        .offset = min,
    };
    errdefer map.grid.free(allocator);
    map.grid.set('.');

    for (rock_paths) |path| {
        for (path) |next_pos, index| {
            if (index == 0) continue;

            // The position of things in the abstract
            const previous_pos: @Vector(2, i64) = path[index - 1];
            const min_pos = @min(@as(@Vector(2, i64), next_pos), previous_pos);
            const max_pos = @max(@as(@Vector(2, i64), next_pos), previous_pos);

            // The position on the data in memory
            const region_pos = @intCast(@Vector(2, usize), min_pos - map.offset);
            const region_size = @intCast(@Vector(2, usize), max_pos - min_pos + @Vector(2, i64){ 1, 1 });

            const region = map.grid.getRegion(region_pos, region_size);
            region.set('#');
        }
    }

    return map;
}

test rockPathsToMap {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var map = try inputToMap(arena.allocator(), TEST_DATA);

    var map_string = std.ArrayList(u8).init(arena.allocator());
    var row: usize = 0;
    while (row < map.grid.size[1]) : (row += 1) {
        try map_string.writer().writeAll(map.grid.data[row * map.grid.stride ..][0..map.grid.size[0]]);
        try map_string.writer().writeAll("\n");
    }

    try std.testing.expectEqualStrings(
        \\..........
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
    ,
        map_string.items,
    );
}
