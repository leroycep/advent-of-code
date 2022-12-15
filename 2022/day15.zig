const std = @import("std");
const Grid = @import("util").Grid;
const ConstGrid = @import("util").ConstGrid;

const DATA = @embedFile("data/day15.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(arena.allocator(), DATA, 2_000_000)});
    try out.print("{}\n", .{try challenge2(arena.allocator(), DATA, 4_000_000)});
}

pub fn challenge1(allocator: std.mem.Allocator, input: []const u8, row_to_check: i64) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var segments = std.ArrayList([2]i64).init(allocator);
    defer segments.deinit();

    const parsed = try Input.parse(arena.allocator(), input);
    for (parsed.sensors) |sensor, index| {
        const beacon = parsed.beacons[index];
        const radius = manhattanDistance(sensor, beacon);

        if (intersectWithLine(sensor, radius, row_to_check)) |segment| {
            std.debug.print("s {any}, b {any}, radius {any}, segment {any}\n", .{ sensor, beacon, radius, segment });

            var new_segment = segment;
            var i = segments.items.len;
            while (i > 0) : (i -= 1) {
                if (segmentsOverlap(segments.items[i - 1], new_segment)) {
                    new_segment = combineSegments(segments.swapRemove(i - 1), new_segment);
                }
            }

            try segments.append(new_segment);
        }
    }

    var count_places_cannot_be: i64 = 0;
    for (segments.items) |segment, i| {
        std.debug.print("segment[{}] = {any}\n", .{ i, segment });
        count_places_cannot_be += segment[1] - segment[0];
    }

    return count_places_cannot_be;
}

pub fn challenge2(allocator: std.mem.Allocator, input: []const u8, max_coordinate: i64) !i64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var segments = std.ArrayList([2]i64).init(allocator);
    defer segments.deinit();

    const parsed = try Input.parse(arena.allocator(), input);

    var distress_beacon = @Vector(2, i64){ -1, -1 };

    var row_to_check: i64 = 0;
    check_rows: while (row_to_check < max_coordinate) : (row_to_check += 1) {
        segments.shrinkRetainingCapacity(0);

        for (parsed.sensors) |sensor, index| {
            const beacon = parsed.beacons[index];
            const radius = manhattanDistance(sensor, beacon);

            if (intersectWithLine(sensor, radius, row_to_check)) |segment| {
                var new_segment = segment;
                var i = segments.items.len;
                while (i > 0) : (i -= 1) {
                    if (segmentsOverlap(segments.items[i - 1], new_segment)) {
                        new_segment = combineSegments(segments.swapRemove(i - 1), new_segment);
                    }
                }

                try segments.append(new_segment);
            }
        }

        var count_places_cannot_be: i64 = 0;
        for (segments.items) |segment| {
            if (segment[0] - 1 >= 0 and segment[0] - 1 <= max_coordinate) {
                distress_beacon = .{ segment[0] - 1, row_to_check };
                break :check_rows;
            }
            if (segment[1] + 1 >= 0 and segment[1] + 1 <= max_coordinate) {
                distress_beacon = .{ segment[1] + 1, row_to_check };
                break :check_rows;
            }
            count_places_cannot_be += segment[1] - segment[0];
        }
    }

    return distress_beacon[0] * 4_000_000 + distress_beacon[1];
}

// Returns the left and right x coordinates of the square/circle intersecting the line
fn intersectWithLine(origin: [2]i64, radius: i64, line_y: i64) ?[2]i64 {
    const distance_to_line = std.math.absInt(origin[1] - line_y) catch return null;
    if (distance_to_line > radius) {
        return null;
    }

    return .{
        origin[0] - (radius - distance_to_line),
        origin[0] + (radius - distance_to_line),
    };
}

fn manhattanDistance(a: [2]i64, b: [2]i64) i64 {
    const av: @Vector(2, i64) = a;
    const bv: @Vector(2, i64) = b;
    const max = @max(av, bv);
    const min = @min(av, bv);
    return @reduce(.Add, max - min);
}

const TEST_DATA =
    \\Sensor at x=2, y=18: closest beacon is at x=-2, y=15
    \\Sensor at x=9, y=16: closest beacon is at x=10, y=16
    \\Sensor at x=13, y=2: closest beacon is at x=15, y=3
    \\Sensor at x=12, y=14: closest beacon is at x=10, y=16
    \\Sensor at x=10, y=20: closest beacon is at x=10, y=16
    \\Sensor at x=14, y=17: closest beacon is at x=10, y=16
    \\Sensor at x=8, y=7: closest beacon is at x=2, y=10
    \\Sensor at x=2, y=0: closest beacon is at x=2, y=10
    \\Sensor at x=0, y=11: closest beacon is at x=2, y=10
    \\Sensor at x=20, y=14: closest beacon is at x=25, y=17
    \\Sensor at x=17, y=20: closest beacon is at x=21, y=22
    \\Sensor at x=16, y=7: closest beacon is at x=15, y=3
    \\Sensor at x=14, y=3: closest beacon is at x=15, y=3
    \\Sensor at x=20, y=1: closest beacon is at x=15, y=3
    \\
;

test challenge1 {
    const output = try challenge1(std.testing.allocator, TEST_DATA, 10);
    try std.testing.expectEqual(@as(i64, 26), output);
}

test challenge2 {
    const output = try challenge2(std.testing.allocator, TEST_DATA, 20);
    try std.testing.expectEqual(@as(i64, 56000011), output);
}

fn segmentsOverlap(a: [2]i64, b: [2]i64) bool {
    const radius_a = @divFloor(a[1] - a[0] + 1, 2);
    const radius_b = @divFloor(b[1] - b[0] + 1, 2);

    const midpoint_a = @divFloor(a[0] + a[1], 2);
    const midpoint_b = @divFloor(b[0] + b[1], 2);

    const distance_between = std.math.absInt(midpoint_b - midpoint_a) catch unreachable;
    return distance_between <= radius_a + radius_b;
}

test segmentsOverlap {
    try std.testing.expect(segmentsOverlap(.{ -2, 2 }, .{ 2, 14 }));
    try std.testing.expect(!segmentsOverlap(.{ -2, 1 }, .{ 3, 14 }));
    try std.testing.expect(segmentsOverlap(.{ -2, 16 }, .{ 3, 14 }));
}

fn combineSegments(a: [2]i64, b: [2]i64) [2]i64 {
    return .{
        std.math.min(a[0], b[0]),
        std.math.max(a[1], b[1]),
    };
}

const Input = struct {
    sensors: [][2]i64,
    beacons: [][2]i64,

    pub fn parse(allocator: std.mem.Allocator, input: []const u8) !@This() {
        var sensors = std.ArrayList([2]i64).init(allocator);
        defer sensors.deinit();
        var beacons = std.ArrayList([2]i64).init(allocator);
        defer beacons.deinit();

        var lines_iterator = std.mem.split(u8, input, "\n");
        while (lines_iterator.next()) |line| {
            if (line.len == 0) continue;

            var number_string_iterator = std.mem.tokenize(u8, line, "Sensor at x=, y=: closest beacon is at x=, y=");
            const sensor_x = number_string_iterator.next() orelse return error.InvalidFormat;
            const sensor_y = number_string_iterator.next() orelse return error.InvalidFormat;
            const beacon_x = number_string_iterator.next() orelse return error.InvalidFormat;
            const beacon_y = number_string_iterator.next() orelse return error.InvalidFormat;

            try sensors.append(.{
                try std.fmt.parseInt(i64, sensor_x, 10),
                try std.fmt.parseInt(i64, sensor_y, 10),
            });
            try beacons.append(.{
                try std.fmt.parseInt(i64, beacon_x, 10),
                try std.fmt.parseInt(i64, beacon_y, 10),
            });
        }

        const sensors_slice = try sensors.toOwnedSlice();
        errdefer allocator.free(sensors_slice);
        const beacons_slice = try beacons.toOwnedSlice();
        errdefer allocator.free(beacons_slice);

        return @This(){
            .sensors = sensors_slice,
            .beacons = beacons_slice,
        };
    }

    test parse {
        const parsed = try Input.parse(std.testing.allocator, TEST_DATA);
        defer {
            std.testing.allocator.free(parsed.sensors);
            std.testing.allocator.free(parsed.beacons);
        }
        try std.testing.expectEqualSlices([2]i64, parsed.sensors, &.{
            .{ 2, 18 },
            .{ 9, 16 },
            .{ 13, 2 },
            .{ 12, 14 },
            .{ 10, 20 },
            .{ 14, 17 },
            .{ 8, 7 },
            .{ 2, 0 },
            .{ 0, 11 },
            .{ 20, 14 },
            .{ 17, 20 },
            .{ 16, 7 },
            .{ 14, 3 },
            .{ 20, 1 },
        });
        try std.testing.expectEqualSlices([2]i64, parsed.beacons, &.{
            .{ -2, 15 },
            .{ 10, 16 },
            .{ 15, 3 },
            .{ 10, 16 },
            .{ 10, 16 },
            .{ 10, 16 },
            .{ 2, 10 },
            .{ 2, 10 },
            .{ 2, 10 },
            .{ 25, 17 },
            .{ 21, 22 },
            .{ 15, 3 },
            .{ 15, 3 },
            .{ 15, 3 },
        });
    }
};
