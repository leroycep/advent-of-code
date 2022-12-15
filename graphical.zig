const std = @import("std");
const glfw = @import("glfw");
const gl = @import("zgl");
const nanovg = @import("nanovg");

const solution = @import("solution");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    try glfw.init(.{});
    defer glfw.terminate();

    const window = try glfw.Window.create(640, 480, "2022 day 14", null, null, .{ .resizable = true });
    defer window.destroy();

    try glfw.makeContextCurrent(window);

    try gl.loadExtensions({}, glGetProcAddress);

    var vg = try nanovg.gl.init(gpa.allocator(), .{});
    defer vg.deinit();

    try solution.graphicsMain(gpa.allocator(), window, vg);
}

fn glGetProcAddress(_: void, name: [:0]const u8) ?*const anyopaque {
    return glfw.getProcAddress(name);
}
