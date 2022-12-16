const std = @import("std");
const glfw = @import("glfw");
const gl = @import("zgl");
const nanovg = @import("nanovg");
const c = @cImport({
    @cInclude("libavcodec/avcodec.h");
    @cInclude("libavutil/avutil.h");
});

const solution = @import("solution");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    try glfw.init(.{});
    defer glfw.terminate();

    const screen_size = [2]u32{ 640, 480 };
    const recording = true;

    const window = try glfw.Window.create(screen_size[0], screen_size[1], "2022 day 14", null, null, .{ .resizable = !recording });
    defer window.destroy();

    try glfw.makeContextCurrent(window);

    try gl.loadExtensions({}, glGetProcAddress);

    var vg = try nanovg.gl.init(gpa.allocator(), .{});
    defer vg.deinit();

    _ = vg.createFontMem("sans", @embedFile("dep/nanovg-zig/examples/Roboto-Regular.ttf"));

    // Set up ffmpeg to encode video
    const codec = c.avcodec_find_encoder_by_name("libx264rgb") orelse return error.CodecNotFound;

    var avcodec_context = c.avcodec_alloc_context3(codec) orelse return error.CodecContextNotAllocated;
    defer c.avcodec_free_context(&avcodec_context);

    avcodec_context.*.width = screen_size[0];
    avcodec_context.*.height = screen_size[1];
    avcodec_context.*.time_base = c.av_make_q(1, 25);
    avcodec_context.*.pix_fmt = c.AV_PIX_FMT_RGB24;

    if (c.avcodec_open2(avcodec_context, codec, null) < 0) {
        return error.CouldNotOpenCodec;
    }

    var packet = c.av_packet_alloc() orelse return error.CouldNotAllocateAVCodecPacket;
    defer c.av_packet_free(&packet);

    var frame = c.av_frame_alloc() orelse return error.CouldNotAllocateAVFrame;
    defer c.av_frame_free(&frame);
    frame.*.format = c.AV_PIX_FMT_RGBA;
    frame.*.width = screen_size[0];
    frame.*.height = screen_size[1];

    if (c.av_frame_get_buffer(frame, 0) < 0) {
        return error.CouldNotAllocateAVFrameBuffer;
    }

    var frame_number: i64 = 0;

    const file = try std.fs.cwd().createFile("recording.mp4", .{});
    defer file.close();

    try solution.graphicsInit(gpa.allocator(), window, vg, recording);
    defer solution.graphicsDeinit(gpa.allocator(), window, vg);
    while (!window.shouldClose()) : (frame_number += 1) {
        try glfw.pollEvents();

        try solution.graphicsRender(gpa.allocator(), window, vg, recording);
        try window.swapBuffers();

        if (c.av_frame_make_writable(frame) < 0) {
            return error.FrameNotWritable;
        }
        frame.*.pts = frame_number;

        std.debug.print("linesize[0] = {}\n", .{frame.*.linesize[0]});
        gl.readPixels(0, 0, screen_size[0], screen_size[1], .rgba, .unsigned_byte, frame.*.data[0][0 .. 4 * screen_size[0] * screen_size[1]]);
        std.debug.print("linesize[0] = {}\n", .{frame.*.linesize[0]});

        if (c.avcodec_send_frame(avcodec_context, frame) < 0) {
            return error.AVEncodingError;
        }

        while (true) {
            const ret = c.avcodec_receive_packet(avcodec_context, packet);
            if (ret == c.AVERROR(c.EAGAIN) or ret == c.AVERROR_EOF) {
                break;
            } else if (ret < 0) {
                return error.AVEncodingError;
            }
            try file.writeAll(packet.*.data[0..@intCast(usize, packet.*.size)]);
            c.av_packet_unref(packet);
        }
    }

    // Flush the video
    while (true) {
        const ret = c.avcodec_receive_packet(avcodec_context, packet);
        if (ret == c.AVERROR(c.EAGAIN) or ret == c.AVERROR_EOF) {
            break;
        } else if (ret < 0) {
            return error.AVEncodingError;
        }
        try file.writeAll(packet.*.data[0..@intCast(usize, packet.*.size)]);
        c.av_packet_unref(packet);
    }
}

fn glGetProcAddress(_: void, name: [:0]const u8) ?*const anyopaque {
    return glfw.getProcAddress(name);
}
