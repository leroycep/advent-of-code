const std = @import("std");

const DATA = @embedFile("./data/day8.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(DATA)});
    try out.print("{}\n", .{try challenge2(arena.allocator(), DATA)});
}

const Segments = [7]u1;
const digits_segment_count = .{ 6, 2, 5, 5, 4, 5, 6, 3, 7, 6 };
const canonical_digit_representation = .{
    0b1110111, // 0
    0b0010010, // 1
    0b1011101, // 2
    0b1011011, // 3
    0b0111010, // 4
    0b1101011, // 5
    0b1101111, // 6
    0b1010010, // 7
    0b1111111, // 8
    0b1111011, // 9
};
const segment = struct {
    const a = 0b1000000;
    const b = 0b0100000;
    const c = 0b0010000;
    const d = 0b0001000;
    const e = 0b0000100;
    const f = 0b0000010;
    const g = 0b0000001;
};

pub fn challenge1(data: []const u8) !u64 {
    var num_unique_output_values: u64 = 0;

    var line_iter = std.mem.tokenize(u8, data, "\n");
    while (line_iter.next()) |line| {
        var unique_pattern_display_iter = std.mem.tokenize(u8, line, "|");
        const unique_patterns = unique_pattern_display_iter.next().?;
        _ = unique_patterns;

        const displayed = unique_pattern_display_iter.next().?;
        var displayed_iter = std.mem.tokenize(u8, displayed, " ");
        while (displayed_iter.next()) |digit| {
            switch (digit.len) {
                2, 4, 3, 7 => num_unique_output_values += 1,
                6, 5 => {},
                else => unreachable,
            }
        }
    }

    return num_unique_output_values;
}

test challenge1 {
    try std.testing.expectEqual(@as(u64, 26), try challenge1(
        \\be cfbegad cbdgef fgaecd cgeb fdcge agebfd fecdb fabcd edb | fdgacbe cefdb cefbgd gcbe
        \\edbfga begcd cbg gc gcadebf fbgde acbgfd abcde gfcbed gfec | fcgedb cgb dgebacf gc
        \\fgaebd cg bdaec gdafb agbcfd gdcbef bgcad gfac gcb cdgabef | cg cg fdcagb cbg
        \\fbegcd cbd adcefb dageb afcb bc aefdc ecdab fgdeca fcdbega | efabcd cedba gadfec cb
        \\aecbfdg fbg gf bafeg dbefa fcge gcbea fcaegb dgceab fcbdga | gecf egdcabf bgf bfgea
        \\fgeab ca afcebg bdacfeg cfaedg gcfdb baec bfadeg bafgc acf | gebdcfa ecba ca fadegcb
        \\dbcfg fgd bdegcaf fgec aegbdf ecdfab fbedc dacgb gdcebf gf | cefg dcbef fcge gbcadfe
        \\bdfegc cbegaf gecbf dfcage bdacg ed bedf ced adcbefg gebcd | ed bcgafe cdgba cbgef
        \\egadfb cdbfeg cegd fecab cgb gbdefca cg fgcdab egfdb bfceg | gbdfcae bgc cg cgb
        \\gcafb gcf dcaebfg ecagb gf abcdeg gaef cafbge fdbac fegbdc | fgae cfgab fg bagce
    ));
}

pub fn challenge2(allocator: std.mem.Allocator, data: []const u8) !u64 {
    var total: u64 = 0;

    var digits = std.ArrayList(u7).init(allocator);
    defer digits.deinit();

    var line_iter = std.mem.tokenize(u8, data, "\n");
    while (line_iter.next()) |line| {
        digits.shrinkRetainingCapacity(0);

        var unique_pattern_display_iter = std.mem.tokenize(u8, line, "|");

        const unique_patterns = unique_pattern_display_iter.next().?;
        var unique_pattern_iter = std.mem.tokenize(u8, unique_patterns, " ");
        while (unique_pattern_iter.next()) |unique_pattern| {
            try digits.append(stringToSegmentBits(unique_pattern));
        }

        // Use the set of unique patterns to get the transform
        const transform = getTransformFromDigitSet(digits.items[0..10].*);

        var display_number: u64 = 0;

        const displayed = unique_pattern_display_iter.next().?;
        var displayed_iter = std.mem.tokenize(u8, displayed, " ");
        while (displayed_iter.next()) |displayed_pattern| {
            display_number *= 10;

            const garbled_segment_bits = stringToSegmentBits(displayed_pattern);
            const transformed_segment_bits = applyTransform(garbled_segment_bits, transform);
            switch (transformed_segment_bits) {
                canonical_digit_representation[0] => display_number += 0,
                canonical_digit_representation[1] => display_number += 1,
                canonical_digit_representation[2] => display_number += 2,
                canonical_digit_representation[3] => display_number += 3,
                canonical_digit_representation[4] => display_number += 4,
                canonical_digit_representation[5] => display_number += 5,
                canonical_digit_representation[6] => display_number += 6,
                canonical_digit_representation[7] => display_number += 7,
                canonical_digit_representation[8] => display_number += 8,
                canonical_digit_representation[9] => display_number += 9,
                else => std.debug.panic("Unkown digit: {b:0>7}", .{transformed_segment_bits}),
            }
        }

        total += display_number;
    }

    return total;
}

fn stringToSegmentBits(str: []const u8) u7 {
    var digit: u7 = 0;
    for (str) |c| {
        const index = @intCast(u3, c - 'a');
        digit |= @as(u7, 1) << (6 - index);
    }
    return digit;
}

fn applyTransform(segment_bits: u7, transform: [7]u7) u7 {
    var output: u7 = 0;
    for (transform) |bit_to_set, mask_index| {
        const mask = @as(u7, 1) << @intCast(u3, 6 - mask_index);
        if (segment_bits & mask == mask) {
            output |= bit_to_set;
        }
    }
    return output;
}

test applyTransform {
    try std.testing.expectEqual(
        @as(u7, canonical_digit_representation[1]),
        applyTransform(
            segment.a | segment.b,
            [7]u7{
                0b0010000,
                0b0000010,
                0b0000001,
                0b1000000,
                0b0100000,
                0b0001000,
                0b0000100,
            },
        ),
    );
}

// test challenge2 {
//     try std.testing.expectEqual(@as(u64, 61229), try challenge2(std.testing.allocator,
//         \\be cfbegad cbdgef fgaecd cgeb fdcge agebfd fecdb fabcd edb | fdgacbe cefdb cefbgd gcbe
//         \\edbfga begcd cbg gc gcadebf fbgde acbgfd abcde gfcbed gfec | fcgedb cgb dgebacf gc
//         \\fgaebd cg bdaec gdafb agbcfd gdcbef bgcad gfac gcb cdgabef | cg cg fdcagb cbg
//         \\fbegcd cbd adcefb dageb afcb bc aefdc ecdab fgdeca fcdbega | efabcd cedba gadfec cb
//         \\aecbfdg fbg gf bafeg dbefa fcge gcbea fcaegb dgceab fcbdga | gecf egdcabf bgf bfgea
//         \\fgeab ca afcebg bdacfeg cfaedg gcfdb baec bfadeg bafgc acf | gebdcfa ecba ca fadegcb
//         \\dbcfg fgd bdegcaf fgec aegbdf ecdfab fbedc dacgb gdcebf gf | cefg dcbef fcge gbcadfe
//         \\bdfegc cbegaf gecbf dfcage bdacg ed bedf ced adcbefg gebcd | ed bcgafe cdgba cbgef
//         \\egadfb cdbfeg cegd fecab cgb gbdefca cg fgcdab egfdb bfceg | gbdfcae bgc cg cgb
//         \\gcafb gcf dcaebfg ecagb gf abcdeg gaef cafbge fdbac fegbdc | fgae cfgab fg bagce
//     ));
// }

test {
    try std.testing.expectEqual(@as(u64, 5353), try challenge2(std.testing.allocator,
        \\acedgfb cdfbe gcdfa fbcad dab cefabd cdfgeb eafb cagedb ab | cdfeb fcadb cdfeb cdbaf
    ));
}

fn getTransformFromDigitSet(digits: [10]u7) [7]u7 {
    var map: [7]u7 = [_]u7{0b111_1111} ** 7;
    var segment_frequencies: [7]u32 = [_]u32{0} ** 7;
    for (digits) |digit| {
        const num_bits = @popCount(digit);
        switch (num_bits) {
            // The digit 1 is the only digit with only 2 bits set
            2 => mapWhittle(&map, digit, canonical_digit_representation[1]),

            // same as above, but for 7
            3 => mapWhittle(&map, digit, canonical_digit_representation[7]),

            // same as above, but for 4
            4 => mapWhittle(&map, digit, canonical_digit_representation[4]),

            // same as above, but for 8. Since 8 sets all the bits, it gives us no info.
            7 => {},

            6, 5 => {
                // Multiple digits have this number of segments, doesn't tell us much
            },
            else => {},
        }

        for (integer_to_array(digit)) |bit, bit_index| {
            segment_frequencies[bit_index] += bit;
        }
    }

    // Identify digits using amount of times a bit appears; frequency analysis essentially
    for (segment_frequencies) |frequency, bit_index| {
        switch (frequency) {
            4 => mapWhittle(&map, @as(u7, 1) << @intCast(u3, 6 - bit_index), segment.e),
            6 => mapWhittle(&map, @as(u7, 1) << @intCast(u3, 6 - bit_index), segment.b),
            9 => mapWhittle(&map, @as(u7, 1) << @intCast(u3, 6 - bit_index), segment.f),

            8, 7 => {},
            else => std.debug.panic("Unexpected frequency: {}", .{frequency}),
        }
    }

    return map;
}

test getTransformFromDigitSet {
    try std.testing.expectEqual([7]u7{
        0b0010000,
        0b0000010,
        0b0000001,
        0b1000000,
        0b0100000,
        0b0001000,
        0b0000100,
    }, getTransformFromDigitSet(.{
        segment.a | segment.b | segment.c | segment.d | segment.e | segment.f | segment.g,
        segment.c | segment.d | segment.f | segment.b | segment.e,
        segment.g | segment.c | segment.d | segment.f | segment.a,
        segment.f | segment.b | segment.c | segment.a | segment.d,
        segment.d | segment.a | segment.b,
        segment.c | segment.e | segment.f | segment.a | segment.b | segment.d,
        segment.c | segment.d | segment.f | segment.g | segment.e | segment.b,
        segment.e | segment.a | segment.f | segment.b,
        segment.c | segment.a | segment.g | segment.e | segment.d | segment.b,
        segment.a | segment.b,
    }));
}

fn mapWhittle(map: *[7]u7, this_representation: u7, canonical_representation: u7) void {
    for (integer_to_array(this_representation)) |bit, bit_index| {
        if (bit == 1) {
            map[bit_index] &= canonical_representation;
        } else {
            map[bit_index] &= ~canonical_representation;
        }
    }
}

test mapWhittle {
    var map: [7]u7 = [_]u7{0b111_1111} ** 7;
    mapWhittle(&map, segment.a | segment.b, canonical_digit_representation[1]);
    try std.testing.expectEqual([7]u7{
        0b0010010,
        0b0010010,
        0b1101101,
        0b1101101,
        0b1101101,
        0b1101101,
        0b1101101,
    }, map);

    mapWhittle(&map, segment.d | segment.a | segment.b, canonical_digit_representation[7]);
    try std.testing.expectEqual([7]u7{
        0b0010010,
        0b0010010,
        0b0101101,
        0b1000000,
        0b0101101,
        0b0101101,
        0b0101101,
    }, map);

    mapWhittle(&map, segment.e | segment.a | segment.f | segment.b, canonical_digit_representation[4]);
    try std.testing.expectEqual([7]u7{
        0b0010010,
        0b0010010,
        0b0000101,
        0b1000000,
        0b0101000,
        0b0101000,
        0b0000101,
    }, map);

    mapWhittle(&map, segment.g, segment.e);
    std.debug.print("\n", .{});
    for (map) |digit| {
        std.debug.print("{b: >7}\n", .{digit});
    }
    std.debug.print("\n", .{});
    try std.testing.expectEqual([7]u7{
        0b0010010,
        0b0010010,
        0b0000001,
        0b1000000,
        0b0101000,
        0b0101000,
        0b0000100,
    }, map);
}

test "whittle full block by single segment" {
    var map: [7]u7 = [_]u7{0b111_1111} ** 7;
    mapWhittle(&map, segment.g, segment.e);
    std.debug.print("\n", .{});
    for (map) |digit| {
        std.debug.print("{b: >7}\n", .{digit});
    }
    std.debug.print("\n", .{});
    try std.testing.expectEqual([7]u7{
        0b1111011,
        0b1111011,
        0b1111011,
        0b1111011,
        0b1111011,
        0b1111011,
        0b0000100,
    }, map);
}

fn integer_to_array(integer: u7) [7]u1 {
    var array: [7]u1 = undefined;
    var i: u3 = 0;
    while (i < 7) : (i += 1) {
        array[i] = @truncate(u1, integer >> (6 - i));
    }
    return array;
}
