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

    _ = vg.createFontMem("sans", @embedFile("dep/nanovg-zig/examples/Roboto-Regular.ttf"));

    try solution.graphicsInit(gpa.allocator(), window, vg);
    defer solution.graphicsDeinit(gpa.allocator(), window, vg);
    while (!window.shouldClose()) {
        try glfw.pollEvents();

        try solution.graphicsRender(gpa.allocator(), window, vg);
        try window.swapBuffers();
    }
}

fn glGetProcAddress(_: void, name: [:0]const u8) ?*const anyopaque {
    return glfw.getProcAddress(name);
}
