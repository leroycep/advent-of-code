const std = @import("std");

const DATA = @embedFile("data/day07.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(arena.allocator(), DATA)});
    try out.print("{}\n", .{try challenge2(arena.allocator(), DATA)});
}

const Entry = union(enum) {
    file: u64,
    directory: usize,
};

pub fn challenge1(allocator: std.mem.Allocator, input: []const u8) !u64 {
    var directories = std.ArrayList(std.StringHashMapUnmanaged(Entry)).init(allocator);
    defer {
        for (directories.items) |*dir| {
            dir.deinit(allocator);
        }
        directories.deinit();
    }

    try directories.append(.{});

    var path = std.ArrayList(usize).init(allocator);
    defer path.deinit();
    try path.append(0);

    var lines_iterator = std.mem.split(u8, input, "\n");
    while (lines_iterator.next()) |line| {
        var word_iterator = std.mem.tokenize(u8, line, " ");
        const line_type = word_iterator.next() orelse continue;

        const dir = &directories.items[path.items[path.items.len - 1]];

        if (std.mem.eql(u8, line_type, "$")) {
            // do command
            const command = word_iterator.next().?;
            if (std.mem.eql(u8, command, "cd")) {
                const new_directory = word_iterator.next().?;
                if (std.mem.eql(u8, new_directory, "..")) {
                    _ = path.pop();
                } else if (std.mem.eql(u8, new_directory, "/")) {
                    path.shrinkRetainingCapacity(0);
                    try path.append(0);
                } else {
                    std.debug.print("current dir = {}\n", .{path.items[path.items.len - 1]});
                    std.debug.print("new dir = {s}\n", .{new_directory});
                    const gop = try dir.getOrPut(allocator, new_directory);
                    if (!gop.found_existing) {
                        gop.value_ptr.* = .{ .directory = directories.items.len };
                    }
                    try path.append(gop.value_ptr.directory);
                    if (!gop.found_existing) {
                        try directories.append(.{});
                    }
                }
            } else if (std.mem.eql(u8, command, "ls")) {
                // Ignore ls
            } else {
                std.debug.print("unknown command: {s}\n", .{command});
            }
        } else if (std.mem.eql(u8, line_type, "dir")) {
            // directory entry
            const new_dir_name = word_iterator.next().?;
            const gop = try dir.getOrPut(allocator, new_dir_name);
            if (!gop.found_existing) {
                gop.value_ptr.* = .{ .directory = directories.items.len };
                try directories.append(.{});
            }
        } else {
            // file entry
            const file_size = try std.fmt.parseInt(u64, line_type, 10);

            const new_file_name = word_iterator.next().?;
            try dir.put(allocator, new_file_name, Entry{ .file = file_size });
        }
    }

    printTree(0, directories.items);

    return totalSizeOfSmallDirectories(0, directories.items);
}

pub fn printTree(inode: usize, directories: []const std.StringHashMapUnmanaged(Entry)) void {
    const dir = directories[inode];
    var iterator = dir.iterator();
    while (iterator.next()) |entry| {
        switch (entry.value_ptr.*) {
            .directory => |sub_dir_inode| {
                std.debug.print("dir {s}: [\n", .{entry.key_ptr.*});
                printTree(sub_dir_inode, directories);
                std.debug.print("]\n", .{});
            },
            .file => |file_size| {
                std.debug.print("{s} {}\n", .{ entry.key_ptr.*, file_size });
            },
        }
    }
}

pub fn totalSizeOfSmallDirectories(inode: usize, directories: []const std.StringHashMapUnmanaged(Entry)) u64 {
    var total_size: u64 = 0;
    const size_of_this_path = treeSize(inode, directories);
    if (size_of_this_path <= 100_000) {
        total_size += size_of_this_path;
    }

    const dir = directories[inode];
    var iterator = dir.iterator();
    while (iterator.next()) |entry| {
        switch (entry.value_ptr.*) {
            .directory => |sub_dir_inode| {
                total_size += totalSizeOfSmallDirectories(sub_dir_inode, directories);
            },
            .file => {},
        }
    }
    return total_size;
}

pub fn treeSize(inode: usize, directories: []const std.StringHashMapUnmanaged(Entry)) u64 {
    var size: u64 = 0;
    const dir = directories[inode];
    var iterator = dir.iterator();
    while (iterator.next()) |entry| {
        switch (entry.value_ptr.*) {
            .directory => |sub_dir_inode| {
                size += treeSize(sub_dir_inode, directories);
            },
            .file => |file_size| size += file_size,
        }
    }
    return size;
}

const TEST_INPUT =
    \\$ cd /
    \\$ ls
    \\dir a
    \\14848514 b.txt
    \\8504156 c.dat
    \\dir d
    \\$ cd a
    \\$ ls
    \\dir e
    \\29116 f
    \\2557 g
    \\62596 h.lst
    \\$ cd e
    \\$ ls
    \\584 i
    \\$ cd ..
    \\$ cd ..
    \\$ cd d
    \\$ ls
    \\4060174 j
    \\8033020 d.log
    \\5626152 d.ext
    \\7214296 k
    \\
;

test challenge1 {
    const output = try challenge1(std.testing.allocator, TEST_INPUT);
    try std.testing.expectEqual(@as(usize, 95437), output);
}

pub fn challenge2(allocator: std.mem.Allocator, input: []const u8) !usize {
    _ = allocator;
    _ = input;
    return 0;
}

test challenge2 {
    if (true) return error.SkipZigTest;
    const output = try challenge2(std.testing.allocator, TEST_INPUT);
    try std.testing.expectEqual(@as(usize, std.math.maxInt(usize)), output);
}
