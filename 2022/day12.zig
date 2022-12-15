const std = @import("std");
const util = @import("util");

const DATA = @embedFile("data/day12.txt");

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
    tiles: util.ConstGrid(u8),
    start_pos: [2]i32,
    end_pos: [2]i32,

    pub fn deinit(this: *@This(), allocator: std.mem.Allocator) void {
        this.tiles.free(allocator);
    }

    pub fn size(this: @This()) [2]i32 {
        return .{ @intCast(i32, this.tiles.size[0]), @intCast(i32, this.tiles.size[1]) };
    }
};

pub fn parseMapData(allocator: std.mem.Allocator, input: []const u8) !Map {
    const width = std.mem.indexOfScalar(u8, input, '\n') orelse return error.InvalidFormat;
    const height = input.len / (width + 1);
    // Reinterpret input as a grid of ascii characters
    const input_grid = util.ConstGrid(u8){
        .data = input,
        .stride = width + 1,
        .size = .{ width, height },
    };
    var grid = try util.Grid(u8).dupe(allocator, input_grid);

    var start_pos: [2]i32 = undefined;
    var end_pos: [2]i32 = undefined;

    var y: usize = 0;
    while (y < height) : (y += 1) {
        var x: usize = 0;
        while (x < width) : (x += 1) {
            switch (input_grid.getPos(.{ x, y })) {
                'S' => {
                    start_pos = .{ @intCast(i32, x), @intCast(i32, y) };
                    grid.setPos(.{ x, y }, 'a');
                },
                'E' => {
                    end_pos = .{ @intCast(i32, x), @intCast(i32, y) };
                    grid.setPos(.{ x, y }, 'z');
                },
                'a'...'z' => {},
                else => return error.InvalidFormat,
            }
        }
    }

    return Map{
        .tiles = grid.asConst(),
        .start_pos = start_pos,
        .end_pos = end_pos,
    };
}

pub fn challenge1(allocator: std.mem.Allocator, input: []const u8) !u64 {
    var map = try parseMapData(allocator, input);
    defer map.deinit(allocator);

    const NEIGHBORS = [_][2]i32{ .{ 1, 0 }, .{ 0, 1 }, .{ -1, 0 }, .{ 0, -1 } };

    const came_from = try allocator.alloc(u32, map.tiles.data.len);
    defer allocator.free(came_from);
    std.mem.set(u32, came_from, std.math.maxInt(u32));

    const cost_to_path = try allocator.alloc(u64, map.tiles.data.len);
    defer allocator.free(cost_to_path);
    std.mem.set(u64, cost_to_path, std.math.maxInt(u64));
    cost_to_path[posToIndex(map.tiles.stride, map.start_pos)] = 0;

    const estimated_cost_from_node = try allocator.alloc(u64, map.tiles.data.len);
    defer allocator.free(estimated_cost_from_node);
    std.mem.set(u64, estimated_cost_from_node, std.math.maxInt(u64));
    estimated_cost_from_node[0] = manhattanDistance(map.start_pos, map.end_pos);

    var next = std.PriorityQueue([2]i32, MapContext, MapContext.compare).init(allocator, .{
        .stride = map.tiles.stride,
        .estimated_cost_from_node = estimated_cost_from_node,
    });
    defer next.deinit();
    try next.add(map.start_pos);

    while (next.removeOrNull()) |current_pos| {
        if (std.mem.eql(i32, &current_pos, &map.end_pos)) {
            break;
        }
        for (NEIGHBORS) |offset| {
            const neighbor_pos = @as(@Vector(2, i32), current_pos) + @as(@Vector(2, i32), offset);
            if (@reduce(.Or, neighbor_pos < @splat(2, @as(i32, 0))) or @reduce(.Or, neighbor_pos >= map.size())) {
                continue;
            }
            const current = posToIndex(map.tiles.stride, current_pos);
            const neighbor = posToIndex(map.tiles.stride, neighbor_pos);

            const can_move_to_neighbor = map.tiles.data[neighbor] <= map.tiles.data[current] + 1;
            if (!can_move_to_neighbor) continue;
            const tentative_cost = cost_to_path[current] + 1;
            if (tentative_cost < cost_to_path[neighbor]) {
                came_from[neighbor] = current;
                cost_to_path[neighbor] = tentative_cost;
                estimated_cost_from_node[neighbor] = tentative_cost + manhattanDistance(neighbor_pos, map.end_pos);
                try next.add(neighbor_pos);
            }
        }
    } else {
        std.debug.print("hello\n", .{});
        return 0;
    }

    return cost_to_path[posToIndex(map.tiles.stride, map.end_pos)];
}

const MapContext = struct {
    stride: usize,
    estimated_cost_from_node: []u64,

    fn compare(this: @This(), a: [2]i32, b: [2]i32) std.math.Order {
        const index_a = posToIndex(this.stride, a);
        const index_b = posToIndex(this.stride, b);
        return std.math.order(this.estimated_cost_from_node[index_a], this.estimated_cost_from_node[index_b]);
    }
};

fn manhattanDistance(a: @Vector(2, i32), b: @Vector(2, i32)) u64 {
    const max = @select(i32, a > b, a, b);
    const min = @select(i32, a < b, a, b);
    return @intCast(u64, @reduce(.Add, max - min));
}

fn posToIndex(width: usize, pos: [2]i32) u32 {
    return @intCast(u32, pos[1]) * @intCast(u32, width) + @intCast(u32, pos[0]);
}

const TEST_DATA =
    \\Sabqponm
    \\abcryxxl
    \\accszExk
    \\acctuvwj
    \\abdefghi
    \\
;

test parseMapData {
    var output = try parseMapData(std.testing.allocator, TEST_DATA);
    defer output.deinit(std.testing.allocator);
    try std.testing.expectEqual(@Vector(2, usize){ 8, 5 }, output.tiles.size);
    try std.testing.expectEqualStrings("aabqponmabcryxxlaccszzxkacctuvwjabdefghi", output.tiles.data);
    try std.testing.expectEqualSlices(i32, &.{ 0, 0 }, &output.start_pos);
    try std.testing.expectEqualSlices(i32, &.{ 5, 2 }, &output.end_pos);
}

test challenge1 {
    const output = try challenge1(std.testing.allocator, TEST_DATA);
    try std.testing.expectEqual(@as(u64, 31), output);
}

pub fn challenge2(allocator: std.mem.Allocator, input: []const u8) !u64 {
    var map = try parseMapData(allocator, input);
    defer map.deinit(allocator);

    const NEIGHBORS = [_][2]i32{ .{ 1, 0 }, .{ 0, 1 }, .{ -1, 0 }, .{ 0, -1 } };

    const came_from = try allocator.alloc(u32, map.tiles.data.len);
    defer allocator.free(came_from);
    std.mem.set(u32, came_from, std.math.maxInt(u32));

    const cost_to_path = try allocator.alloc(u64, map.tiles.data.len);
    defer allocator.free(cost_to_path);
    std.mem.set(u64, cost_to_path, std.math.maxInt(u64));

    const estimated_cost_from_node = try allocator.alloc(u64, map.tiles.data.len);
    defer allocator.free(estimated_cost_from_node);
    std.mem.set(u64, estimated_cost_from_node, std.math.maxInt(u64));

    var next = std.PriorityQueue([2]i32, MapContext, MapContext.compare).init(allocator, .{
        .stride = map.tiles.stride,
        .estimated_cost_from_node = estimated_cost_from_node,
    });
    defer next.deinit();

    for (map.tiles.data) |tile, tile_index| {
        if (tile == 'a') {
            cost_to_path[tile_index] = 0;
            const pos = indexToPos(map.tiles.stride, tile_index);
            estimated_cost_from_node[tile_index] = manhattanDistance(pos, map.end_pos);
            try next.add(pos);
        }
    }

    while (next.removeOrNull()) |current_pos| {
        if (std.mem.eql(i32, &current_pos, &map.end_pos)) {
            break;
        }
        for (NEIGHBORS) |offset| {
            const neighbor_pos = @as(@Vector(2, i32), current_pos) + @as(@Vector(2, i32), offset);
            if (@reduce(.Or, neighbor_pos < @splat(2, @as(i32, 0))) or @reduce(.Or, neighbor_pos >= map.size())) {
                continue;
            }
            const current = posToIndex(map.tiles.stride, current_pos);
            const neighbor = posToIndex(map.tiles.stride, neighbor_pos);

            const can_move_to_neighbor = map.tiles.data[neighbor] <= map.tiles.data[current] + 1;
            if (!can_move_to_neighbor) continue;
            const tentative_cost = cost_to_path[current] + 1;
            if (tentative_cost < cost_to_path[neighbor]) {
                came_from[neighbor] = current;
                cost_to_path[neighbor] = tentative_cost;
                estimated_cost_from_node[neighbor] = tentative_cost + manhattanDistance(neighbor_pos, map.end_pos);
                try next.add(neighbor_pos);
            }
        }
    } else {
        std.debug.print("hello\n", .{});
        return 0;
    }

    return cost_to_path[posToIndex(map.tiles.stride, map.end_pos)];
}

fn indexToPos(width: usize, index: usize) [2]i32 {
    return .{ @intCast(i32, index % width), @intCast(i32, index / width) };
}

test challenge1 {
    const output = try challenge2(std.testing.allocator, TEST_DATA);
    try std.testing.expectEqual(@as(u64, 29), output);
}
