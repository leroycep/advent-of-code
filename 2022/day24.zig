const std = @import("std");
const util = @import("util");
const glfw = @import("util").glfw;
const gl = @import("util").gl;
const nanovg = @import("util").nanovg;
const Grid = @import("util").Grid;
const ConstGrid = @import("util").ConstGrid;

const DATA = @embedFile("data/day24.txt");

pub fn challenge1(allocator: std.mem.Allocator, input: []const u8) !i64 {
    var data = try Data.parseData(allocator, input);
    defer data.deinit();

    const start_pos = @Vector(2, i64){ 0, -1 };
    const end_pos = data.map_size - @Vector(2, i64){ 1, 0 };

    const SearchNode = struct {
        time: i64,
        pos: @Vector(2, i64),

        fn compare(context: Data, a: @This(), b: @This()) std.math.Order {
            _ = context;
            switch (std.math.order(a.time, b.time)) {
                .lt, .gt => |c| return c,
                .eq => {},
            }
            switch (std.math.order(a.pos[1], b.pos[1])) {
                .lt, .gt => |c| return c,
                .eq => {},
            }
            switch (std.math.order(a.pos[0], b.pos[0])) {
                .lt, .gt => |c| return c,
                .eq => {},
            }
            return .eq;
        }
    };

    var queue = std.PriorityQueue(SearchNode, Data, SearchNode.compare).init(allocator, data);
    defer queue.deinit();
    try queue.add(.{ .time = 0, .pos = .{ 0, -1 } });

    var node_distances = std.AutoHashMap(SearchNode, void).init(allocator);
    defer node_distances.deinit();

    var blizzards_out = try allocator.alloc(@Vector(2, i64), data.blizzards.len);
    defer allocator.free(blizzards_out);

    const repeat_size = @reduce(.Mul, data.map_size);

    var shortest_path_time: i64 = std.math.maxInt(i64);
    search_for_path: while (queue.removeOrNull()) |search_node| {
        if (search_node.time >= shortest_path_time) {
            continue :search_for_path;
        }

        const reduced_search_node = SearchNode{
            .time = @mod(search_node.time, repeat_size),
            .pos = search_node.pos,
        };
        if (node_distances.contains(reduced_search_node)) {
            continue :search_for_path;
        }

        if (@reduce(.And, search_node.pos == end_pos)) {
            shortest_path_time = @min(shortest_path_time, search_node.time);
            break :search_for_path;
        }

        if (@reduce(.Or, search_node.pos >= data.map_size)) {
            continue :search_for_path;
        }

        if (@reduce(.Or, search_node.pos < @splat(2, @as(i64, 0))) and !@reduce(.And, search_node.pos == start_pos)) {
            continue :search_for_path;
        }

        const blizzards_at_time = moveBlizzards(data.map_size, data.blizzards, data.blizzards_direction, search_node.time, blizzards_out);
        for (blizzards_at_time) |blizzard| {
            if (@reduce(.And, blizzard == search_node.pos)) {
                continue :search_for_path;
            }
        }

        try node_distances.put(reduced_search_node, {});

        try queue.addSlice(&.{
            .{ .time = search_node.time + 1, .pos = search_node.pos },
            .{ .time = search_node.time + 1, .pos = search_node.pos + @Vector(2, i64){ 1, 0 } },
            .{ .time = search_node.time + 1, .pos = search_node.pos + @Vector(2, i64){ -1, 0 } },
            .{ .time = search_node.time + 1, .pos = search_node.pos + @Vector(2, i64){ 0, 1 } },
            .{ .time = search_node.time + 1, .pos = search_node.pos + @Vector(2, i64){ 0, -1 } },
        });
    }

    return shortest_path_time;
}

pub fn challenge2(allocator: std.mem.Allocator, input: []const u8) !i64 {
    var data = try Data.parseData(allocator, input);
    defer data.deinit();

    const start_pos = @Vector(2, i64){ 0, -1 };
    const end_pos = data.map_size - @Vector(2, i64){ 1, 0 };

    const SearchNode = struct {
        time: i64,
        pos: @Vector(2, i64),
        state: State,

        const State = enum {
            initial,
            reached_end,
            reached_start,
        };

        fn compare(context: Data, a: @This(), b: @This()) std.math.Order {
            _ = context;
            switch (std.math.order(a.time, b.time)) {
                .lt, .gt => |c| return c,
                .eq => {},
            }
            switch (std.math.order(a.pos[1], b.pos[1])) {
                .lt, .gt => |c| return c,
                .eq => {},
            }
            switch (std.math.order(a.pos[0], b.pos[0])) {
                .lt, .gt => |c| return c,
                .eq => {},
            }
            return .eq;
        }
    };

    var queue = std.PriorityQueue(SearchNode, Data, SearchNode.compare).init(allocator, data);
    defer queue.deinit();
    try queue.add(.{ .time = 0, .pos = .{ 0, -1 }, .state = .initial });

    var node_distances = std.AutoHashMap(SearchNode, void).init(allocator);
    defer node_distances.deinit();

    var blizzards_out = try allocator.alloc(@Vector(2, i64), data.blizzards.len);
    defer allocator.free(blizzards_out);

    const repeat_size = @reduce(.Mul, data.map_size);

    var shortest_path_time: i64 = std.math.maxInt(i64);
    search_for_path: while (queue.removeOrNull()) |search_node| {
        if (search_node.time >= shortest_path_time) {
            continue :search_for_path;
        }

        const reduced_search_node = SearchNode{
            .time = @mod(search_node.time, repeat_size),
            .pos = search_node.pos,
            .state = search_node.state,
        };
        if (node_distances.contains(reduced_search_node)) {
            continue :search_for_path;
        }

        var new_state: SearchNode.State = switch (search_node.state) {
            .initial => if (@reduce(.And, search_node.pos == end_pos)) .reached_end else .initial,
            .reached_end => if (@reduce(.And, search_node.pos == start_pos)) .reached_start else .reached_end,
            .reached_start => if (@reduce(.And, search_node.pos == end_pos)) {
                shortest_path_time = @min(shortest_path_time, search_node.time);
                break :search_for_path;
            } else .reached_start,
        };

        if (@reduce(.Or, search_node.pos >= data.map_size) and !@reduce(.And, search_node.pos == end_pos)) {
            continue :search_for_path;
        }

        if (@reduce(.Or, search_node.pos < @splat(2, @as(i64, 0))) and !@reduce(.And, search_node.pos == start_pos)) {
            continue :search_for_path;
        }

        const blizzards_at_time = moveBlizzards(data.map_size, data.blizzards, data.blizzards_direction, search_node.time, blizzards_out);
        for (blizzards_at_time) |blizzard| {
            if (@reduce(.And, blizzard == search_node.pos)) {
                continue :search_for_path;
            }
        }

        try node_distances.put(reduced_search_node, {});

        try queue.addSlice(&.{
            .{ .time = search_node.time + 1, .pos = search_node.pos, .state = new_state },
            .{ .time = search_node.time + 1, .pos = search_node.pos + @Vector(2, i64){ 1, 0 }, .state = new_state },
            .{ .time = search_node.time + 1, .pos = search_node.pos + @Vector(2, i64){ -1, 0 }, .state = new_state },
            .{ .time = search_node.time + 1, .pos = search_node.pos + @Vector(2, i64){ 0, 1 }, .state = new_state },
            .{ .time = search_node.time + 1, .pos = search_node.pos + @Vector(2, i64){ 0, -1 }, .state = new_state },
        });
    }

    return shortest_path_time;
}

const TEST_DATA =
    \\#.######
    \\#>>.<^<#
    \\#.<..<<#
    \\#>v.><>#
    \\#<^v^^>#
    \\######.#
    \\
;

test challenge1 {
    const output = try challenge1(std.testing.allocator, TEST_DATA);
    try std.testing.expectEqual(@as(i64, 18), output);
}

test challenge2 {
    const output = try challenge2(std.testing.allocator, TEST_DATA);
    try std.testing.expectEqual(@as(i64, 54), output);
}

fn moveBlizzards(map_size: @Vector(2, i64), blizzards_in: []const @Vector(2, i64), blizzards_dir: []const @Vector(2, i64), number_of_steps: i64, blizzards_out: []@Vector(2, i64)) []@Vector(2, i64) {
    std.debug.assert(blizzards_out.len == blizzards_in.len);
    const repeat_size = @reduce(.Mul, map_size);
    const step_count_reduced = @mod(number_of_steps, repeat_size);
    for (blizzards_out) |*out, index| {
        const movement = blizzards_dir[index] * @splat(2, step_count_reduced);
        out.* = @mod(blizzards_in[index] +% movement, map_size);
    }
    return blizzards_out;
}

test moveBlizzards {
    var blizzards_out: [2]@Vector(2, i64) = undefined;
    try std.testing.expectEqualSlices(@Vector(2, i64), &.{
        .{ 1, 1 },
        .{ 3, 4 },
    }, moveBlizzards(.{ 5, 5 }, &.{
        .{ 0, 1 },
        .{ 3, 3 },
    }, &.{
        .{ 1, 0 },
        .{ 0, 1 },
    }, 1, &blizzards_out));

    try std.testing.expectEqualSlices(@Vector(2, i64), &.{
        .{ 1, 1 },
        .{ 3, 4 },
    }, moveBlizzards(.{ 5, 5 }, &.{
        .{ 0, 1 },
        .{ 3, 3 },
    }, &.{
        .{ 1, 0 },
        .{ 0, 1 },
    }, 6, &blizzards_out));

    try std.testing.expectEqualSlices(@Vector(2, i64), &.{
        .{ 0, 1 },
        .{ 3, 3 },
    }, moveBlizzards(.{ 5, 5 }, &.{
        .{ 4, 1 },
        .{ 3, 2 },
    }, &.{
        .{ 1, 0 },
        .{ 0, 1 },
    }, 1, &blizzards_out));
}

const Data = struct {
    allocator: std.mem.Allocator,
    map_size: @Vector(2, i64),
    blizzards: []@Vector(2, i64),
    blizzards_direction: []@Vector(2, i64),

    pub fn parseData(allocator: std.mem.Allocator, input: []const u8) !@This() {
        var blizzards = std.ArrayList(@Vector(2, i64)).init(allocator);
        errdefer blizzards.deinit();
        var blizzards_direction = std.ArrayList(@Vector(2, i64)).init(allocator);
        errdefer blizzards_direction.deinit();

        var lines_iter = std.mem.tokenize(u8, input, "\n");

        // skip initial line
        _ = lines_iter.next();

        var max_x: i64 = std.math.minInt(i64);
        var y: i64 = 0;
        while (lines_iter.next()) |line| : (y += 1) {
            const without_walls = std.mem.trim(u8, line, "#");
            max_x = @max(max_x, @intCast(i64, without_walls.len));
            for (without_walls) |character, col| {
                switch (character) {
                    '>', '<', '^', 'v' => try blizzards.append(.{ @intCast(i64, col), @intCast(i64, y) }),
                    else => {},
                }
                switch (character) {
                    '>' => try blizzards_direction.append(.{ 1, 0 }),
                    '<' => try blizzards_direction.append(.{ -1, 0 }),
                    '^' => try blizzards_direction.append(.{ 0, -1 }),
                    'v' => try blizzards_direction.append(.{ 0, 1 }),
                    else => {},
                }
            }
        }

        const blizzards_slice = try blizzards.toOwnedSlice();
        errdefer allocator.free(blizzards_slice);
        const blizzards_direction_slice = try blizzards_direction.toOwnedSlice();
        errdefer allocator.free(blizzards_direction_slice);

        return @This(){
            .allocator = allocator,
            .map_size = .{ max_x, y - 1 },
            .blizzards = blizzards_slice,
            .blizzards_direction = blizzards_direction_slice,
        };
    }

    pub fn deinit(this: *@This()) void {
        this.allocator.free(this.blizzards);
        this.allocator.free(this.blizzards_direction);
    }

    test parseData {
        var world = try parseData(std.testing.allocator, TEST_DATA);
        defer world.deinit();
        try std.testing.expectEqual(@Vector(2, i64){ 6, 4 }, world.map_size);
        try std.testing.expectEqualSlices(@Vector(2, i64), &.{
            // line 0
            .{ 0, 0 },
            .{ 1, 0 },
            .{ 3, 0 },
            .{ 4, 0 },
            .{ 5, 0 },

            // line 1
            .{ 1, 1 },
            .{ 4, 1 },
            .{ 5, 1 },

            // line 2
            .{ 0, 2 },
            .{ 1, 2 },
            .{ 3, 2 },
            .{ 4, 2 },
            .{ 5, 2 },

            // line 3
            .{ 0, 3 },
            .{ 1, 3 },
            .{ 2, 3 },
            .{ 3, 3 },
            .{ 4, 3 },
            .{ 5, 3 },
        }, world.blizzards);
        try std.testing.expectEqualSlices(@Vector(2, i64), &.{
            // line 0
            .{ 1, 0 },
            .{ 1, 0 },
            .{ -1, 0 },
            .{ 0, -1 },
            .{ -1, 0 },

            // line 1
            .{ -1, 0 },
            .{ -1, 0 },
            .{ -1, 0 },

            // line 2
            .{ 1, 0 },
            .{ 0, 1 },
            .{ 1, 0 },
            .{ -1, 0 },
            .{ 1, 0 },
            .{ -1, 0 },

            // line 3
            .{ 0, -1 },
            .{ 0, 1 },
            .{ 0, -1 },
            .{ 0, -1 },
            .{ 1, 0 },
        }, world.blizzards_direction);
    }
};

pub fn main() !void {
    const ctx = try util.Context.init(.{ .title = "Advent of Code - Day 21" });
    defer ctx.deinit();

    const stdout = std.io.getStdOut();

    const answer1 = try challenge1(ctx.allocator, DATA);
    try stdout.writer().print("{}\n", .{answer1});

    const answer2 = try challenge2(ctx.allocator, DATA);
    try stdout.writer().print("{}\n", .{answer2});

    var data = try Data.parseData(ctx.allocator, DATA);
    defer data.deinit();

    while (!ctx.window.shouldClose()) {
        try ctx.beginFrame();

        try ctx.endFrame();
    }

    try ctx.flush();
}
