const std = @import("std");

const DATA = @embedFile("./data/day8.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(DATA)});
}

const Segments = [7]u1;
const digits_segment_count = .{ 6, 2, 5, 5, 4, 5, 6, 3, 7, 6 };

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

test {
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
