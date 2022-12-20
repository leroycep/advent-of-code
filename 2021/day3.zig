const std = @import("std");

const DATA = @embedFile("./data/day3.txt");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(arena.allocator(), DATA)});
    try out.print("{}\n", .{try challenge2(arena.allocator(), DATA)});
}

pub fn challenge1(allocator: std.mem.Allocator, data: []const u8) !i64 {
    const numbers = try parseNumbers(allocator, data);
    defer allocator.free(numbers.numbers);

    const bits = countBits(numbers);

    var gamma: i64 = 0;
    var epsilon: i64 = 0;
    for (bits.zero[0..bits.len]) |ctz, i| {
        gamma <<= 1;
        epsilon <<= 1;
        if (bits.one[i] >= ctz) {
            gamma |= 1;
        } else {
            epsilon |= 1;
        }
    }

    std.log.debug("", .{});
    std.log.debug("ctz {any}", .{bits.zero[0..bits.len]});
    std.log.debug("cto {any}", .{bits.one[0..bits.len]});
    std.log.debug("", .{});
    std.log.debug("gamma   {b: >12} {}", .{ gamma, gamma });
    std.log.debug("epsilon {b: >12} {}", .{ epsilon, epsilon });

    return gamma * epsilon;
}

pub fn challenge2(allocator: std.mem.Allocator, data: []const u8) !u64 {
    const numbers = try parseNumbers(allocator, data);
    defer allocator.free(numbers.numbers);

    const oxygen = try searchForValue(allocator, numbers, .greatest);
    const scrubber = try searchForValue(allocator, numbers, .least);

    std.log.debug("", .{});
    std.log.debug("oxygen   {b: >12} {}", .{ oxygen, oxygen });
    std.log.debug("scrubber {b: >12} {}", .{ scrubber, scrubber });

    return oxygen * scrubber;
}

const Numbers = struct {
    numbers: []u64,
    bits: u6,
};

pub fn parseNumbers(allocator: std.mem.Allocator, data: []const u8) !Numbers {
    var numbers = std.ArrayList(u64).init(allocator);
    defer numbers.deinit();

    var bits: ?u6 = null;
    var line_iter = std.mem.tokenize(u8, data, "\n\r");
    while (line_iter.next()) |line| {
        if (bits) |b| {
            std.debug.assert(@as(u64, b) == line.len);
        }
        bits = @intCast(u6, line.len);
        try numbers.append(try std.fmt.parseUnsigned(u64, line, 2));
    }

    return Numbers{
        .numbers = try numbers.toOwnedSlice(),
        .bits = bits.?,
    };
}

const BitCounts = struct {
    zero: [N]u64 = [_]u64{0} ** N,
    one: [N]u64 = [_]u64{0} ** N,
    len: u6,

    const N = std.meta.bitCount(u64);
};

pub fn countBits(numbers: Numbers) BitCounts {
    const N = std.meta.bitCount(u64);
    var num_of_zeroes = [_]u64{0} ** N;
    var num_of_ones = [_]u64{0} ** N;

    for (numbers.numbers) |number| {
        var i: u6 = 0;
        while (i < numbers.bits) : (i += 1) {
            switch (@truncate(u1, number >> (numbers.bits - i - 1))) {
                0 => num_of_zeroes[i] += 1,
                1 => num_of_ones[i] += 1,
            }
        }
    }

    return BitCounts{
        .zero = num_of_zeroes,
        .one = num_of_ones,
        .len = numbers.bits,
    };
}

const Value = enum {
    least,
    greatest,
};

pub fn searchForValue(allocator: std.mem.Allocator, numbers: Numbers, value: Value) !u64 {
    var remaining = std.ArrayList(u64).init(allocator);
    defer remaining.deinit();
    try remaining.appendSlice(numbers.numbers);

    var i: usize = 0;
    while (remaining.items.len > 1 and i < numbers.bits) : (i += 1) {
        const bitCounts = countBits(.{ .numbers = remaining.items, .bits = numbers.bits });
        std.log.debug("ones = {any}", .{bitCounts.one[0..numbers.bits]});
        std.log.debug("zeros = {any}", .{bitCounts.zero[0..numbers.bits]});
        std.log.debug("ones = {}, zeroes = {}", .{ bitCounts.one[i], bitCounts.zero[i] });

        const remove_zeroes_if_greatest = bitCounts.one[i] >= bitCounts.zero[i];
        const remove_zeroes = if (value == .greatest) remove_zeroes_if_greatest else !remove_zeroes_if_greatest;
        std.log.debug("remove {}", .{@boolToInt(!remove_zeroes)});

        const filter = @as(u64, 1) << @intCast(u6, numbers.bits - i - 1);
        std.log.debug("filter {b:0>5}", .{@intCast(u64, filter)});

        var iter = remaining.items.len;
        while (iter > 0) : (iter -= 1) {
            const idx = iter - 1;
            const num = remaining.items[idx];
            if ((remove_zeroes and num & filter == 0) or
                (!remove_zeroes and (~num) & filter == 0))
            {
                _ = remaining.swapRemove(idx);
            }
        }

        std.log.debug("numbers:", .{});
        for (remaining.items) |num| {
            std.log.debug("\t{: >4} {b:0>5}", .{ num, num });
        }
    }
    std.debug.assert(remaining.items.len == 1);

    return remaining.items[0];
}

test "challenge1" {
    try std.testing.expectEqual(@as(i64, 198), try challenge1(std.testing.allocator,
        \\00100
        \\11110
        \\10110
        \\10111
        \\10101
        \\01111
        \\00111
        \\11100
        \\10000
        \\11001
        \\00010
        \\01010
    ));
}

test "challenge2 oxygen generator rating" {
    const test_data =
        \\00100
        \\11110
        \\10110
        \\10111
        \\10101
        \\01111
        \\00111
        \\11100
        \\10000
        \\11001
        \\00010
        \\01010
    ;
    const numbers = try parseNumbers(std.testing.allocator, test_data);
    defer std.testing.allocator.free(numbers.numbers);
    try std.testing.expectEqual(@as(u64, 23), try searchForValue(std.testing.allocator, numbers, .greatest));
    try std.testing.expectEqual(@as(u64, 10), try searchForValue(std.testing.allocator, numbers, .least));

    try std.testing.expectEqual(@as(u64, 230), try challenge2(std.testing.allocator, test_data));
}
