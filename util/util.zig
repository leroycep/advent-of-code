const std = @import("std");

pub const glfw = @import("glfw");
pub const gl = @import("zgl");
pub const nanovg = @import("nanovg");
pub const ArrayDeque = @import("./array_deque.zig").ArrayDeque;

const c = @cImport({
    @cInclude("libavformat/avformat.h");
    @cInclude("libavcodec/avcodec.h");
    @cInclude("libavutil/avutil.h");
    @cInclude("libswscale/swscale.h");
});

pub const Grid = @import("./grid.zig").Grid;
pub const ConstGrid = @import("./grid.zig").ConstGrid;

pub var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub const Context = struct {
    allocator: std.mem.Allocator,
    args: [][:0]u8,
    window: glfw.Window,
    vg: nanovg,

    frame: i64 = 0,

    // For recording
    recording: bool,
    output_context: ?*c.AVFormatContext = null,
    video_stream: ?*c.AVStream = null,
    codec_context: ?*c.AVCodecContext = null,
    sws_context: ?*c.SwsContext = null,
    packet: ?*c.AVPacket = null,
    input_frame: ?*c.AVFrame = null,
    output_frame: ?*c.AVFrame = null,

    const InitOptions = struct {
        title: [:0]const u8 = "advent of code - graphical solution",
        allocator: std.mem.Allocator = gpa.allocator(),
    };

    pub fn init(options: InitOptions) !*@This() {
        glfw.setErrorCallback(errorCallbackForGLFW);
        _ = glfw.init(.{});

        const args = try std.process.argsAlloc(options.allocator);

        const recording = args.len == 2;

        const window = glfw.Window.create(1024, 1024, options.title.ptr, null, null, .{ .visible = !recording }) orelse return error.FailedToCreateWindow;
        errdefer window.destroy();

        glfw.makeContextCurrent(window);

        try gl.loadExtensions({}, glGetProcAddress);

        var vg = try nanovg.gl.init(options.allocator, .{});
        _ = vg.createFontMem("sans", @embedFile("./Roboto-Regular.ttf"));

        const this = try options.allocator.create(@This());
        this.* = .{
            .allocator = options.allocator,
            .window = window,
            .vg = vg,
            .args = args,
            .recording = recording,
        };
        return this;
    }

    pub fn deinit(this: *@This()) void {
        std.process.argsFree(this.allocator, this.args);
        this.vg.deinit();
        glfw.terminate();

        if (this.output_context) |output_context| {
            c.avformat_free_context(output_context);
            c.avcodec_free_context(&this.codec_context);
            c.sws_freeContext(this.sws_context);
            c.av_packet_free(&this.packet);
            c.av_frame_free(&this.input_frame);
            c.av_frame_free(&this.output_frame);
        }

        this.allocator.destroy(this);
        _ = gpa.deinit();
    }

    pub fn flush(this: *@This()) !void {
        if (this.output_context != null) {
            try this.endFrame();
            if (c.avcodec_send_frame(this.codec_context, null) < 0) {
                return error.AVEncodingError;
            }

            // Flush the video
            while (true) {
                const ret = c.avcodec_receive_packet(this.codec_context, this.packet);
                if (ret == c.AVERROR(c.EAGAIN)) {
                    continue;
                } else if (ret == c.AVERROR_EOF) {
                    break;
                } else if (ret < 0) {
                    return error.AVEncodingError;
                }
                c.av_packet_rescale_ts(this.packet, this.codec_context.?.*.time_base, this.video_stream.?.*.time_base);
                this.packet.?.*.stream_index = this.video_stream.?.*.index;
                if (c.av_interleaved_write_frame(this.output_context, this.packet) < 0) {
                    return error.CouldNotWriteVideoPacket;
                }
            }

            if (c.av_write_trailer(this.output_context) < 0) {
                return error.CouldNotWriteToFile;
            }

            if (c.avio_closep(&this.output_context.?.pb) < 0) {
                return error.CouldNotCloseFile;
            }
        }
    }

    pub fn beginFrame(this: *@This()) !void {
        const window_size = this.window.getSize();
        const framebuffer_size = this.window.getFramebufferSize();
        const content_scale = this.window.getContentScale();
        const pixel_ratio = @max(content_scale.x_scale, content_scale.y_scale);

        gl.viewport(0, 0, framebuffer_size.width, framebuffer_size.height);
        gl.clearColor(0, 0, 0, 1);
        gl.clear(.{ .color = true, .depth = true, .stencil = true });

        this.vg.beginFrame(@intToFloat(f32, window_size.width), @intToFloat(f32, window_size.height), pixel_ratio);
    }

    pub fn endFrame(this: *@This()) !void {
        defer this.frame += 1;

        this.vg.endFrame();

        glfw.pollEvents();
        this.window.swapBuffers();

        if (this.recording) {
            if (this.output_context == null) {
                try this.setupVideoRecording();
            }

            const framebuffer_size = this.window.getFramebufferSize();

            if (c.av_frame_make_writable(this.input_frame) < 0) {
                return error.FrameNotWritable;
            }

            const elements_per_row = @intCast(usize, this.input_frame.?.*.linesize[0]) / 3;
            const input_frame_size = [2]usize{
                @intCast(usize, this.input_frame.?.*.width),
                @intCast(usize, this.input_frame.?.*.height),
            };
            var input_frame_grid = Grid([3]u8){
                .data = @ptrCast([*][3]u8, this.input_frame.?.*.data[0])[0 .. elements_per_row * input_frame_size[1]],
                .stride = elements_per_row,
                .size = input_frame_size,
            };

            gl.pixelStore(.pack_alignment, 1);
            gl.pixelStore(.pack_row_length, @intCast(u32, this.input_frame.?.*.linesize[0]) / 3);
            gl.readPixels(0, 0, framebuffer_size.width, framebuffer_size.height, .rgb, .unsigned_byte, std.mem.sliceAsBytes(input_frame_grid.data));

            input_frame_grid.flip(.{ false, true });

            if (c.av_frame_make_writable(this.output_frame) < 0) {
                return error.FrameNotWritable;
            }

            if (c.sws_scale(this.sws_context, &this.input_frame.?.*.data, &this.input_frame.?.*.linesize, 0, this.codec_context.?.*.height, &this.output_frame.?.*.data, &this.output_frame.?.*.linesize) < 0) {
                return error.SWScaling;
            }

            this.output_frame.?.*.pts = this.frame;
            if (c.avcodec_send_frame(this.codec_context, this.output_frame) < 0) {
                return error.AVEncodingError;
            }

            while (true) {
                const ret = c.avcodec_receive_packet(this.codec_context, this.packet);
                if (ret == c.AVERROR(c.EAGAIN) or ret == c.AVERROR_EOF) {
                    break;
                } else if (ret < 0) {
                    return error.AVEncodingError;
                }
                c.av_packet_rescale_ts(this.packet, this.codec_context.?.*.time_base, this.video_stream.?.*.time_base);
                this.packet.?.*.stream_index = this.video_stream.?.*.index;
                if (c.av_interleaved_write_frame(this.output_context, this.packet) < 0) {
                    return error.CouldNotWriteVideoPacket;
                }
            }
        }
    }

    fn setupVideoRecording(this: *@This()) !void {
        const framebuffer_size = this.window.getFramebufferSize();
        const filename = this.args[1];

        if (c.avformat_alloc_output_context2(&this.output_context, null, null, filename.ptr) < 0) {
            return error.CouldNotGuessFormat;
        }

        // Open file for writing
        if (c.avio_open(&this.output_context.?.pb, filename.ptr, c.AVIO_FLAG_WRITE) < 0) {
            return error.CouldNotOpenFileForWriting;
        }

        this.video_stream = c.avformat_new_stream(this.output_context, null) orelse return error.CouldNotMakeNewStream;
        this.video_stream.?.*.time_base = c.av_make_q(1, 30);

        const codec = c.avcodec_find_encoder(c.AV_CODEC_ID_VP9) orelse return error.CodecNotFound;

        this.codec_context = c.avcodec_alloc_context3(codec) orelse return error.CodecContextNotAllocated;

        this.codec_context.?.*.bit_rate = 400_000;
        this.codec_context.?.*.width = @intCast(c_int, framebuffer_size.width);
        this.codec_context.?.*.height = @intCast(c_int, framebuffer_size.height);
        this.codec_context.?.*.time_base = this.video_stream.?.*.time_base;
        this.codec_context.?.*.pix_fmt = c.avcodec_find_best_pix_fmt_of_list(codec.*.pix_fmts, c.AV_PIX_FMT_RGB24, 0, null);

        var opt: ?*c.AVDictionary = null;
        defer c.av_dict_free(&opt);
        _ = c.av_dict_set_int(&opt, "lossless", 1, 0);

        if (c.avcodec_open2(this.codec_context, codec, &opt) < 0) {
            return error.CouldNotOpenCodec;
        }

        if (c.avcodec_parameters_from_context(this.video_stream.?.*.codecpar, this.codec_context) < 0) {
            return error.CopyParameters;
        }

        this.sws_context = c.sws_getContext(
            @intCast(c_int, framebuffer_size.width),
            @intCast(c_int, framebuffer_size.height),
            c.AV_PIX_FMT_RGB24,
            @intCast(c_int, framebuffer_size.width),
            @intCast(c_int, framebuffer_size.height),
            this.codec_context.?.*.pix_fmt,
            c.SWS_BICUBIC,
            null,
            null,
            null,
        ) orelse return error.CodecContextNotAllocated;

        this.packet = c.av_packet_alloc() orelse return error.CouldNotAllocateAVCodecPacket;

        this.input_frame = c.av_frame_alloc() orelse return error.CouldNotAllocateAVFrame;
        this.input_frame.?.*.format = c.AV_PIX_FMT_RGB24;
        this.input_frame.?.*.width = @intCast(c_int, framebuffer_size.width);
        this.input_frame.?.*.height = @intCast(c_int, framebuffer_size.height);

        if (c.av_frame_get_buffer(this.input_frame, 0) < 0) {
            return error.CouldNotAllocateAVFrameBuffer;
        }

        this.output_frame = c.av_frame_alloc() orelse return error.CouldNotAllocateAVFrame;
        this.output_frame.?.*.format = this.codec_context.?.*.pix_fmt;
        this.output_frame.?.*.width = @intCast(c_int, framebuffer_size.width);
        this.output_frame.?.*.height = @intCast(c_int, framebuffer_size.height);

        if (c.av_frame_get_buffer(this.output_frame, 0) < 0) {
            return error.CouldNotAllocateAVFrameBuffer;
        }

        c.av_dump_format(this.output_context, 0, filename.ptr, 1);

        if (c.avformat_write_header(this.output_context, null) < 0) {
            return error.AVWriteHeader;
        }
    }
};

fn glGetProcAddress(_: void, name: [:0]const u8) ?*const anyopaque {
    return glfw.getProcAddress(name);
}

fn errorCallbackForGLFW(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.scoped(.glfw).err("{}: {s}", .{ error_code, description });
}
