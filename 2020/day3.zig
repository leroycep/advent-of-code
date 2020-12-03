const std = @import("std");

const INPUT = @embedFile("day3.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = &gpa.allocator;

    const map = break_into_lines: {
        var lines = std.ArrayList([]const u8).init(allocator);
        defer lines.deinit();
        
        var line_iter = std.mem.tokenize(INPUT, "\n\r ");
        while (line_iter.next()) |line| {
            try lines.append(line);
        }

        break :break_into_lines lines.toOwnedSlice();
    };
    defer allocator.free(map);

    const stdout = std.io.getStdOut().writer();

    const trees_3r1d = calcTreesEncountered(map, 3, 1);
    try stdout.print("Encountered {} trees on 3 right 1 down path\n", .{trees_3r1d});
}

fn calcTreesEncountered(map: []const []const u8, right: usize, down: usize) usize {
    var num_trees: usize = 0;
    var pos = [2]usize{0,0};
    while (pos[1] < map.len) {
        defer {
            pos[0] += right;
            pos[1] += down;
        }
        
        const wrapped_xpos = pos[0] % map[pos[1]].len;
        const item_on_map = map[pos[1]][wrapped_xpos];
        switch(item_on_map) {
            '.' => {},
            '#' => num_trees += 1,
            else => |c| std.log.warn("Unknown item '{}'", .{c}),
        }
    }
    return num_trees;
}
