const std = @import("std");
const util = @import("util");
const glfw = @import("util").glfw;
const gl = @import("util").gl;
const nanovg = @import("util").nanovg;
const Grid = @import("util").Grid;
const ConstGrid = @import("util").ConstGrid;

const DATA = @embedFile("data/day23.txt");

pub fn challenge1(allocator: std.mem.Allocator, input: []const u8) !i64 {
    var world = try World.parseData(allocator, input);
    defer world.deinit();

    while (world.step < 10) {
        _ = try world.stepElves();
    }

    var min = @Vector(2, i64){ std.math.maxInt(i64), std.math.maxInt(i64) };
    var max = @Vector(2, i64){ std.math.minInt(i64), std.math.minInt(i64) };
    for (world.getElves().keys()) |elf| {
        min = @min(min, elf);
        max = @max(max, elf);
    }

    const size = max - min + @Vector(2, i64){ 1, 1 };
    return @reduce(.Mul, size) - @intCast(i64, world.getElves().count());
}

pub fn challenge2(allocator: std.mem.Allocator, input: []const u8) !i64 {
    var world = try World.parseData(allocator, input);
    defer world.deinit();

    while (try world.stepElves()) {}

    return @intCast(i64, world.step);
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

test "challenge 2" {
    const output = try challenge2(std.testing.allocator, TEST_DATA);
    try std.testing.expectEqual(@as(i64, 20), output);
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

const World = struct {
    allocator: std.mem.Allocator,
    step: usize,
    elves: [2]std.AutoArrayHashMapUnmanaged(@Vector(2, i64), void),
    proposed: std.AutoArrayHashMapUnmanaged(@Vector(2, i64), usize),
    direction_to_move: []@Vector(2, i64),

    pub fn parseData(allocator: std.mem.Allocator, input: []const u8) !@This() {
        var elves = std.AutoArrayHashMapUnmanaged(@Vector(2, i64), void){};
        errdefer elves.deinit(allocator);

        var lines_iter = std.mem.tokenize(u8, input, "\n");
        var y: i64 = 0;
        while (lines_iter.next()) |line| : (y += 1) {
            for (line) |character, col| {
                if (character == '#') {
                    try elves.put(allocator, .{ @intCast(i64, col), y }, {});
                }
            }
        }

        const direction_to_move = try allocator.alloc(@Vector(2, i64), elves.count());
        errdefer allocator.free(direction_to_move);

        return @This(){
            .allocator = allocator,
            .step = 0,
            .elves = .{ elves, .{} },
            .proposed = .{},
            .direction_to_move = direction_to_move,
        };
    }

    pub fn deinit(this: *@This()) void {
        this.elves[0].deinit(this.allocator);
        this.elves[1].deinit(this.allocator);
        this.proposed.deinit(this.allocator);
        this.allocator.free(this.direction_to_move);
    }

    pub fn getElves(this: *@This()) *std.AutoArrayHashMapUnmanaged(@Vector(2, i64), void) {
        return &this.elves[this.step % 2];
    }

    pub fn stepElves(this: *@This()) !bool {
        try this.updateProposals();
        return try this.moveElves();
    }

    pub fn updateProposals(this: *@This()) !void {
        const elves_in = &this.elves[this.step % 2];
        this.proposed.clearRetainingCapacity();

        const first_direction = @intToEnum(Direction, @truncate(u4, this.step));

        std.mem.set(@Vector(2, i64), this.direction_to_move, .{ 0, 0 });

        for (this.getElves().keys()) |elf, elf_index| {
            if (!anyElvesInOffsets(elves_in.*, elf, &Direction.NEIGHBORS)) {
                continue;
            }

            var i: usize = 0;
            checking_directions: while (i < 4) : (i += 1) {
                const dir = @enumToInt(first_direction) +% @truncate(u2, i);

                if (anyElvesInOffsets(elves_in.*, elf, &Direction.CHECK_OFFSETS[dir])) {
                    continue :checking_directions;
                }

                this.direction_to_move[elf_index] = Direction.CHECK_OFFSETS[dir][1];

                const gop = try this.proposed.getOrPut(this.allocator, elf + Direction.CHECK_OFFSETS[dir][1]);
                if (!gop.found_existing) {
                    gop.value_ptr.* = 0;
                }
                gop.value_ptr.* += 1;
                break :checking_directions;
            }
        }
    }

    pub fn moveElves(this: *@This()) !bool {
        const elves_in = &this.elves[this.step % 2];
        const elves_out = &this.elves[(this.step +% 1) % 2];
        elves_out.clearRetainingCapacity();

        var any_moved = false;

        for (elves_in.keys()) |elf, elf_index| {
            const move = elf + this.direction_to_move[elf_index];

            if (@reduce(.And, elf == move)) {
                try elves_out.putNoClobber(this.allocator, elf, {});
                continue;
            }
            if (this.proposed.get(move).? > 1) {
                try elves_out.putNoClobber(this.allocator, elf, {});
            } else {
                try elves_out.putNoClobber(this.allocator, move, {});
                any_moved = true;
            }
        }

        this.step += 1;

        std.debug.assert(elves_in.count() == elves_out.count());
        return any_moved;
    }

    test parseData {
        var world = try parseData(std.testing.allocator, TEST_DATA);
        defer world.deinit();
        try std.testing.expectEqual(@as(usize, 22), world.elves[0].count());
    }

    fn anyElvesInOffsets(elves: std.AutoArrayHashMapUnmanaged(@Vector(2, i64), void), pos: @Vector(2, i64), offsets: []const @Vector(2, i64)) bool {
        for (offsets) |offset| {
            if (elves.contains(pos + offset)) {
                return true;
            }
        }
        return false;
    }

    test stepElves {
        var world = try World.parseData(std.testing.allocator,
            \\.....
            \\..##.
            \\..#..
            \\.....
            \\..##.
            \\.....
            \\
        );
        defer world.deinit();

        try std.testing.expect(world.getElves().contains(.{ 2, 1 }));
        try std.testing.expect(world.getElves().contains(.{ 3, 1 }));
        try std.testing.expect(world.getElves().contains(.{ 2, 2 }));
        try std.testing.expect(world.getElves().contains(.{ 2, 4 }));
        try std.testing.expect(world.getElves().contains(.{ 3, 4 }));

        std.debug.assert(try world.stepElves());
        try std.testing.expect(world.getElves().contains(.{ 2, 0 }));
        try std.testing.expect(world.getElves().contains(.{ 3, 0 }));
        try std.testing.expect(world.getElves().contains(.{ 2, 2 }));
        try std.testing.expect(world.getElves().contains(.{ 2, 4 }));
        try std.testing.expect(world.getElves().contains(.{ 3, 3 }));

        std.debug.assert(try world.stepElves());
        try std.testing.expect(world.getElves().contains(.{ 2, 1 }));
        try std.testing.expect(world.getElves().contains(.{ 3, 1 }));
        try std.testing.expect(world.getElves().contains(.{ 1, 2 }));
        try std.testing.expect(world.getElves().contains(.{ 2, 5 }));
        try std.testing.expect(world.getElves().contains(.{ 4, 3 }));

        std.debug.assert(try world.stepElves());
        try std.testing.expect(world.getElves().contains(.{ 2, 0 }));
        try std.testing.expect(world.getElves().contains(.{ 4, 1 }));
        try std.testing.expect(world.getElves().contains(.{ 0, 2 }));
        try std.testing.expect(world.getElves().contains(.{ 2, 5 }));
        try std.testing.expect(world.getElves().contains(.{ 4, 3 }));
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

    var world = try World.parseData(ctx.allocator, DATA);
    defer world.deinit();

    var still_running = true;

    var i: usize = 0;
    while (!ctx.window.shouldClose()) {
        try ctx.beginFrame();

        if (still_running) {
            still_running = try world.stepElves();
            i +%= 1;
        } else {
            ctx.window.setShouldClose(true);
        }

        var min = @Vector(2, f32){ std.math.inf(f32), std.math.inf(f32) };
        var max = @Vector(2, f32){ -std.math.inf(f32), -std.math.inf(f32) };
        for (world.getElves().keys()) |elf| {
            const elf_f = @Vector(2, f32){ @intToFloat(f32, elf[0]), @intToFloat(f32, elf[1]) };
            min = @min(min, elf_f);
            max = @max(max, elf_f);
        }

        const window_size_glfw = ctx.window.getSize() catch glfw.Window.Size{ .width = 1024, .height = 1024 };
        const window_size = @Vector(2, f32){ @intToFloat(f32, window_size_glfw.width), @intToFloat(f32, window_size_glfw.height) };

        const rect_size = max - min + @Vector(2, f32){ 1, 1 };
        const elf_size = std.math.floor(@max(1, @reduce(.Min, window_size / rect_size)));

        const space_left = (window_size - (rect_size * @splat(2, elf_size))) / @splat(2, elf_size);

        ctx.vg.scale(elf_size, elf_size);
        ctx.vg.translate(-min[0] + space_left[0] / 2, -min[1] + space_left[1] / 2);

        ctx.vg.beginPath();
        for (world.getElves().keys()) |elf| {
            ctx.vg.rect(@intToFloat(f32, elf[0]), @intToFloat(f32, elf[1]), 1, 1);
        }
        ctx.vg.fillColor(nanovg.rgba(0xFF, 0xFF, 0xFF, 0xFF));
        ctx.vg.fill();

        try ctx.endFrame();
    }

    try ctx.flush();
}
