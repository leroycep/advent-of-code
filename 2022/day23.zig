const std = @import("std");
const util = @import("util");
const glfw = @import("util").glfw;
const gl = @import("util").gl;
const nanovg = @import("util").nanovg;
const Grid = @import("util").Grid;
const ConstGrid = @import("util").ConstGrid;

const DATA = @embedFile("data/day23.txt");

pub fn challenge1(allocator: std.mem.Allocator, input: []const u8) !i64 {
    var elf_buffer: [2]std.AutoArrayHashMap(@Vector(2, i64), void) = undefined;
    elf_buffer[0] = try parseData(allocator, input);
    defer elf_buffer[0].deinit();
    elf_buffer[1] = std.AutoArrayHashMap(@Vector(2, i64), void).init(allocator);
    defer elf_buffer[1].deinit();

    var i: usize = 0;
    while (i < 10) : (i += 1) {
        try stepElves(allocator, elf_buffer[i % 2], &elf_buffer[(i + 1) % 2], @intToEnum(Direction, @truncate(u4, i)));
    }

    var min = @Vector(2, i64){ std.math.maxInt(i64), std.math.maxInt(i64) };
    var max = @Vector(2, i64){ std.math.minInt(i64), std.math.minInt(i64) };
    for (elf_buffer[i % 2].keys()) |elf| {
        min = @min(min, elf);
        max = @max(max, elf);
    }

    const size = max - min + @Vector(2, i64){ 1, 1 };
    return @reduce(.Mul, size) - @intCast(i64, elf_buffer[i % 2].count());
}

const TEST_DATA =
    \\....#..
    \\..###.#
    \\#...#.#
    \\.#...##
    \\#.###..
    \\##.#.##
    \\.#..#..
    \\
;

test "challenge 1" {
    const output = try challenge1(std.testing.allocator, TEST_DATA);
    try std.testing.expectEqual(@as(i64, 110), output);
}

pub fn parseData(allocator: std.mem.Allocator, input: []const u8) !std.AutoArrayHashMap(@Vector(2, i64), void) {
    var elves = std.AutoArrayHashMap(@Vector(2, i64), void).init(allocator);
    errdefer elves.deinit();

    var lines_iter = std.mem.tokenize(u8, input, "\n");
    var y: i64 = 0;
    while (lines_iter.next()) |line| : (y += 1) {
        for (line) |character, col| {
            if (character == '#') {
                try elves.put(.{ @intCast(i64, col), y }, {});
            }
        }
    }

    return elves;
}

test parseData {
    var elves = try parseData(std.testing.allocator, TEST_DATA);
    defer elves.deinit();
    try std.testing.expectEqual(@as(usize, 22), elves.count());
}

const Direction = enum(u2) {
    north = 0,
    south = 1,
    west = 2,
    east = 3,

    const NEIGHBORS = [_]@Vector(2, i64){
        .{ -1, -1 }, .{ 0, -1 }, .{ 1, -1 },
        .{ -1, 0 },  .{ 1, 0 },  .{ -1, 1 },
        .{ 0, 1 },   .{ 1, 1 },
    };
    const CHECK_OFFSETS = blk: {
        var offsets: [4][3]@Vector(2, i64) = undefined;
        offsets[@enumToInt(Direction.north)] = .{ .{ -1, -1 }, .{ 0, -1 }, .{ 1, -1 } };
        offsets[@enumToInt(Direction.south)] = .{ .{ -1, 1 }, .{ 0, 1 }, .{ 1, 1 } };
        offsets[@enumToInt(Direction.west)] = .{ .{ -1, -1 }, .{ -1, 0 }, .{ -1, 1 } };
        offsets[@enumToInt(Direction.east)] = .{ .{ 1, -1 }, .{ 1, 0 }, .{ 1, 1 } };
        break :blk offsets;
    };
};

pub fn stepElves(allocator: std.mem.Allocator, elves_in: std.AutoArrayHashMap(@Vector(2, i64), void), elves_out: *std.AutoArrayHashMap(@Vector(2, i64), void), first_direction: Direction) !void {
    elves_out.clearRetainingCapacity();

    var proposed = std.AutoArrayHashMap(@Vector(2, i64), usize).init(allocator);
    defer proposed.deinit();

    var direction_to_move = try allocator.alloc(@Vector(2, i64), elves_in.count());
    defer allocator.free(direction_to_move);
    std.mem.set(@Vector(2, i64), direction_to_move, .{ 0, 0 });

    for (elves_in.keys()) |elf, elf_index| {
        if (!anyElvesInOffsets(elves_in, elf, &Direction.NEIGHBORS)) {
            continue;
        }

        var i: usize = 0;
        checking_directions: while (i < 4) : (i += 1) {
            const dir = @enumToInt(first_direction) +% @truncate(u2, i);

            if (anyElvesInOffsets(elves_in, elf, &Direction.CHECK_OFFSETS[dir])) {
                continue :checking_directions;
            }

            direction_to_move[elf_index] = Direction.CHECK_OFFSETS[dir][1];

            const gop = try proposed.getOrPut(elf + Direction.CHECK_OFFSETS[dir][1]);
            if (!gop.found_existing) {
                gop.value_ptr.* = 0;
            }
            gop.value_ptr.* += 1;
            break :checking_directions;
        }
    }

    for (elves_in.keys()) |elf, elf_index| {
        const move = elf + direction_to_move[elf_index];

        if (@reduce(.And, elf == move)) {
            try elves_out.putNoClobber(elf, {});
            continue;
        }
        if (proposed.get(move).? > 1) {
            try elves_out.putNoClobber(elf, {});
        } else {
            try elves_out.putNoClobber(move, {});
        }
    }

    std.debug.assert(elves_in.count() == elves_out.count());
}

test stepElves {
    var elves = try parseData(std.testing.allocator,
        \\.....
        \\..##.
        \\..#..
        \\.....
        \\..##.
        \\.....
        \\
    );
    defer elves.deinit();

    try std.testing.expect(elves.contains(.{ 2, 1 }));
    try std.testing.expect(elves.contains(.{ 3, 1 }));
    try std.testing.expect(elves.contains(.{ 2, 2 }));
    try std.testing.expect(elves.contains(.{ 2, 4 }));
    try std.testing.expect(elves.contains(.{ 3, 4 }));

    var elves_out = try elves.clone();
    defer elves_out.deinit();

    try stepElves(std.testing.allocator, elves, &elves_out, .north);
    std.mem.swap(std.AutoArrayHashMap(@Vector(2, i64), void), &elves, &elves_out);
    try std.testing.expect(elves.contains(.{ 2, 0 }));
    try std.testing.expect(elves.contains(.{ 3, 0 }));
    try std.testing.expect(elves.contains(.{ 2, 2 }));
    try std.testing.expect(elves.contains(.{ 2, 4 }));
    try std.testing.expect(elves.contains(.{ 3, 3 }));

    try stepElves(std.testing.allocator, elves, &elves_out, .south);
    std.mem.swap(std.AutoArrayHashMap(@Vector(2, i64), void), &elves, &elves_out);
    try std.testing.expect(elves.contains(.{ 2, 1 }));
    try std.testing.expect(elves.contains(.{ 3, 1 }));
    try std.testing.expect(elves.contains(.{ 1, 2 }));
    try std.testing.expect(elves.contains(.{ 2, 5 }));
    try std.testing.expect(elves.contains(.{ 4, 3 }));

    try stepElves(std.testing.allocator, elves, &elves_out, .west);
    std.mem.swap(std.AutoArrayHashMap(@Vector(2, i64), void), &elves, &elves_out);
    try std.testing.expect(elves.contains(.{ 2, 0 }));
    try std.testing.expect(elves.contains(.{ 4, 1 }));
    try std.testing.expect(elves.contains(.{ 0, 2 }));
    try std.testing.expect(elves.contains(.{ 2, 5 }));
    try std.testing.expect(elves.contains(.{ 4, 3 }));
}

fn anyElvesInOffsets(elves: std.AutoArrayHashMap(@Vector(2, i64), void), pos: @Vector(2, i64), offsets: []const @Vector(2, i64)) bool {
    for (offsets) |offset| {
        if (elves.contains(pos + offset)) {
            return true;
        }
    }
    return false;
}

pub fn main() !void {
    const ctx = try util.Context.init(.{ .title = "Advent of Code - Day 21" });
    defer ctx.deinit();

    const stdout = std.io.getStdOut();

    const answer1 = try challenge1(ctx.allocator, DATA);
    try stdout.writer().print("{}\n", .{answer1});

    var elf_buffer: [2]std.AutoArrayHashMap(@Vector(2, i64), void) = undefined;
    elf_buffer[0] = try parseData(ctx.allocator, DATA);
    defer elf_buffer[0].deinit();
    elf_buffer[1] = std.AutoArrayHashMap(@Vector(2, i64), void).init(ctx.allocator);
    defer elf_buffer[1].deinit();

    var i: usize = 0;
    while (!ctx.window.shouldClose()) {
        try ctx.beginFrame();

        if (i < 10) {
            try stepElves(ctx.allocator, elf_buffer[i % 2], &elf_buffer[(i + 1) % 2], @intToEnum(Direction, @truncate(u4, i)));
            i +%= 1;
        }

        var min = @Vector(2, i64){ std.math.maxInt(i64), std.math.maxInt(i64) };
        var max = @Vector(2, i64){ std.math.minInt(i64), std.math.minInt(i64) };
        for (elf_buffer[i % 2].keys()) |elf| {
            min = @min(min, elf);
            max = @max(max, elf);
        }

        const midpoint = (min + max) * @splat(2, @as(i64, 10));
        ctx.vg.translate(@intToFloat(f32, midpoint[0]), @intToFloat(f32, midpoint[1]));

        ctx.vg.beginPath();
        for (elf_buffer[i % 2].keys()) |elf| {
            const pos = elf * @splat(2, @as(i64, 20));
            ctx.vg.circle(@intToFloat(f32, pos[0]), @intToFloat(f32, pos[1]), 10);
        }
        ctx.vg.fillColor(nanovg.rgba(0xFF, 0xFF, 0xFF, 0xFF));
        ctx.vg.fill();

        try ctx.endFrame();
    }

    try ctx.flush();
}
