const std = @import("std");

const DATA = @embedFile("data/day08.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(arena.allocator(), DATA)});
    try out.print("{}\n", .{try challenge2(arena.allocator(), DATA)});
}

const Map = struct {
    tiles: []const u8,
    width: usize,

    pub fn countVisibleInLine(this: @This(), start: [2]i64, dir: [2]i64) i64 {
        var pos: @Vector(2, i64) = start;
        var count: i64 = 0;
        var prev_height: u8 = this.get(pos);

        if (prev_height != '\n') count += 1;

        pos += dir;
        while (pos[0] >= 0 and pos[1] >= 0 and @reduce(.And, pos < this.size())) : (pos += dir) {
            const height = this.get(pos);
            if (height == '\n') continue;
            if (height > prev_height) {
                count += 1;
                prev_height = height;
            }
        }
        return count;
    }

    pub fn markVisibleInLine(this: @This(), start: [2]i64, dir: [2]i64, visible: *Visible) void {
        var pos: @Vector(2, i64) = start;
        var prev_height: u8 = this.get(pos);

        if (prev_height != '\n') visible.set(pos);

        pos += dir;
        while (pos[0] >= 0 and pos[1] >= 0 and @reduce(.And, pos < this.size())) : (pos += dir) {
            const height = this.get(pos);
            if (height == '\n') continue;
            if (height > prev_height) {
                visible.set(pos);
                prev_height = height;
            }
        }
    }

    pub fn get(this: @This(), pos: [2]i64) u8 {
        return this.tiles[@intCast(usize, pos[1]) * this.width + @intCast(usize, pos[0])];
    }

    pub fn size(this: @This()) [2]i64 {
        return .{ @intCast(i64, this.width), @intCast(i64, this.tiles.len / this.width) };
    }
};

const Visible = struct {
    tiles: []bool,
    width: usize,

    pub fn init(allocator: std.mem.Allocator, map_size: [2]i64) !@This() {
        const tiles = try allocator.alloc(bool, @intCast(usize, map_size[0] * map_size[1]));
        std.mem.set(bool, tiles, false);
        return @This(){
            .tiles = tiles,
            .width = @intCast(usize, map_size[0]),
        };
    }

    pub fn deinit(this: @This(), allocator: std.mem.Allocator) void {
        allocator.free(this.tiles);
    }

    pub fn set(this: *@This(), pos: [2]i64) void {
        this.tiles[@intCast(usize, pos[1]) * this.width + @intCast(usize, pos[0])] = true;
    }

    pub fn size(this: @This()) [2]i64 {
        return .{ @intCast(i64, this.width), @intCast(i64, this.tiles.len / this.width) };
    }

    pub fn count(this: @This()) i64 {
        var total: i64 = 0;
        for (this.tiles) |tile_is_visible| {
            if (tile_is_visible) {
                total += 1;
            }
        }
        return total;
    }

    pub fn dump(this: @This()) void {
        for (this.tiles) |tile_is_visible, index| {
            std.debug.print("{}", .{@boolToInt(tile_is_visible)});
            if (index % this.width == this.width - 1) {
                std.debug.print("\n", .{});
            }
        }
    }
};

pub fn challenge1(allocator: std.mem.Allocator, input: []const u8) !i64 {
    const map = Map{
        .tiles = input,
        .width = (std.mem.indexOf(u8, input, "\n") orelse return error.InvalidFormat) + 1,
    };
    std.debug.print("map size = {any}\n", .{map.size()});

    var visible = try Visible.init(allocator, map.size());
    defer visible.deinit(allocator);

    var x: i64 = 0;
    while (x < map.size()[0]) : (x += 1) {
        map.markVisibleInLine(.{ x, 0 }, .{ 0, 1 }, &visible);
        map.markVisibleInLine(.{ x, map.size()[1] - 1 }, .{ 0, -1 }, &visible);
    }

    var y: i64 = 0;
    while (y < map.size()[1]) : (y += 1) {
        map.markVisibleInLine(.{ 0, y }, .{ 1, 0 }, &visible);
        map.markVisibleInLine(.{ map.size()[0] - 1, y }, .{ -1, 0 }, &visible);
    }

    visible.dump();

    return visible.count();
}

const TEST_INPUT =
    \\30373
    \\25512
    \\65332
    \\33549
    \\35390
    \\
;

test challenge1 {
    const output = try challenge1(std.testing.allocator, TEST_INPUT);
    try std.testing.expectEqual(@as(i64, 21), output);
}

pub fn challenge2(allocator: std.mem.Allocator, input: []const u8) !usize {
    _ = allocator;
    _ = input;
    return error.Unimplemented;
}

test challenge2 {
    if (true) return error.SkipZigTest;
    const output = try challenge2(std.testing.allocator, TEST_INPUT);
    try std.testing.expectEqual(@as(usize, 24933642), output);
}
