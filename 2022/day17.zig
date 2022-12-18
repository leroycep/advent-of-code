const std = @import("std");
const glfw = @import("glfw");
const gl = @import("zgl");
const nanovg = @import("nanovg");
const Grid = @import("util").Grid;
const ConstGrid = @import("util").ConstGrid;

const DATA = @embedFile("data/day17.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try calculateHighestRock(arena.allocator(), DATA, 2022)});
    try out.print("{}\n", .{try calculateHighestRock(arena.allocator(), DATA, 1000000000000)});
}

const PIECES = [_]ConstGrid(u1){
    .{
        .data = &.{ 1, 1, 1, 1 },
        .stride = 4,
        .size = .{ 4, 1 },
    },
    .{
        .data = &.{
            0, 1, 0, //
            1, 1, 1,
            0, 1, 0,
        },
        .stride = 3,
        .size = .{ 3, 3 },
    },
    .{
        .data = &.{
            0, 0, 1, //
            0, 0, 1,
            1, 1, 1,
        },
        .stride = 3,
        .size = .{ 3, 3 },
    },
    .{
        .data = &.{ 1, 1, 1, 1 },
        .stride = 1,
        .size = .{ 1, 4 },
    },
    .{
        .data = &.{ 1, 1, 1, 1 },
        .stride = 2,
        .size = .{ 2, 2 },
    },
};

pub fn calculateHighestRock(allocator: std.mem.Allocator, input: []const u8, number_of_rocks: u64) !u64 {
    var data: Data = undefined;
    try data.init(allocator, input);
    defer data.deinit(allocator);

    while (data.piece < number_of_rocks) {
        data.update();
    }

    return data.map.size[1] - data.highest_rock;
}

const TEST_DATA = ">>><<><>><<<>><>>><<<>>><<<><<<>><>><<>>";
test "challenge 1" {
    const output = try calculateHighestRock(std.testing.allocator, TEST_DATA, 2022);
    try std.testing.expectEqual(@as(u64, 3068), output);
}

test "challenge 2" {
    const output = try calculateHighestRock(std.testing.allocator, TEST_DATA, 1000000000000);
    try std.testing.expectEqual(@as(u64, 1514285714288), output);
}

fn collides(map: ConstGrid(u1), piece: ConstGrid(u1), pos: @Vector(2, usize)) bool {
    if (@reduce(.Or, (pos + piece.size) > map.size)) return true;
    const map_region = map.getRegion(pos, piece.size);

    var map_iterator = map_region.iterateRows();
    var piece_iterator = piece.iterateRows();
    var tiles_checked: usize = 0;
    while (true) {
        const map_row = map_iterator.next() orelse break;
        const piece_row = piece_iterator.next() orelse break;
        std.debug.assert(map_row.len > 0);
        for (piece_row) |piece_tile, i| {
            const map_tile = map_row[i];
            if (piece_tile == 1 and map_tile == 1) {
                return true;
            }
            tiles_checked += 1;
        }
    }
    std.debug.assert(tiles_checked == piece.size[0] * piece.size[1]);
    return false;
}

const Data = struct {
    map: Grid(u1),
    piece: usize,
    pos: @Vector(2, usize),
    highest_rock: usize,
    gas_vents: []const u8,
    vent_index: usize,

    frame: usize = 0,
    move_state: MoveState = .vent,
    paused: bool = false,

    const MoveState = enum {
        vent,
        fall,
    };

    pub fn init(this: *@This(), allocator: std.mem.Allocator, input: []const u8) !void {
        for (input) |character| {
            if (character != '<' and character != '>') {
                return error.InvalidFormat;
            }
        }
        const map = try Grid(u1).alloc(allocator, .{ 7, 10_000 });
        map.set(0);
        this.* = .{
            .map = map,
            .piece = 0,
            .pos = .{ 2, map.size[1] - PIECES[0].size[1] - 3 },
            .highest_rock = map.size[1],
            .gas_vents = std.mem.trim(u8, input, " \n"),
            .vent_index = 0,
        };
    }

    pub fn deinit(this: *@This(), allocator: std.mem.Allocator) void {
        this.map.free(allocator);
    }

    pub fn update(this: *@This()) void {
        const piece = PIECES[app_data.piece % PIECES.len];

        switch (this.move_state) {
            .vent => {
                const vent = app_data.gas_vents[app_data.vent_index];

                app_data.vent_index +%= 1;
                app_data.vent_index %= app_data.gas_vents.len;

                const new_pos = switch (vent) {
                    '<' => app_data.pos -| @Vector(2, usize){ 1, 0 },
                    '>' => app_data.pos +| @Vector(2, usize){ 1, 0 },
                    else => unreachable,
                };

                if (!collides(app_data.map.asConst(), piece, new_pos)) {
                    app_data.pos = new_pos;
                }
                app_data.move_state = .fall;
            },
            .fall => {
                if (!collides(app_data.map.asConst(), piece, app_data.pos + @Vector(2, usize){ 0, 1 })) {
                    app_data.pos += @Vector(2, usize){ 0, 1 };
                } else {
                    const map_region = app_data.map.getRegion(app_data.pos, piece.size);
                    map_region.addSaturating(piece);
                    app_data.highest_rock = std.math.min(app_data.highest_rock, app_data.pos[1]);

                    app_data.piece += 1;
                    app_data.pos = @Vector(2, usize){ 2, app_data.highest_rock - PIECES[app_data.piece % PIECES.len].size[1] - 3 };
                }
                app_data.move_state = .vent;
            },
        }
    }
};

var app_data: Data = undefined;

pub fn graphicsInit(allocator: std.mem.Allocator, window: glfw.Window, vg: nanovg, recording: bool) !void {
    _ = window;
    _ = vg;
    _ = recording;
    try app_data.init(allocator, TEST_DATA);
}

pub fn graphicsDeinit(allocator: std.mem.Allocator, window: glfw.Window, vg: nanovg) void {
    _ = window;
    _ = vg;
    app_data.deinit(allocator);
}

pub fn graphicsRender(allocator: std.mem.Allocator, window: glfw.Window, vg: nanovg, recording: bool) !void {
    _ = allocator;

    if (!recording and window.getKey(.space) == .press) {
        app_data.paused = !app_data.paused;
    }

    if (recording and app_data.piece >= 100) {
        window.setShouldClose(true);
    }
    if (!app_data.paused and app_data.piece < 1_000_000) {
        app_data.update();
    }
    app_data.frame += 1;

    const window_size = try window.getSize();
    const framebuffer_size = try window.getFramebufferSize();
    const pixel_ratio = @intToFloat(f32, framebuffer_size.width) / @intToFloat(f32, window_size.width);

    gl.viewport(0, 0, framebuffer_size.width, framebuffer_size.height);
    gl.clearColor(0, 0, 0, 1);
    gl.clear(.{ .color = true, .depth = true, .stencil = true });

    vg.beginFrame(@intToFloat(f32, window_size.width), @intToFloat(f32, window_size.height), pixel_ratio);

    const viewport_height = app_data.highest_rock - 7;
    const last_row_can_see = std.math.min(app_data.map.size[1] - viewport_height, (window_size.height / 8) + 2);
    const map_region = app_data.map.getRegion(.{ 0, viewport_height }, .{ app_data.map.size[0], last_row_can_see });

    vg.beginPath();
    var row_index: usize = 0;
    var rows = map_region.asConst().iterateRows();
    while (rows.next()) |row| : (row_index += 1) {
        for (row) |tile, column| {
            if (tile == 1) {
                vg.rect(@intToFloat(f32, column * 8), @intToFloat(f32, row_index * 8), 7, 7);
            }
        }
    }
    vg.fillColor(nanovg.rgba(0xFF, 0xFF, 0xFF, 0xFF));
    vg.fill();

    vg.beginPath();
    row_index = 0;
    rows = PIECES[app_data.piece % PIECES.len].iterateRows();
    while (rows.next()) |row| : (row_index += 1) {
        for (row) |tile, column| {
            if (tile == 1) {
                vg.rect(@intToFloat(f32, (app_data.pos[0] + column) * 8), @intToFloat(f32, (app_data.pos[1] + row_index - viewport_height) * 8), 7, 7);
            }
        }
    }
    vg.fillColor(nanovg.rgba(0xAA, 0xAA, 0xAA, 0xFF));
    vg.fill();

    vg.beginPath();
    vg.rect(0, @intToFloat(f32, (app_data.map.size[1] - viewport_height) * 8), 7 * 8, 8);
    vg.fillColor(nanovg.rgba(0x11, 0xAA, 0x11, 0xFF));
    vg.fill();

    var textx: f32 = 100;
    for (app_data.gas_vents) |v, i| {
        vg.beginPath();
        vg.fontFace("sans");
        vg.fillColor(nanovg.rgba(0xFF, 0xFF, 0xFF, 0xFF));
        const new_textx = vg.text(textx, 100, &.{v});
        if (i == app_data.vent_index) {
            vg.beginPath();
            vg.rect(textx, 90, new_textx - textx, 10);
            vg.strokeColor(nanovg.rgba(0xFF, 0xAA, 0x11, 0xFF));
            vg.stroke();
        }
        textx = new_textx;
    }

    blk: {
        var buf: [50]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "highest rock = {}", .{app_data.highest_rock}) catch break :blk;

        vg.beginPath();
        vg.fontFace("sans");
        vg.fillColor(nanovg.rgba(0xFF, 0xFF, 0xFF, 0xFF));
        _ = vg.text(100, 200, text);
    }

    blk: {
        var buf: [50]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "pos = {}", .{app_data.pos}) catch break :blk;

        vg.beginPath();
        vg.fontFace("sans");
        vg.fillColor(nanovg.rgba(0xFF, 0xFF, 0xFF, 0xFF));
        _ = vg.text(100, 215, text);
    }

    blk: {
        var buf: [50]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "number of pieces = {}", .{app_data.piece}) catch break :blk;

        vg.beginPath();
        vg.fontFace("sans");
        vg.fillColor(nanovg.rgba(0xFF, 0xFF, 0xFF, 0xFF));
        _ = vg.text(100, 230, text);
    }

    if (app_data.highest_rock + 1 < app_data.map.size[1]) {
        var rows_ignored: usize = 0;
        while (rows_ignored < (app_data.map.size[1] - app_data.highest_rock) / 2) : (rows_ignored += 1) {
            const filled = app_data.map.asConst().getRegion(.{ 0, app_data.highest_rock }, .{ 7, app_data.map.size[1] - app_data.highest_rock - rows_ignored });
            const top_half = filled.getRegion(.{ 0, 0 }, .{ 7, filled.size[1] / 2 });
            const bottom_half = filled.getRegion(.{ 0, filled.size[1] / 2 }, .{ 7, filled.size[1] / 2 });
            if (top_half.eql(bottom_half)) {
                app_data.paused = true;

                vg.beginPath();
                row_index = 0;
                rows = top_half.iterateRows();
                while (rows.next()) |row| : (row_index += 1) {
                    for (row) |tile, column| {
                        if (tile == 1) {
                            vg.rect(@intToFloat(f32, column * 8) + 512, @intToFloat(f32, row_index * 8) + 16, 7, 7);
                        }
                    }
                }
                vg.fillColor(nanovg.rgba(0xAA, 0xAA, 0xAA, 0xFF));
                vg.fill();
            }
        }
    }

    vg.endFrame();
}