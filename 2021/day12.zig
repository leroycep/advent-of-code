const std = @import("std");

const DATA = @embedFile("./data/day12.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(arena.allocator(), DATA)});
    try out.print("{}\n", .{try challenge2(arena.allocator(), DATA)});
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

const PathSearchVertex = struct {
    cave: usize,
    twice_small_cave: ?usize,
    next_path_to_consider: usize,
};

pub fn challenge2(allocator: std.mem.Allocator, text: []const u8) !u64 {
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

    const cave_visit_counts = try allocator.alloc(u32, caves.vertices.len);
    std.mem.set(u32, cave_visit_counts, 0);
    var stack = std.ArrayList(PathSearchVertex).init(allocator);
    defer {
        allocator.free(cave_visit_counts);
        stack.deinit();
    }

    const start_cave = caves.name_to_vertex.get("start").?;
    try stack.append(.{
        .cave = start_cave,
        .twice_small_cave = null,
        .next_path_to_consider = 0,
    });
    cave_visit_counts[start_cave] += 1;
    const end_cave = caves.name_to_vertex.get("end").?;

    var number_of_paths: u64 = 0;
    while (stack.items.len > 0) {
        if (false) {
            for (stack.items) |vert| {
                std.debug.print("{s},", .{caves.vertices.items(.name)[vert.cave]});
            }
            std.debug.print("\n", .{});
        }

        const current = &stack.items[stack.items.len - 1];
        if (current.cave == end_cave) {
            if (false) std.debug.print("end cave\n\n", .{});
            cave_visit_counts[current.cave] -= 1;
            _ = stack.pop();
            number_of_paths += 1;
            continue;
        }
        if (current.cave == start_cave and cave_visit_counts[current.cave] > 1) {
            cave_visit_counts[current.cave] -= 1;
            _ = stack.pop();
            continue;
        }

        var twice_small_cave = current.twice_small_cave;
        const is_large = caves.vertices.items(.large)[current.cave];
        if (cave_visit_counts[current.cave] > 1 and !is_large and current.twice_small_cave == null) {
            if (false) std.debug.print("twice small cave\n", .{});
            twice_small_cave = current.cave;
        } else if (cave_visit_counts[current.cave] > 1 and !is_large) {
            if (false) std.debug.print("cannot visit again (visits = {})\n\n", .{cave_visit_counts[current.cave]});
            cave_visit_counts[current.cave] -= 1;
            _ = stack.pop();
            continue;
        }

        const paths = caves.vertices.items(.edges)[current.cave].items;
        if (false) std.debug.print("paths = {any}, next = {}\n", .{ paths, current.next_path_to_consider });
        if (current.next_path_to_consider >= paths.len) {
            cave_visit_counts[current.cave] -= 1;
            _ = stack.pop();
            continue;
        }
        const next_cave = paths[current.next_path_to_consider];
        current.next_path_to_consider += 1;
        try stack.append(.{
            .cave = next_cave,
            .twice_small_cave = twice_small_cave,
            .next_path_to_consider = 0,
        });
        cave_visit_counts[next_cave] += 1;
        if (false) std.debug.print("\n", .{});
    }

    return number_of_paths;
}

test challenge2 {
    try std.testing.expectEqual(@as(u64, 36), try challenge2(std.testing.allocator,
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

test "challenge2 -- case 2" {
    try std.testing.expectEqual(@as(u64, 103), try challenge2(std.testing.allocator,
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

test "challenge2 -- case 3" {
    try std.testing.expectEqual(@as(u64, 3509), try challenge2(std.testing.allocator,
        \\fs-end
        \\he-DX
        \\fs-he
        \\start-DX
        \\pj-DX
        \\end-zg
        \\zg-sl
        \\zg-pj
        \\pj-he
        \\RW-he
        \\fs-DX
        \\pj-RW
        \\zg-RW
        \\start-pj
        \\he-WI
        \\zg-he
        \\pj-fs
        \\start-RW
        \\
    ));
}
