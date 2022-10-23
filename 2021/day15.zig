const std = @import("std");

const DATA = @embedFile("./data/day15.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(arena.allocator(), DATA)});
    // try out.print("{}\n", .{try challenge2(arena.allocator(), DATA)});
}

const TestData = struct {
    width: usize,
    danger_levels: []const u8,

    pub fn parse(allocator: std.mem.Allocator, text: []const u8) !TestData {
        var width: usize = 0;
        var danger_levels = std.ArrayList(u8).init(allocator);
        defer danger_levels.deinit();

        var line_iter = std.mem.tokenize(u8, text, "\n");
        while (line_iter.next()) |line| {
            width = line.len;
            for (line) |c| {
                try danger_levels.append(c - '0');
            }
        }

        return @This(){
            .width = width,
            .danger_levels = danger_levels.toOwnedSlice(),
        };
    }

    pub fn deinit(this: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(this.danger_levels);
        this.* = undefined;
    }
};

pub fn challenge1(allocator: std.mem.Allocator, text: []const u8) !u64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var data = try TestData.parse(arena.allocator(), text);

    const size = @Vector(2, i32){ @intCast(i32, data.width), @intCast(i32, data.danger_levels.len / data.width) };
    const start = [2]i32{ 0, 0 };
    const finish = [2]i32{ size[0] - 1, size[1] - 1 };

    const came_from = try arena.allocator().alloc(u32, data.danger_levels.len);
    std.mem.set(u32, came_from, std.math.maxInt(u32));

    const cost_to_path = try arena.allocator().alloc(u64, data.danger_levels.len);
    std.mem.set(u64, cost_to_path, std.math.maxInt(u64));
    cost_to_path[0] = 0;

    const estimated_cost_from_node = try arena.allocator().alloc(u64, data.danger_levels.len);
    std.mem.set(u64, estimated_cost_from_node, std.math.maxInt(u64));
    estimated_cost_from_node[0] = manhattanDistance(start, finish);

    var next = std.PriorityQueue([2]i32, MapContext, MapContext.compare).init(arena.allocator(), .{ .width = data.width, .estimated_cost_from_node = estimated_cost_from_node });
    try next.add(start);

    while (next.removeOrNull()) |current_pos| {
        if (std.mem.eql(i32, &current_pos, &finish)) {
            break;
        }
        for (NEIGHBORS) |offset| {
            const neighbor_pos = @as(@Vector(2, i32), current_pos) + @as(@Vector(2, i32), offset);
            if (@reduce(.Or, neighbor_pos < @splat(2, @as(i32, 0))) or @reduce(.Or, neighbor_pos >= size)) {
                continue;
            }
            const current = posToIndex(data.width, current_pos);
            const neighbor = posToIndex(data.width, neighbor_pos);
            const tentative_cost = cost_to_path[current] + data.danger_levels[neighbor];
            if (tentative_cost < cost_to_path[neighbor]) {
                came_from[neighbor] = current;
                cost_to_path[neighbor] = tentative_cost;
                estimated_cost_from_node[neighbor] = tentative_cost + manhattanDistance(neighbor_pos, finish);
                try next.add(neighbor_pos);
            }
        }
    } else {
        return 0;
    }

    return cost_to_path[posToIndex(data.width, finish)];
}

const NEIGHBORS = [_][2]i32{ .{ 1, 0 }, .{ 0, 1 }, .{ -1, 0 }, .{ 0, -1 } };

fn manhattanDistance(a: @Vector(2, i32), b: @Vector(2, i32)) u64 {
    return @intCast(u64, @reduce(.Add, b - a));
}

fn posToIndex(width: usize, pos: [2]i32) u32 {
    return @intCast(u32, pos[1]) * @intCast(u32, width) + @intCast(u32, pos[0]);
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

test challenge1 {
    const TEST_DATA =
        \\1163751742
        \\1381373672
        \\2136511328
        \\3694931569
        \\7463417111
        \\1319128137
        \\1359912421
        \\3125421639
        \\1293138521
        \\2311944581
        \\
    ;
    try std.testing.expectEqual(@as(u64, 40), try challenge1(std.testing.allocator, TEST_DATA));
}
