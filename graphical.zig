const std = @import("std");
const glfw = @import("glfw");
const gl = @import("zgl");
const nanovg = @import("nanovg");
const util = @import("util");
const c = @cImport({
    @cInclude("libavformat/avformat.h");
    @cInclude("libavcodec/avcodec.h");
    @cInclude("libavutil/avutil.h");
    @cInclude("libswscale/swscale.h");
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

    const window = try glfw.Window.create(1024, 1024, "advent of code - graphical solution", null, null, .{ .visible = !recording });
    defer window.destroy();

    try glfw.makeContextCurrent(window);

    try gl.loadExtensions({}, glGetProcAddress);

    var vg = try nanovg.gl.init(gpa.allocator(), .{});
    defer vg.deinit();

    _ = vg.createFontMem("sans", @embedFile("dep/nanovg-zig/examples/Roboto-Regular.ttf"));

    if (recording) {
        return try recordVideo(gpa.allocator(), window, vg, args);
    }

    try solution.graphicsInit(gpa.allocator(), window, vg, recording);
    defer solution.graphicsDeinit(gpa.allocator(), window, vg);
    while (!window.shouldClose()) {
        try solution.graphicsRender(gpa.allocator(), window, vg, recording);
        try window.swapBuffers();

        try glfw.pollEvents();
    }
}

pub fn recordVideo(allocator: std.mem.Allocator, window: glfw.Window, vg: nanovg, args: [][:0]const u8) !void {
    try solution.graphicsInit(allocator, window, vg, true);
    defer solution.graphicsDeinit(allocator, window, vg);

    // Poll events so the framebuffer size is correct
    try glfw.pollEvents();
    const framebuffer_size = try window.getFramebufferSize();

    // Set up ffmpeg to encode video
    const filename = args[1];

    var output_context: ?*c.AVFormatContext = null;
    defer c.avformat_free_context(output_context);
    if (c.avformat_alloc_output_context2(&output_context, null, null, filename.ptr) < 0) {
        return error.CouldNotGuessFormat;
    }

    // Open file for writing
    if (c.avio_open(&output_context.?.pb, filename.ptr, c.AVIO_FLAG_WRITE) < 0) {
        return error.CouldNotOpenFileForWriting;
    }

    var video_stream = c.avformat_new_stream(output_context, null) orelse return error.CouldNotMakeNewStream;
    video_stream.*.time_base = c.av_make_q(1, 30);

    const codec = c.avcodec_find_encoder_by_name("libvpx") orelse return error.CodecNotFound;

    var codec_context = c.avcodec_alloc_context3(codec) orelse return error.CodecContextNotAllocated;
    defer c.avcodec_free_context(&codec_context);

    codec_context.*.bit_rate = 400_000;
    codec_context.*.width = @intCast(c_int, framebuffer_size.width);
    codec_context.*.height = @intCast(c_int, framebuffer_size.height);
    codec_context.*.time_base = video_stream.*.time_base;
    codec_context.*.pix_fmt = c.avcodec_find_best_pix_fmt_of_list(codec.*.pix_fmts, c.AV_PIX_FMT_RGB24, 0, null);

    if (c.avcodec_open2(codec_context, codec, null) < 0) {
        return error.CouldNotOpenCodec;
    }

    if (c.avcodec_parameters_from_context(video_stream.*.codecpar, codec_context) < 0) {
        return error.CopyParameters;
    }

    var sws_context = c.sws_getContext(
        @intCast(c_int, framebuffer_size.width),
        @intCast(c_int, framebuffer_size.height),
        c.AV_PIX_FMT_RGB24,
        @intCast(c_int, framebuffer_size.width),
        @intCast(c_int, framebuffer_size.height),
        codec_context.*.pix_fmt,
        c.SWS_BICUBIC,
        null,
        null,
        null,
    ) orelse return error.CodecContextNotAllocated;
    defer c.sws_freeContext(sws_context);

    var packet = c.av_packet_alloc() orelse return error.CouldNotAllocateAVCodecPacket;
    defer c.av_packet_free(&packet);

    var input_frame = c.av_frame_alloc() orelse return error.CouldNotAllocateAVFrame;
    defer c.av_frame_free(&input_frame);
    input_frame.*.format = c.AV_PIX_FMT_RGB24;
    input_frame.*.width = @intCast(c_int, framebuffer_size.width);
    input_frame.*.height = @intCast(c_int, framebuffer_size.height);

    if (c.av_frame_get_buffer(input_frame, 0) < 0) {
        return error.CouldNotAllocateAVFrameBuffer;
    }

    var output_frame = c.av_frame_alloc() orelse return error.CouldNotAllocateAVFrame;
    defer c.av_frame_free(&output_frame);
    output_frame.*.format = codec_context.*.pix_fmt;
    output_frame.*.width = @intCast(c_int, framebuffer_size.width);
    output_frame.*.height = @intCast(c_int, framebuffer_size.height);

    if (c.av_frame_get_buffer(output_frame, 0) < 0) {
        return error.CouldNotAllocateAVFrameBuffer;
    }

    c.av_dump_format(output_context, 0, filename.ptr, 1);

    if (c.avformat_write_header(output_context, null) < 0) {
        return error.AVWriteHeader;
    }

    var frame_number: i64 = 0;

    while (!window.shouldClose()) : (frame_number += 1) {
        try solution.graphicsRender(allocator, window, vg, true);
        try window.swapBuffers();

        if (c.av_frame_make_writable(input_frame) < 0) {
            return error.FrameNotWritable;
        }

        const elements_per_row = @intCast(usize, input_frame.*.linesize[0]) / 3;
        const input_frame_size = [2]usize{
            @intCast(usize, input_frame.*.width),
            @intCast(usize, input_frame.*.height),
        };
        var input_frame_grid = util.Grid([3]u8){
            .data = @ptrCast([*][3]u8, input_frame.*.data[0])[0 .. elements_per_row * input_frame_size[1]],
            .stride = elements_per_row,
            .size = input_frame_size,
        };

        gl.pixelStore(.pack_alignment, 1);
        gl.pixelStore(.pack_row_length, @intCast(u32, input_frame.*.linesize[0]) / 3);
        gl.readPixels(0, 0, framebuffer_size.width, framebuffer_size.height, .rgb, .unsigned_byte, std.mem.sliceAsBytes(input_frame_grid.data));

        input_frame_grid.flip(.{ false, true });

        if (c.av_frame_make_writable(output_frame) < 0) {
            return error.FrameNotWritable;
        }

        if (c.sws_scale(sws_context, &input_frame.*.data, &input_frame.*.linesize, 0, codec_context.*.height, &output_frame.*.data, &output_frame.*.linesize) < 0) {
            return error.SWScaling;
        }

        output_frame.*.pts = frame_number;
        if (c.avcodec_send_frame(codec_context, output_frame) < 0) {
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

        try glfw.pollEvents();
    }

    try solution.graphicsRender(allocator, window, vg, true);
    try window.swapBuffers();

    if (c.av_frame_make_writable(input_frame) < 0) {
        return error.FrameNotWritable;
    }

    const elements_per_row = @intCast(usize, input_frame.*.linesize[0]) / 3;
    const input_frame_size = [2]usize{
        @intCast(usize, input_frame.*.width),
        @intCast(usize, input_frame.*.height),
    };
    var input_frame_grid = util.Grid([3]u8){
        .data = @ptrCast([*][3]u8, input_frame.*.data[0])[0 .. elements_per_row * input_frame_size[1]],
        .stride = elements_per_row,
        .size = input_frame_size,
    };

    gl.pixelStore(.pack_alignment, 1);
    gl.pixelStore(.pack_row_length, @intCast(u32, input_frame.*.linesize[0]) / 3);
    gl.readPixels(0, 0, framebuffer_size.width, framebuffer_size.height, .rgb, .unsigned_byte, std.mem.sliceAsBytes(input_frame_grid.data));

    input_frame_grid.flip(.{ false, true });

    if (c.av_frame_make_writable(output_frame) < 0) {
        return error.FrameNotWritable;
    }

    if (c.sws_scale(sws_context, &input_frame.*.data, &input_frame.*.linesize, 0, codec_context.*.height, &output_frame.*.data, &output_frame.*.linesize) < 0) {
        return error.SWScaling;
    }

    output_frame.*.pts = frame_number;
    if (c.avcodec_send_frame(codec_context, output_frame) < 0) {
        return error.AVEncodingError;
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
