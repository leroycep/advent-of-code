const std = @import("std");
const Grid = @import("util").Grid;
const ConstGrid = @import("util").ConstGrid;

const DATA = @embedFile("data/day16.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(arena.allocator(), DATA)});
}

pub const Valve = struct {
    name: [2]u8,
    flow_rate: i64,
    tunnels: std.BoundedArray(u8, 10),
};

pub fn challenge1(allocator: std.mem.Allocator, input: []const u8) !i64 {
    var valves = std.ArrayList(Valve).init(allocator);
    defer valves.deinit();
    var valve_names = std.AutoHashMap([2]u8, u8).init(allocator);
    defer valve_names.deinit();

    var line_iterator = std.mem.split(u8, input, "\n");
    while (line_iterator.next()) |line| {
        if (line.len == 0) continue;
        var valve = Valve{
            .name = line[6..8].*,
            .flow_rate = undefined,
            .tunnels = .{},
        };

        const flow_rate_string_start = std.mem.indexOfAnyPos(u8, line, 8, "0123456789") orelse return error.InvalidFormat;
        const flow_rate_string_end = std.mem.indexOfPos(u8, line, flow_rate_string_start, ";") orelse return error.InvalidFormat;
        const flow_rate_string = line[flow_rate_string_start..flow_rate_string_end];
        valve.flow_rate = try std.fmt.parseInt(i64, flow_rate_string, 10);

        try valve_names.putNoClobber(valve.name, @intCast(u8, valves.items.len));
        try valves.append(valve);
    }

    // Parse tunnels
    var line_number: usize = 0;
    line_iterator = std.mem.split(u8, input, "\n");
    while (line_iterator.next()) |line| : (line_number += 1) {
        if (line.len == 0) continue;

        const flow_rate_string_end = std.mem.indexOfPos(u8, line, 8, ";") orelse return error.InvalidFormat;
        const indexof_valve = std.mem.indexOfPos(u8, line, flow_rate_string_end, "valve") orelse return error.InvalidFormat;
        const indexof_space = std.mem.indexOfPos(u8, line, indexof_valve, " ") orelse return error.InvalidFormat;

        var tunnel_iterator = std.mem.tokenize(u8, line[indexof_space..], ", ");
        while (tunnel_iterator.next()) |tunnel| {
            const tunnel_valve_index = valve_names.get(tunnel[0..2].*).?;
            try valves.items[line_number].tunnels.append(tunnel_valve_index);
        }
    }

    var distances = try calcDistances(allocator, valves.items);
    defer distances.free(allocator);

    return calcMostPressure(valves.items, distances.asConst(), null, valve_names.get("AA".*).?, 30);
}

// Floyd-Warshall algorithm, kind of. https://en.wikipedia.org/wiki/Floyd%E2%80%93Warshall_algorithm
fn calcDistances(allocator: std.mem.Allocator, valves: []const Valve) !Grid(u32) {
    var distances = try Grid(u32).alloc(allocator, .{ valves.len, valves.len });
    errdefer distances.free(allocator);
    distances.set(std.math.maxInt(u32));

    for (valves) |valve, index| {
        for (valve.tunnels.slice()) |tunnel| {
            distances.setPos(.{ index, tunnel }, 1);
        }
    }
    for (valves) |_, index| {
        distances.setPos(.{ index, index }, 0);
    }

    for (valves) |_, k| {
        for (valves) |_, i| {
            for (valves) |_, j| {
                const distance_ikj = distances.getPos(.{ i, k }) +| distances.getPos(.{ k, j });
                if (distance_ikj < distances.getPos(.{ i, j })) {
                    distances.setPos(.{ i, j }, distance_ikj);
                }
            }
        }
    }

    return distances;
}

const OpenValve = struct {
    next: ?*const OpenValve,
    index: usize,

    fn contains(this: @This(), index: usize) bool {
        if (this.index == index) return true;
        if (this.next) |next_open_valve| {
            return next_open_valve.contains(index);
        }
        return false;
    }
};

fn calcMostPressure(valves: []const Valve, distances: ConstGrid(u32), opened_opt: ?*const OpenValve, position: usize, time_left: i64) !i64 {
    if (time_left == 0) {
        return 0;
    }

    var best_pressure_release: i64 = 0;
    var best_index: usize = 0;
    for (valves) |valve, index| {
        if (valve.flow_rate == 0) continue;
        if (opened_opt) |opened| {
            if (opened.contains(index)) {
                continue;
            }
        }

        const distance = distances.getPos(.{ position, index });
        if (distance + 1 > time_left) continue;

        const pressure_from_this_valve = (time_left - distance - 1) * valve.flow_rate;
        const pressure_from_others = try calcMostPressure(valves, distances, &.{ .next = opened_opt, .index = index }, index, time_left - distance - 1);
        const pressure_release_estimate = pressure_from_this_valve + pressure_from_others;

        if (pressure_release_estimate > best_pressure_release) {
            best_pressure_release = pressure_release_estimate;
            best_index = index;
        }
    }

    return best_pressure_release;
}

const TEST_DATA =
    \\Valve AA has flow rate=0; tunnels lead to valves DD, II, BB
    \\Valve BB has flow rate=13; tunnels lead to valves CC, AA
    \\Valve CC has flow rate=2; tunnels lead to valves DD, BB
    \\Valve DD has flow rate=20; tunnels lead to valves CC, AA, EE
    \\Valve EE has flow rate=3; tunnels lead to valves FF, DD
    \\Valve FF has flow rate=0; tunnels lead to valves EE, GG
    \\Valve GG has flow rate=0; tunnels lead to valves FF, HH
    \\Valve HH has flow rate=22; tunnel leads to valve GG
    \\Valve II has flow rate=0; tunnels lead to valves AA, JJ
    \\Valve JJ has flow rate=21; tunnel leads to valve II
    \\
;

test challenge1 {
    try std.testing.expectEqual(@as(i64, 1651), try challenge1(std.testing.allocator, TEST_DATA));
}
