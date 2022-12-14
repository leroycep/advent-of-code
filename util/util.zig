const std = @import("std");

pub fn Grid(comptime T: type) type {
    return struct {
        data: []T,
        stride: usize,
        size: [2]usize,

        pub fn alloc(allocator: std.mem.Allocator, size: [2]usize) !@This() {
            const data = try allocator.alloc(T, size[0] * size[1]);
            return @This(){
                .data = data,
                .stride = size[0],
                .size = size,
            };
        }

        pub fn free(this: *@This(), allocator: std.mem.Allocator) void {
            allocator.free(this.data);
        }

        pub fn asConst(this: @This()) ConstGrid(T) {
            return ConstGrid(T){
                .data = this.data,
                .stride = this.stride,
                .size = this.size,
            };
        }

        pub fn copy(dest: @This(), src: ConstGrid(T)) void {
            std.debug.assert(src.size[0] >= dest.size[0]);
            std.debug.assert(src.size[1] >= dest.size[1]);

            var row_index: usize = 0;
            while (row_index < dest.size[1]) : (row_index += 1) {
                const dest_row = dest.data[row_index * dest.stride ..][0..dest.size[0]];
                const src_row = src.data[row_index * src.stride ..][0..src.size[0]];
                std.mem.copy(T, dest_row, src_row);
            }
        }

        pub fn set(this: @This(), value: T) void {
            var row_index: usize = 0;
            while (row_index < this.size[1]) : (row_index += 1) {
                const row = this.data[row_index * this.stride ..][0..this.size[0]];
                std.mem.set(T, row, value);
            }
        }

        pub fn setPos(this: @This(), pos: [2]usize, value: T) void {
            std.debug.assert(pos[0] < this.size[0] and pos[1] < this.size[1]);
            this.data[pos[1] * this.stride + pos[0]] = value;
        }

        pub fn getPosPtr(this: @This(), pos: [2]usize) *T {
            std.debug.assert(pos[0] < this.size[0] and pos[1] < this.size[1]);
            return &this.tiles[pos[1] * this.stride + pos[0]];
        }

        pub fn getPos(this: @This(), pos: [2]usize) T {
            return this.asConst().getPos(pos);
        }

        pub fn getRegion(this: @This(), pos: [2]usize, size: [2]usize) @This() {
            const posv: @Vector(2, usize) = pos;
            const sizev: @Vector(2, usize) = size;

            std.debug.assert(@reduce(.And, posv < this.size));
            std.debug.assert(@reduce(.And, posv + sizev <= this.size));

            const max_pos = posv + sizev - @Vector(2, usize){ 1, 1 };

            const min_index = posv[1] * this.stride + posv[0];
            const max_index = max_pos[1] * this.stride + max_pos[0];

            std.debug.assert(max_index - min_index + 1 >= size[0] * size[1]);

            return @This(){
                .data = this.data[min_index .. max_index + 1],
                .stride = this.stride,
                .size = size,
            };
        }
    };
}

pub fn ConstGrid(comptime T: type) type {
    return struct {
        data: []const T,
        stride: usize,
        size: [2]usize,

        pub fn getPos(this: @This(), pos: [2]usize) T {
            std.debug.assert(pos[0] < this.size[0] and pos[1] < this.size[1]);
            return this.data[pos[1] * this.stride + pos[0]];
        }

        pub fn getRegion(this: @This(), pos: [2]usize, size: [2]usize) @This() {
            const posv: @Vector(2, usize) = pos;
            const sizev: @Vector(2, usize) = size;

            std.debug.assert(@reduce(.And, posv < this.size));
            std.debug.assert(@reduce(.And, posv + sizev <= this.size));

            const max_pos = posv + sizev - .{ 1, 1 };

            const min_index = posv[1] * this.stride + posv[0];
            const max_index = max_pos[1] * this.stride + max_pos[0];

            return @This(){
                .data = this.data[min_index .. max_index + 1],
                .stride = this.stride,
                .size = size,
            };
        }
    };
}
