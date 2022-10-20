const std = @import("std");

const DATA = @embedFile("./data/day12.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(arena.allocator(), DATA)});
    // try out.print("{}\n", .{try challenge2(arena.allocator(), DATA)});
}

pub fn challenge1(allocator: std.mem.Allocator, text: []const u8) !u64 {
    var caves = CaveGraph{ .allocator = allocator };
    defer caves.deinit();

    var line_iter = std.mem.tokenize(u8, text, "\n");
    while (line_iter.next()) |line| {
        var cave_iter = std.mem.tokenize(u8, line, "-");
        const cave_names = [2][]const u8{
            cave_iter.next() orelse continue,
            cave_iter.next() orelse continue,
        };
        const cave_vertices = [2]usize{
            try caves.getOrPutCave(cave_names[0]),
            try caves.getOrPutCave(cave_names[1]),
        };
        try caves.addPath(cave_vertices);
    }
    caves.dump();

    return try caves.numberOfValidPathsToEnd(caves.name_to_vertex.get("start").?, null);
}

const CaveGraph = struct {
    allocator: std.mem.Allocator,
    vertices: std.MultiArrayList(Cave) = .{},
    name_to_vertex: std.StringHashMapUnmanaged(usize) = .{},

    pub const Cave = struct {
        edges: std.ArrayListUnmanaged(usize) = .{},
        name: []const u8,
        large: bool,
    };

    pub fn deinit(this: *@This()) void {
        this.name_to_vertex.deinit(this.allocator);
        for (this.vertices.items(.edges)) |*edges| {
            edges.deinit(this.allocator);
        }
        this.vertices.deinit(this.allocator);
    }

    pub fn getOrPutCave(this: *@This(), cave_name: []const u8) !usize {
        const gop = try this.name_to_vertex.getOrPut(this.allocator, cave_name);
        if (!gop.found_existing) {
            gop.value_ptr.* = this.vertices.len;
            try this.vertices.append(this.allocator, .{
                .name = cave_name,
                .large = std.ascii.isUpper(cave_name[0]),
            });
        }
        return gop.value_ptr.*;
    }

    pub fn addPath(this: *@This(), caves: [2]usize) !void {
        try this.vertices.items(.edges)[caves[0]].append(this.allocator, caves[1]);
        try this.vertices.items(.edges)[caves[1]].append(this.allocator, caves[0]);
    }

    pub fn dump(this: *@This()) void {
        std.debug.print("\n", .{});
        for (this.vertices.items(.edges)) |edges, vertex| {
            for (edges.items) |destination| {
                std.debug.print("{s} -- {s}\n", .{
                    this.vertices.items(.name)[vertex],
                    this.vertices.items(.name)[destination],
                });
            }
        }
        std.debug.print("\n", .{});
    }

    pub fn numberOfValidPathsToEnd(this: *@This(), vertex_index: usize, path_was_explored_opt: ?[]const bool) !u64 {
        if (std.mem.eql(u8, "end", this.vertices.items(.name)[vertex_index])) {
            return 1;
        }

        const next_paths_explored = try this.allocator.alloc(bool, this.vertices.len);
        defer this.allocator.free(next_paths_explored);

        var number_of_valid_paths: u64 = 0;

        for (this.vertices.items(.edges)[vertex_index].items) |destination| {
            if (!this.vertices.items(.large)[destination] and path_was_explored_opt != null and path_was_explored_opt.?[destination]) continue;
            if (path_was_explored_opt) |path_was_explored| {
                std.mem.copy(bool, next_paths_explored, path_was_explored);
            } else {
                std.mem.set(bool, next_paths_explored, false);
                next_paths_explored[vertex_index] = true;
            }
            next_paths_explored[destination] = true;
            number_of_valid_paths += try this.numberOfValidPathsToEnd(destination, next_paths_explored);
        }

        return number_of_valid_paths;
    }
};

test challenge1 {
    try std.testing.expectEqual(@as(u64, 10), try challenge1(std.testing.allocator,
        \\start-A
        \\start-b
        \\A-c
        \\A-b
        \\b-d
        \\A-end
        \\b-end
        \\
    ));
}

test "challenge1 -- case 2" {
    try std.testing.expectEqual(@as(u64, 19), try challenge1(std.testing.allocator,
        \\dc-end
        \\HN-start
        \\start-kj
        \\dc-start
        \\dc-HN
        \\LN-dc
        \\HN-end
        \\kj-sa
        \\kj-HN
        \\kj-dc
        \\
    ));
}
