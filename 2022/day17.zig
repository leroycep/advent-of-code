const std = @import("std");
const util = @import("util");
const glfw = @import("util").glfw;
const gl = @import("util").gl;
const nanovg = @import("util").nanovg;
const Grid = @import("util").Grid;
const ConstGrid = @import("util").ConstGrid;

const DATA = @embedFile("data/day17.txt");

const PIECES = [_]ConstGrid(u8){
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
    if (true) return error.SkipZigTest;
    const output = try calculateHighestRock(std.testing.allocator, TEST_DATA, 1000000000000);
    try std.testing.expectEqual(@as(u64, 1514285714288), output);
}

fn collides(map: ConstGrid(u8), piece: ConstGrid(u8), pos: @Vector(2, usize)) bool {
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
            if (piece_tile >= 1 and map_tile >= 1) {
                return true;
            }
            tiles_checked += 1;
        }
    }
    std.debug.assert(tiles_checked == piece.size[0] * piece.size[1]);
    return false;
}

const Data = struct {
    map: Grid(u8),
    piece: usize,
    pos: @Vector(2, usize),
    highest_rock: usize,
    gas_vents: []const u8,
    vent_index: usize,

    frame: i64 = 0,
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
        const map = try Grid(u8).allocWithRowAlign(allocator, .{ 7, 10_000 }, 4);
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
        const piece = PIECES[this.piece % PIECES.len];

        switch (this.move_state) {
            .vent => {
                const vent = this.gas_vents[this.vent_index];

                this.vent_index +%= 1;
                this.vent_index %= this.gas_vents.len;

                const new_pos = switch (vent) {
                    '<' => this.pos -| @Vector(2, usize){ 1, 0 },
                    '>' => this.pos +| @Vector(2, usize){ 1, 0 },
                    else => unreachable,
                };

                if (!collides(this.map.asConst(), piece, new_pos)) {
                    this.pos = new_pos;
                }
                this.move_state = .fall;
            },
            .fall => {
                if (!collides(this.map.asConst(), piece, this.pos + @Vector(2, usize){ 0, 1 })) {
                    this.pos += @Vector(2, usize){ 0, 1 };
                } else {
                    const map_region = this.map.getRegion(this.pos, piece.size);
                    var map_row_iterator = map_region.iterateRows();
                    var piece_row_iterator = piece.iterateRows();
                    while (map_row_iterator.next()) |row| {
                        const piece_row = piece_row_iterator.next() orelse break;
                        for (row) |*map_tile, i| {
                            const piece_tile = piece_row[i];
                            if (piece_tile > 0) {
                                map_tile.* = piece_tile * @intCast(u8, (this.piece % PIECES.len) + 2);
                            }
                        }
                    }
                    this.highest_rock = std.math.min(this.highest_rock, this.pos[1]);

                    this.piece += 1;
                    this.pos = @Vector(2, usize){ 2, this.highest_rock - PIECES[this.piece % PIECES.len].size[1] - 3 };
                }
                this.move_state = .vent;
            },
        }
    }
};

fn renderGrid(vg: nanovg, grid: ConstGrid(u8), offset: @Vector(2, f32)) void {
    var row_index: usize = 0;
    var rows = grid.iterateRows();
    while (rows.next()) |row| : (row_index += 1) {
        for (row) |tile, column| {
            if (tile >= 1) {
                vg.rect(offset[0] + @intToFloat(f32, column), offset[1] + @intToFloat(f32, row_index), 1, 1);
            }
        }
    }
}

const ColormappedGrid = struct {
    vg: nanovg,
    colormap: nanovg.Image,
    grid: ConstGrid(u8),
    grid_image: nanovg.Image,

    const Options = struct {
        palette: []const [4]u8 = &DEFAULT_PALETTE,
    };

    const DEFAULT_PALETTE = generate_palette: {
        var palette: [256][4]u8 = undefined;
        palette[0] = .{ 0, 0, 0, 0 };
        // ROY G BIV
        palette[1] = .{ 0xFF, 0xFF, 0xFF, 0xFF };
        palette[2] = .{ 0xFF, 0x00, 0x00, 0xFF };
        palette[3] = .{ 0xFF, 0xAA, 0x00, 0xFF };
        palette[4] = .{ 0xFF, 0xFF, 0x00, 0xFF };
        palette[5] = .{ 0x00, 0xFF, 0x00, 0xFF };
        palette[6] = .{ 0x00, 0x00, 0xFF, 0xFF };
        palette[7] = .{ 0x4B, 0x00, 0x82, 0xFF };
        palette[8] = .{ 0x80, 0x00, 0xFF, 0xFF };
        break :generate_palette palette;
    };

    fn init(vg: nanovg, grid: ConstGrid(u8), options: Options) @This() {
        const colormap = vg.createImageRGBA(@intCast(u32, options.palette.len), 1, .{ .nearest = true }, std.mem.sliceAsBytes(options.palette));

        const grid_image = vg.createImageAlpha(
            @intCast(u32, grid.stride),
            @intCast(u32, grid.size[1]),
            .{ .nearest = true },
            std.mem.sliceAsBytes(grid.data),
        );

        return @This(){
            .vg = vg,
            .colormap = colormap,
            .grid = grid,
            .grid_image = grid_image,
        };
    }

    fn updateImage(this: *@This(), grid: ConstGrid(u8)) void {
        std.debug.assert(grid.stride == this.grid.stride);
        std.debug.assert(std.mem.eql(usize, &this.grid.size, &grid.size));
        this.vg.updateImage(this.grid_image, std.mem.sliceAsBytes(grid.data));
        this.grid = grid;
    }

    fn deinit(this: *@This()) void {
        this.vg.deleteImage(this.colormap);
        this.vg.deleteImage(this.grid_image);
    }

    pub fn draw(this: @This(), offset: @Vector(2, f32), size: @Vector(2, f32)) void {
        this.drawRegion(offset, size, .{ 0, 0 }, this.grid.size);
    }

    pub fn drawRegion(this: @This(), offset: @Vector(2, f32), size: @Vector(2, f32), regionPos: [2]usize, regionSize: [2]usize) void {
        this.vg.beginPath();
        this.vg.rect(offset[0], offset[1], size[0], size[1]);
        const image_size = .{
            size[0] * @intToFloat(f32, this.grid.stride) / @intToFloat(f32, regionSize[0]),
            size[1] * @intToFloat(f32, this.grid.size[1]) / @intToFloat(f32, regionSize[1]),
        };
        const image_offset = .{
            size[0] * @intToFloat(f32, regionPos[0]) / @intToFloat(f32, regionSize[0]),
            size[1] * @intToFloat(f32, regionPos[1]) / @intToFloat(f32, regionSize[1]),
        };
        this.vg.fillPaint(this.vg.indexedImagePattern(
            offset[0] - image_offset[0],
            offset[1] - image_offset[1],
            image_size[0],
            image_size[1],
            0,
            this.grid_image,
            this.colormap,
            1,
        ));
        this.vg.fill();
    }
};

pub fn main() !void {
    const ctx = try util.Context.init(.{ .title = "Advent of Code - Day 17" });
    defer ctx.deinit();

    var app_data: Data = undefined;
    try app_data.init(ctx.allocator, TEST_DATA);
    defer app_data.deinit(ctx.allocator);

    if (!ctx.recording and ctx.window.getKey(.space) == .press) {
        app_data.paused = !app_data.paused;
    }

    var map_image = ColormappedGrid.init(ctx.vg, app_data.map.asConst(), .{});
    defer map_image.deinit();

    while (!ctx.window.shouldClose()) : (app_data.frame += 1) {
        if (!app_data.paused and app_data.piece < 1_000_000) {
            app_data.update();
        }

        const window_size = try ctx.window.getSize();
        const framebuffer_size = try ctx.window.getFramebufferSize();
        const content_scale = try ctx.window.getContentScale();
        const pixel_ratio = @max(content_scale.x_scale, content_scale.y_scale);

        gl.viewport(0, 0, framebuffer_size.width, framebuffer_size.height);
        gl.clearColor(0, 0, 0, 1);
        gl.clear(.{ .color = true, .depth = true, .stencil = true });

        ctx.vg.beginFrame(@intToFloat(f32, window_size.width), @intToFloat(f32, window_size.height), pixel_ratio);

        const viewport_height = app_data.highest_rock - 7;
        // const last_row_can_see = std.math.min(app_data.map.size[1] - viewport_height, (window_size.height / 8) + 2);
        // const map_region = app_data.map.getRegion(.{ 0, viewport_height }, .{ app_data.map.size[0], last_row_can_see });

        ctx.vg.scale(8, 8);

        map_image.updateImage(app_data.map.asConst());
        map_image.drawRegion(.{ 0, 0 }, .{ 7, @intToFloat(f32, app_data.map.size[1] - viewport_height) }, .{ 0, viewport_height }, .{ 7, app_data.map.size[1] - viewport_height });

        ctx.vg.beginPath();
        renderGrid(ctx.vg, PIECES[app_data.piece % PIECES.len], .{ @intToFloat(f32, app_data.pos[0]), @intToFloat(f32, app_data.pos[1] - viewport_height) });
        ctx.vg.fillColor(nanovg.rgba(0xAA, 0xAA, 0xAA, 0xFF));
        ctx.vg.fill();

        ctx.vg.beginPath();
        ctx.vg.rect(0, @intToFloat(f32, app_data.map.size[1] - viewport_height), 7, 1);
        ctx.vg.fillColor(nanovg.rgba(0x11, 0xAA, 0x11, 0xFF));
        ctx.vg.fill();

        if (app_data.highest_rock + 1 < app_data.map.size[1]) {
            var rows_ignored: usize = 0;
            while (rows_ignored < (app_data.map.size[1] - app_data.highest_rock) / 2) : (rows_ignored += 1) {
                const filled = app_data.map.asConst().getRegion(.{ 0, app_data.highest_rock }, .{ 7, app_data.map.size[1] - app_data.highest_rock - rows_ignored });
                const top_half = filled.getRegion(.{ 0, 0 }, .{ 7, filled.size[1] / 2 });
                const bottom_half = filled.getRegion(.{ 0, filled.size[1] / 2 }, .{ 7, filled.size[1] / 2 });
                if (top_half.eql(bottom_half)) {
                    app_data.paused = true;

                    map_image.drawRegion(.{ 64, 2 }, .{ 7, @intToFloat(f32, top_half.size[1]) }, .{ 0, app_data.highest_rock }, .{ 7, top_half.size[1] });

                    ctx.vg.resetTransform();
                    blk: {
                        var number_of_blocks: usize = 0;
                        var blocks_of_each_piece: [PIECES.len]usize = [1]usize{0} ** PIECES.len;
                        var map_row_iterator = top_half.iterateRows();
                        while (map_row_iterator.next()) |row| {
                            for (row) |tile| {
                                if (tile > 0) {
                                    number_of_blocks += 1;
                                }
                                if (tile >= 2) {
                                    blocks_of_each_piece[tile - 2] += 1;
                                }
                            }
                        }

                        var number_of_each_piece = blocks_of_each_piece;
                        var total_pieces: usize = 0;
                        for (number_of_each_piece) |*count, index| {
                            count.* /= std.mem.count(u8, PIECES[index].data, &.{1});
                            total_pieces += count.*;
                        }

                        var buf: [200]u8 = undefined;
                        const text = std.fmt.bufPrint(&buf,
                            \\number of blocks = {}
                            \\blocks of each piece = {any}
                            \\number of each piece = {any}
                            \\total number pieces = {}
                            \\height = {}
                        , .{ number_of_blocks, blocks_of_each_piece, number_of_each_piece, total_pieces, top_half.size[1] }) catch break :blk;

                        ctx.vg.beginPath();
                        ctx.vg.fontFace("sans");
                        ctx.vg.fillColor(nanovg.rgba(0xFF, 0xFF, 0xFF, 0xFF));
                        _ = ctx.vg.textBox(100, 500, 200, text);
                    }
                }
            }
        }

        ctx.vg.resetTransform();
        var textx: f32 = 100;
        for (app_data.gas_vents) |v, i| {
            ctx.vg.beginPath();
            ctx.vg.fontFace("sans");
            ctx.vg.fillColor(nanovg.rgba(0xFF, 0xFF, 0xFF, 0xFF));
            const new_textx = ctx.vg.text(textx, 100, &.{v});
            if (i == app_data.vent_index) {
                ctx.vg.beginPath();
                ctx.vg.rect(textx, 90, new_textx - textx, 10);
                ctx.vg.strokeColor(nanovg.rgba(0xFF, 0xAA, 0x11, 0xFF));
                ctx.vg.stroke();
            }
            textx = new_textx;
        }

        blk: {
            var buf: [200]u8 = undefined;
            const text = std.fmt.bufPrint(&buf,
                \\highest rock = {}
                \\pos = {}
                \\number of pieces = {}
                \\vent = {}/{}
            , .{ app_data.highest_rock, app_data.pos, app_data.piece, app_data.vent_index + 1, app_data.gas_vents.len }) catch break :blk;

            ctx.vg.beginPath();
            ctx.vg.fontFace("sans");
            ctx.vg.fillColor(nanovg.rgba(0xFF, 0xFF, 0xFF, 0xFF));
            _ = ctx.vg.textBox(100, 200, 200, text);
        }

        ctx.vg.endFrame();
        try ctx.showFrame(app_data.frame);
    }

    try ctx.flush(app_data.frame);
}
