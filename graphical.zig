const std = @import("std");
const glfw = @import("glfw");
const gl = @import("zgl");
const nanovg = @import("nanovg");
const c = @cImport({
    @cInclude("libavformat/avformat.h");
    @cInclude("libavcodec/avcodec.h");
    @cInclude("libavutil/avutil.h");
});

const solution = @import("solution");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    try glfw.init(.{});
    defer glfw.terminate();

    const args = try std.process.argsAlloc(gpa.allocator());
    defer std.process.argsFree(gpa.allocator(), args);

    const recording = args.len == 2;

    const window = try glfw.Window.create(640 * 2, 480 * 2, "advent of code - graphical solution", null, null, .{ .visible = !recording });
    defer window.destroy();

    try glfw.makeContextCurrent(window);

    try gl.loadExtensions({}, glGetProcAddress);

    var vg = try nanovg.gl.init(gpa.allocator(), .{});
    defer vg.deinit();

    _ = vg.createFontMem("sans", @embedFile("dep/nanovg-zig/examples/Roboto-Regular.ttf"));

    if (recording) {
        return try recordVideo(gpa.allocator(), window, vg);
    }

    try solution.graphicsInit(gpa.allocator(), window, vg, recording);
    defer solution.graphicsDeinit(gpa.allocator(), window, vg);
    while (!window.shouldClose()) {
        try glfw.pollEvents();

        try solution.graphicsRender(gpa.allocator(), window, vg, recording);
        try window.swapBuffers();
    }
}

pub fn recordVideo(allocator: std.mem.Allocator, window: glfw.Window, vg: nanovg) !void {
    // Poll events so the framebuffer size is correct
    try glfw.pollEvents();
    const framebuffer_size = try window.getFramebufferSize();

    // Set up ffmpeg to encode video
    const filename = "recording.mp4";

    var output_context: ?*c.AVFormatContext = null;
    defer c.avformat_free_context(output_context);
    if (c.avformat_alloc_output_context2(&output_context, null, null, filename) < 0) {
        return error.CouldNotGuessFormat;
    }

    // Open file for writing
    if (c.avio_open(&output_context.?.pb, filename, c.AVIO_FLAG_WRITE) < 0) {
        return error.CouldNotOpenFileForWriting;
    }

    var video_stream = c.avformat_new_stream(output_context, null) orelse return error.CouldNotMakeNewStream;
    video_stream.*.time_base = c.av_make_q(1, 30);

    const codec = c.avcodec_find_encoder_by_name("libx264rgb") orelse return error.CodecNotFound;

    var codec_context = c.avcodec_alloc_context3(codec) orelse return error.CodecContextNotAllocated;
    defer c.avcodec_free_context(&codec_context);

    codec_context.*.bit_rate = 400_000;
    codec_context.*.width = @intCast(c_int, framebuffer_size.width);
    codec_context.*.height = @intCast(c_int, framebuffer_size.height);
    codec_context.*.time_base = video_stream.*.time_base;
    codec_context.*.pix_fmt = c.AV_PIX_FMT_RGB24;

    if (c.avcodec_open2(codec_context, codec, null) < 0) {
        return error.CouldNotOpenCodec;
    }

    if (c.avcodec_parameters_from_context(video_stream.*.codecpar, codec_context) < 0) {
        return error.CopyParameters;
    }

    var packet = c.av_packet_alloc() orelse return error.CouldNotAllocateAVCodecPacket;
    defer c.av_packet_free(&packet);

    var frame = c.av_frame_alloc() orelse return error.CouldNotAllocateAVFrame;
    defer c.av_frame_free(&frame);
    frame.*.format = c.AV_PIX_FMT_RGB24;
    frame.*.width = @intCast(c_int, framebuffer_size.width);
    frame.*.height = @intCast(c_int, framebuffer_size.height);

    if (c.av_frame_get_buffer(frame, 0) < 0) {
        return error.CouldNotAllocateAVFrameBuffer;
    }

    c.av_dump_format(output_context, 0, filename, 1);

    if (c.avformat_write_header(output_context, null) < 0) {
        return error.AVWriteHeader;
    }

    var frame_number: i64 = 0;

    try solution.graphicsInit(allocator, window, vg, true);
    defer solution.graphicsDeinit(allocator, window, vg);
    while (!window.shouldClose()) : (frame_number += 1) {
        try glfw.pollEvents();

        if (c.av_frame_make_writable(frame) < 0) {
            return error.FrameNotWritable;
        }

        try solution.graphicsRender(allocator, window, vg, true);
        try window.swapBuffers();

        gl.pixelStore(.pack_alignment, 1);
        gl.readPixels(0, 0, framebuffer_size.width, framebuffer_size.height, .rgb, .unsigned_byte, frame.*.data[0][0 .. @intCast(u32, frame.*.linesize[0]) * framebuffer_size.height]);

        frame.*.pts = frame_number;
        if (c.avcodec_send_frame(codec_context, frame) < 0) {
            return error.AVEncodingError;
        }

        while (true) {
            const ret = c.avcodec_receive_packet(codec_context, packet);
            if (ret == c.AVERROR(c.EAGAIN) or ret == c.AVERROR_EOF) {
                break;
            } else if (ret < 0) {
                return error.AVEncodingError;
            }
            c.av_packet_rescale_ts(packet, codec_context.*.time_base, video_stream.*.time_base);
            packet.*.stream_index = video_stream.*.index;
            if (c.av_interleaved_write_frame(output_context, packet) < 0) {
                return error.CouldNotWriteVideoPacket;
            }
        }
    }

    if (c.avcodec_send_frame(codec_context, null) < 0) {
        return error.AVEncodingError;
    }

    // Flush the video
    while (true) {
        const ret = c.avcodec_receive_packet(codec_context, packet);
        if (ret == c.AVERROR(c.EAGAIN)) {
            continue;
        } else if (ret == c.AVERROR_EOF) {
            break;
        } else if (ret < 0) {
            return error.AVEncodingError;
        }
        c.av_packet_rescale_ts(packet, codec_context.*.time_base, video_stream.*.time_base);
        packet.*.stream_index = video_stream.*.index;
        if (c.av_interleaved_write_frame(output_context, packet) < 0) {
            return error.CouldNotWriteVideoPacket;
        }
    }

    if (c.av_write_trailer(output_context) < 0) {
        return error.CouldNotWriteToFile;
    }

    if (c.avio_closep(&output_context.?.pb) < 0) {
        return error.CouldNotCloseFile;
    }
}

fn glGetProcAddress(_: void, name: [:0]const u8) ?*const anyopaque {
    return glfw.getProcAddress(name);
}
