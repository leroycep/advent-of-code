const std = @import("std");

const DATA = @embedFile("./data/day16.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(arena.allocator(), DATA)});
    try out.print("{}\n", .{try challenge2(arena.allocator(), DATA)});
}

const TestData = struct {
    bytes: []const u8,

    pub fn parse(allocator: std.mem.Allocator, text: []const u8) !TestData {
        const trimmed = std.mem.trim(u8, text, "\n ");

        const bytes = try allocator.alloc(u8, trimmed.len / 2);
        _ = try std.fmt.hexToBytes(bytes, trimmed);

        return @This(){
            .bytes = bytes,
        };
    }

    pub fn deinit(this: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(this.bytes);
        this.* = undefined;
    }
};

pub fn challenge1(allocator: std.mem.Allocator, text: []const u8) !u64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const data = try TestData.parse(arena.allocator(), text);

    std.debug.print("\n\n", .{});
    for (data.bytes) |b, i| {
        std.debug.print("byte[{}] = {b:0>8}\n", .{ i, b });
    }
    std.debug.print("\n\n", .{});

    var fbs = std.io.fixedBufferStream(data.bytes);
    var bits = std.io.bitReader(.Big, fbs.reader());

    var bits_read: usize = 0;
    return try sumPacketVersions(&bits, &bits_read);
}

const Packet = struct {
    const Header = struct {
        version: u3,
        op: Op,
    };

    const Op = enum(u3) {
        sum = 0,
        product = 1,
        minimum = 2,
        maximum = 3,
        literal = 4,
        gt = 5,
        lt = 6,
        eq = 7,
    };
};

fn sumPacketVersions(bits: anytype, bits_read: *usize) !u64 {
    bits_read.* = 0;

    const version = try bits.readBitsNoEof(u3, 3);
    bits_read.* += 3;
    const op = @intToEnum(Packet.Op, try bits.readBitsNoEof(u3, 3));
    bits_read.* += 3;
    std.debug.print("version = {}\n", .{version});
    std.debug.print("op = {}\n", .{op});

    var version_sum: u64 = version;
    switch (op) {
        .literal => {
            std.debug.print("literal = ", .{});
            while (true) {
                const should_continue = try bits.readBitsNoEof(u1, 1);
                bits_read.* += 1;

                const value = try bits.readBitsNoEof(u4, 4);
                bits_read.* += 4;
                std.debug.print("{b:0>3}", .{value});

                if (should_continue == 0) break;
            }
            std.debug.print("\n", .{});
        },
        else => {
            const len_type = try bits.readBitsNoEof(u1, 1);
            bits_read.* += 1;
            if (len_type == 0) {
                const bit_len = try bits.readBitsNoEof(u15, 15);
                bits_read.* += 15;
                std.debug.print("num sub bits = {}\n", .{bit_len});
                var sub_bits_read: usize = 0;
                while (sub_bits_read < bit_len) {
                    std.debug.print("sub bits read = {}\n", .{sub_bits_read});
                    var child_bits_read: usize = 0;
                    version_sum += try sumPacketVersions(bits, &child_bits_read);
                    sub_bits_read += child_bits_read;
                }
                bits_read.* += sub_bits_read;
            } else {
                const num_sub_packets = try bits.readBitsNoEof(u11, 11);
                bits_read.* += 11;
                std.debug.print("num sub packets = {}\n", .{num_sub_packets});

                var i: u11 = 0;
                while (i < num_sub_packets) : (i += 1) {
                    var sub_bits_read: usize = undefined;
                    version_sum += try sumPacketVersions(bits, &sub_bits_read);
                    bits_read.* += sub_bits_read;
                }
            }
        },
    }

    return version_sum;
}

test {
    try std.testing.expectEqual(@as(u64, 16), try challenge1(std.testing.allocator, "8A004A801A8002F478"));
}

test {
    try std.testing.expectEqual(@as(u64, 12), try challenge1(std.testing.allocator, "620080001611562C8802118E34"));
}

test {
    try std.testing.expectEqual(@as(u64, 23), try challenge1(std.testing.allocator, "C0015000016115A2E0802F182340"));
}

test {
    try std.testing.expectEqual(@as(u64, 31), try challenge1(std.testing.allocator, "A0016C880162017C3686B18A3D4780"));
}

pub fn challenge2(allocator: std.mem.Allocator, text: []const u8) !u64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const data = try TestData.parse(arena.allocator(), text);

    std.debug.print("\n\n", .{});
    for (data.bytes) |b, i| {
        std.debug.print("byte[{}] = {b:0>8}\n", .{ i, b });
    }
    std.debug.print("\n\n", .{});

    var fbs = std.io.fixedBufferStream(data.bytes);
    var bits = std.io.bitReader(.Big, fbs.reader());

    var bits_read: usize = 0;
    return try evaluate(&bits, &bits_read);
}

fn evaluate(bits: anytype, bits_read: *usize) !u64 {
    bits_read.* = 0;

    const version = try bits.readBitsNoEof(u3, 3);
    bits_read.* += 3;
    const op = @intToEnum(Packet.Op, try bits.readBitsNoEof(u3, 3));
    bits_read.* += 3;

    _ = version;

    var value: u64 = undefined;
    switch (op) {
        .literal => {
            value = 0;
            while (true) {
                const should_continue = try bits.readBitsNoEof(u1, 1);
                bits_read.* += 1;

                value <<= 4;
                value |= try bits.readBitsNoEof(u4, 4);
                bits_read.* += 4;

                if (should_continue == 0) break;
            }
            std.debug.print("{}", .{value});
        },
        else => |other_op| {
            std.debug.print("({s} ", .{switch (op) {
                .sum => "+",
                .product => "*",
                .maximum => "min",
                .minimum => "max",
                .literal => unreachable,
                .gt => ">",
                .lt => "<",
                .eq => "==",
            }});

            value = switch (other_op) {
                .sum, .maximum => 0,
                .product => 1,
                .minimum => std.math.maxInt(u64),
                .literal => unreachable,
                .gt, .lt, .eq => undefined,
            };

            const len_type = try bits.readBitsNoEof(u1, 1);
            bits_read.* += 1;
            if (len_type == 0) {
                const bit_len = try bits.readBitsNoEof(u15, 15);
                bits_read.* += 15;

                var sub_bits_read: usize = 0;
                while (sub_bits_read < bit_len) {
                    var child_bits_read: usize = 0;

                    if (sub_bits_read > 0) std.debug.print(" ", .{});

                    const child_value = try evaluate(bits, &child_bits_read);
                    const new_value = switch (other_op) {
                        .sum => value + child_value,
                        .product => value * child_value,
                        .maximum => std.math.max(value, child_value),
                        .minimum => std.math.min(value, child_value),
                        .literal => unreachable,
                        .gt => if (sub_bits_read > 0) @boolToInt(value > child_value) else child_value,
                        .lt => if (sub_bits_read > 0) @boolToInt(value < child_value) else child_value,
                        .eq => if (sub_bits_read > 0) @boolToInt(value == child_value) else child_value,
                    };
                    value = new_value;

                    sub_bits_read += child_bits_read;
                }
                bits_read.* += sub_bits_read;
            } else {
                const num_sub_packets = try bits.readBitsNoEof(u11, 11);
                bits_read.* += 11;

                var i: u11 = 0;
                while (i < num_sub_packets) : (i += 1) {
                    var sub_bits_read: usize = undefined;

                    if (i > 0) std.debug.print(" ", .{});

                    const child_value = try evaluate(bits, &sub_bits_read);
                    const new_value = switch (other_op) {
                        .sum => value + child_value,
                        .product => value * child_value,
                        .maximum => std.math.max(value, child_value),
                        .minimum => std.math.min(value, child_value),
                        .literal => unreachable,
                        .gt => if (i > 0) @boolToInt(value > child_value) else child_value,
                        .lt => if (i > 0) @boolToInt(value < child_value) else child_value,
                        .eq => if (i > 0) @boolToInt(value == child_value) else child_value,
                    };
                    value = new_value;

                    bits_read.* += sub_bits_read;
                }
            }
            std.debug.print(")", .{});
        },
    }

    return value;
}

test {
    try std.testing.expectEqual(@as(u64, 3), try challenge2(std.testing.allocator, "C200B40A82"));
}

test {
    try std.testing.expectEqual(@as(u64, 54), try challenge2(std.testing.allocator, "04005AC33890"));
}

test {
    try std.testing.expectEqual(@as(u64, 7), try challenge2(std.testing.allocator, "880086C3E88112"));
}

test {
    try std.testing.expectEqual(@as(u64, 9), try challenge2(std.testing.allocator, "CE00C43D881120"));
}

test {
    try std.testing.expectEqual(@as(u64, 1), try challenge2(std.testing.allocator, "D8005AC2A8F0"));
}

test {
    try std.testing.expectEqual(@as(u64, 0), try challenge2(std.testing.allocator, "F600BC2D8F"));
}

test {
    try std.testing.expectEqual(@as(u64, 1), try challenge2(std.testing.allocator, "9C0141080250320F1802104A08"));
}
