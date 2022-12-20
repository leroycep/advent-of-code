const std = @import("std");
const gl = @import("util").gl;
const nanovg = @import("util").nanovg;
const util = @import("util");
const Grid = @import("util").Grid;
const ConstGrid = @import("util").ConstGrid;

const DATA = @embedFile("data/day14.txt");

pub fn main() !void {
    var ctx = try util.Context.init(.{});
    defer ctx.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(ctx.allocator, DATA)});

    const amount_of_sand = try challenge2(ctx.allocator, DATA);
    try out.print("{}\n", .{amount_of_sand});

    var map = try inputToMap2(ctx.allocator, DATA);
    defer map.deinit();
    map.set(.{ 500, 0 }, '+');

    const palette = try ctx.allocator.alloc([4]u8, 256);
    defer ctx.allocator.free(palette);
    palette['#'] = colors.STONE;
    palette['o'] = colors.SAND;
    palette['+'] = colors.RED;

    const colormap = ctx.vg.createImageRGBA(@intCast(u32, palette.len), 1, .{ .nearest = true }, std.mem.sliceAsBytes(palette));
    defer ctx.vg.deleteImage(colormap);

    const map_image = ctx.vg.createImageAlpha(
        @intCast(u32, map.grid.size[0]),
        @intCast(u32, map.grid.size[1]),
        .{ .nearest = true },
        std.mem.sliceAsBytes(map.grid.data),
    );
    defer ctx.vg.deleteImage(map_image);

    var text_buffer = std.ArrayList(u8).init(ctx.allocator);
    defer text_buffer.deinit();

    var frame_number: i64 = 0;
    main_loop: while (!ctx.window.shouldClose()) : (frame_number += 1) {
        switch (try map.step()) {
            .none => {},
            else => break :main_loop,
        }

        const window_size = try ctx.window.getSize();
        const framebuffer_size = try ctx.window.getFramebufferSize();
        const content_scale = try ctx.window.getContentScale();
        const pixel_ratio = @max(content_scale.x_scale, content_scale.y_scale);

        gl.viewport(0, 0, framebuffer_size.width, framebuffer_size.height);
        gl.clearColor(0, 0, 0, 1);
        gl.clear(.{ .color = true, .depth = true, .stencil = true });

        ctx.vg.beginFrame(@intToFloat(f32, window_size.width), @intToFloat(f32, window_size.height), pixel_ratio);

        const tile_scale = std.math.floor(std.math.max(1, std.math.min(
            @intToFloat(f32, window_size.width) / @intToFloat(f32, map.grid.size[0]),
            @intToFloat(f32, window_size.height) / @intToFloat(f32, map.grid.size[1]),
        )));

        const offset = [2]f32{
            std.math.floor((@intToFloat(f32, window_size.width) - @intToFloat(f32, map.grid.size[0]) * tile_scale) / 2.0),
            std.math.floor((@intToFloat(f32, window_size.height) - @intToFloat(f32, map.grid.size[1]) * tile_scale) / 2.0),
        };

        ctx.vg.translate(offset[0], offset[1]);
        ctx.vg.scale(tile_scale, tile_scale);

        ctx.vg.updateImage(map_image, std.mem.sliceAsBytes(map.grid.data));
        const image_pattern = ctx.vg.indexedImagePattern(0, 0, @intToFloat(f32, map.grid.size[0]), @intToFloat(f32, map.grid.size[1]), 0, map_image, colormap, 1);

        ctx.vg.beginPath();
        ctx.vg.rect(0, 0, @intToFloat(f32, map.grid.size[0]), @intToFloat(f32, map.grid.size[1]));
        ctx.vg.fillPaint(image_pattern);
        ctx.vg.fill();

        for (map.falling_sand.items) |sand| {
            const pos = sand - map.offset;
            ctx.vg.beginPath();
            ctx.vg.rect(@intToFloat(f32, pos[0]), @intToFloat(f32, pos[1]), 1, 1);
            ctx.vg.fillColor(nanovg.rgba(colors.SAND[0], colors.SAND[1], colors.SAND[2], colors.SAND[3]));
            ctx.vg.fill();
        }

        ctx.vg.endFrame();

        try ctx.showFrame(frame_number);
    }

    try ctx.flush(frame_number);
}

const colors = struct {
    const STONE = .{ 255, 192, 0, 255 };
    const SAND = .{ 0xc2, 0xb2, 0x80, 0xFF };
    const RED = .{ 0xFF, 0x00, 0x00, 0xFF };
};

pub fn challenge1(allocator: std.mem.Allocator, input: []const u8) !u64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var map = try inputToMap(arena.allocator(), input);

    while ((try map.step()) == .none) {}

    return std.mem.count(u8, map.grid.data, "o");
}

pub fn challenge2(allocator: std.mem.Allocator, input: []const u8) !u64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var map = try inputToMap2(arena.allocator(), input);

    while (true) {
        switch (try map.step()) {
            .none => {},
            .hole_blocked => break,
            .sand_out_of_bounds => return error.SandOutOfBounds,
        }
    }

    return std.mem.count(u8, map.grid.data, "o");
}

fn inputToMap(allocator: std.mem.Allocator, input: []const u8) !Map {
    var rock_paths = std.ArrayList([]const [2]i64).init(allocator);
    defer {
        for (rock_paths.items) |path| {
            allocator.free(path);
        }
        rock_paths.deinit();
    }

    var lines_iterator = std.mem.split(u8, input, "\n");
    while (lines_iterator.next()) |line| {
        if (line.len == 0) continue;
        try rock_paths.append(try parseRockPath(allocator, line));
    }

    const map = try rockPathsToMap(allocator, rock_paths.items);

    return map;
}

fn inputToMap2(allocator: std.mem.Allocator, input: []const u8) !Map {
    var min = @Vector(2, i64){ 500, 0 };
    var max = @Vector(2, i64){ 500, 0 };
    var rock_paths = std.ArrayList([]const [2]i64).init(allocator);
    defer {
        for (rock_paths.items) |path| {
            allocator.free(path);
        }
        rock_paths.deinit();
    }

    var lines_iterator = std.mem.split(u8, input, "\n");
    while (lines_iterator.next()) |line| {
        if (line.len == 0) continue;
        const path = try parseRockPath(allocator, line);
        for (path) |segment| {
            min = @min(min, @as(@Vector(2, i64), segment));
            max = @max(max, @as(@Vector(2, i64), segment));
        }
        try rock_paths.append(path);
    }

    // add an "infinite" floor
    try rock_paths.append(try allocator.dupe([2]i64, &.{ .{ min[0] - max[1], max[1] + 2 }, .{ max[0] + max[1], max[1] + 2 } }));

    var map = try rockPathsToMap(allocator, rock_paths.items);

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
    grid: Grid(u8),
    offset: [2]i64,
    falling_sand: std.ArrayListUnmanaged(@Vector(2, i64)),
    sand_to_remove: std.ArrayListUnmanaged(usize),

    pub fn deinit(this: *@This()) void {
        this.grid.free(this.allocator);
        this.falling_sand.deinit(this.allocator);
        this.sand_to_remove.deinit(this.allocator);
    }

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

    const StepResult = enum {
        none,
        sand_out_of_bounds,
        hole_blocked,
    };

    pub fn step(this: *@This()) !StepResult { // Start sand at 500, 0
        switch (this.getOpt(.{ 500, 0 }).?) {
            '.', '+' => {},
            'o' => return .hole_blocked,
            else => {},
        }

        try this.falling_sand.append(this.allocator, .{ 500, 0 });

        const POTENTIAL_MOVES = [_]@Vector(2, i64){
            .{ 0, 1 },
            .{ -1, 1 },
            .{ 1, 1 },
        };

        for (this.falling_sand.items) |*sand_pos, index| {
            // Move sand down
            for (POTENTIAL_MOVES) |move_offset| {
                const new_pos = sand_pos.* + move_offset;
                const new_pos_tile = this.getOpt(new_pos) orelse return .sand_out_of_bounds;

                switch (new_pos_tile) {
                    '.', '+' => {
                        sand_pos.* = new_pos;
                        break;
                    },
                    else => {},
                }
            } else {
                this.set(sand_pos.*, 'o');
                try this.sand_to_remove.append(this.allocator, index);
            }
        }

        std.sort.sort(usize, this.sand_to_remove.items, {}, std.sort.desc(usize));
        for (this.sand_to_remove.items) |index_to_remove| {
            _ = this.falling_sand.swapRemove(index_to_remove);
        }
        this.sand_to_remove.clearRetainingCapacity();

        return .none;
    }
};

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
        .allocator = allocator,
        .grid = try Grid(u8).allocWithRowAlign(allocator, size, 4),
        .offset = min,
        .falling_sand = .{},
        .sand_to_remove = .{},
    };
    errdefer map.deinit();
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
