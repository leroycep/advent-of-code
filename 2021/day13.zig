const std = @import("std");

const DATA = @embedFile("./data/day13.txt");

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
    points: []const [2]i64,
    folds: []const Fold,

    const Fold = struct {
        axis: Axis,
        pos: i64,

        const Axis = enum(u1) { x = 0, y = 1 };
    };

    pub fn parse(allocator: std.mem.Allocator, text: []const u8) !TestData {
        var points = std.ArrayList([2]i64).init(allocator);
        defer points.deinit();
        var folds = std.ArrayList(TestData.Fold).init(allocator);
        defer points.deinit();

        var section_iter = std.mem.split(u8, text, "\n\n");

        const points_text = section_iter.next() orelse return error.InvalidFormat;
        const folds_text = section_iter.next() orelse return error.InvalidFormat;

        var line_iter = std.mem.tokenize(u8, points_text, "\n");
        while (line_iter.next()) |line| {
            var value_iter = std.mem.tokenize(u8, line, ",");
            const point_number_text = [2][]const u8{
                value_iter.next() orelse return error.InvalidFormat,
                value_iter.next() orelse return error.InvalidFormat,
            };
            try points.append(.{
                try std.fmt.parseInt(i64, point_number_text[0], 10),
                try std.fmt.parseInt(i64, point_number_text[1], 10),
            });
        }

        line_iter = std.mem.tokenize(u8, folds_text, "\n");
        while (line_iter.next()) |line| {
            if (std.mem.indexOf(u8, line, "x=")) |x_eq_pos| {
                const num_str = line[x_eq_pos + 2 ..];
                try folds.append(.{
                    .axis = .x,
                    .pos = try std.fmt.parseInt(i64, num_str, 10),
                });
            } else if (std.mem.indexOf(u8, line, "y=")) |y_eq_pos| {
                const num_str = line[y_eq_pos + 2 ..];
                try folds.append(.{
                    .axis = .y,
                    .pos = try std.fmt.parseInt(i64, num_str, 10),
                });
            } else {
                return error.InvalidFormat;
            }
        }

        return TestData{
            .points = points.toOwnedSlice(),
            .folds = folds.toOwnedSlice(),
        };
    }

    pub fn deinit(this: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(this.points);
        allocator.free(this.folds);
        this.points = undefined;
        this.folds = undefined;
    }
};

pub fn challenge1(allocator: std.mem.Allocator, text: []const u8) !u64 {
    var data = try TestData.parse(allocator, text);
    defer data.deinit(allocator);

    const axis = @enumToInt(data.folds[0].axis);
    const fold_pos = data.folds[0].pos;

    var points_transformed = std.AutoArrayHashMap([2]i64, void).init(allocator);
    defer points_transformed.deinit();
    for (data.points) |point| {
        if (point[axis] > fold_pos) {
            var folded_point = point;
            folded_point[axis] = 2 * fold_pos - point[axis];

            try points_transformed.put(folded_point, {});
        } else {
            try points_transformed.put(point, {});
        }
    }

    return points_transformed.count();
}

test challenge1 {
    const TEST_DATA =
        \\6,10
        \\0,14
        \\9,10
        \\0,3
        \\10,4
        \\4,11
        \\6,0
        \\6,12
        \\4,1
        \\0,13
        \\10,12
        \\3,4
        \\3,0
        \\8,4
        \\1,10
        \\2,14
        \\8,10
        \\9,0
        \\
        \\fold along y=7
        \\fold along x=5
        \\
    ;
    try std.testing.expectEqual(@as(u64, 17), try challenge1(std.testing.allocator, TEST_DATA));
}
