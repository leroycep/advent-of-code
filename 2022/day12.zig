const std = @import("std");

const DATA = @embedFile("data/day12.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(arena.allocator(), DATA)});
}

const Map = struct {
    tiles: []const u8,
    width: usize,
    start_pos: [2]i32,
    end_pos: [2]i32,

    pub fn deinit(this: @This(), allocator: std.mem.Allocator) void {
        allocator.free(this.tiles);
    }

    pub fn size(this: @This()) [2]i32 {
        return .{ @intCast(i32, this.width), @intCast(i32, this.tiles.len / this.width) };
    }
};

pub fn parseMapData(allocator: std.mem.Allocator, input: []const u8) !Map {
    const width = std.mem.indexOfScalar(u8, input, '\n') orelse return error.InvalidFormat;

    var start_pos: [2]i32 = undefined;
    var end_pos: [2]i32 = undefined;
    var tiles = std.ArrayList(u8).init(allocator);
    defer tiles.deinit();

    var lines = std.mem.split(u8, input, "\n");
    var y: i32 = 0;
    while (lines.next()) |line| : (y += 1) {
        for (line) |c, x| {
            switch (c) {
                'S' => {
                    start_pos = .{ @intCast(i32, x), y };
                    try tiles.append('a');
                },
                'E' => {
                    end_pos = .{ @intCast(i32, x), y };
                    try tiles.append('z');
                },
                'a'...'z' => |h| try tiles.append(h),
                else => return error.InvalidFormat,
            }
        }
    }

    return Map{
        .tiles = tiles.toOwnedSlice(),
        .width = width,
        .start_pos = start_pos,
        .end_pos = end_pos,
    };
}

pub fn challenge1(allocator: std.mem.Allocator, input: []const u8) !u64 {
    const map = try parseMapData(allocator, input);
    defer map.deinit(allocator);

    const NEIGHBORS = [_][2]i32{ .{ 1, 0 }, .{ 0, 1 }, .{ -1, 0 }, .{ 0, -1 } };

    const came_from = try allocator.alloc(u32, map.tiles.len);
    defer allocator.free(came_from);
    std.mem.set(u32, came_from, std.math.maxInt(u32));

    const cost_to_path = try allocator.alloc(u64, map.tiles.len);
    defer allocator.free(cost_to_path);
    std.mem.set(u64, cost_to_path, std.math.maxInt(u64));
    cost_to_path[posToIndex(map.width, map.start_pos)] = 0;

    const estimated_cost_from_node = try allocator.alloc(u64, map.tiles.len);
    defer allocator.free(estimated_cost_from_node);
    std.mem.set(u64, estimated_cost_from_node, std.math.maxInt(u64));
    estimated_cost_from_node[0] = manhattanDistance(map.start_pos, map.end_pos);

    var next = std.PriorityQueue([2]i32, MapContext, MapContext.compare).init(allocator, .{
        .width = map.width,
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
            const current = posToIndex(map.width, current_pos);
            const neighbor = posToIndex(map.width, neighbor_pos);

            const can_move_to_neighbor = map.tiles[neighbor] <= map.tiles[current] + 1;
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

    return cost_to_path[posToIndex(map.width, map.end_pos)];
}

const MapContext = struct {
    width: usize,
    estimated_cost_from_node: []u64,

    fn compare(this: @This(), a: [2]i32, b: [2]i32) std.math.Order {
        const index_a = posToIndex(this.width, a);
        const index_b = posToIndex(this.width, b);
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
    const output = try parseMapData(std.testing.allocator, TEST_DATA);
    defer output.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 8), output.width);
    try std.testing.expectEqualStrings("aabqponmabcryxxlaccszzxkacctuvwjabdefghi", output.tiles);
    try std.testing.expectEqualSlices(i32, &.{ 0, 0 }, &output.start_pos);
    try std.testing.expectEqualSlices(i32, &.{ 5, 2 }, &output.end_pos);
}

test challenge1 {
    const output = try challenge1(std.testing.allocator, TEST_DATA);
    try std.testing.expectEqual(@as(u64, 31), output);
}
