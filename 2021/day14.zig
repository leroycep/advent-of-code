const std = @import("std");

const DATA = @embedFile("./data/day14.txt");

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
    polymer_template: []const u8,
    pair_insertion_rules: std.AutoHashMapUnmanaged([2]u8, u8),

    pub fn parse(allocator: std.mem.Allocator, text: []const u8) !TestData {
        var section_iter = std.mem.split(u8, text, "\n\n");

        var this = @This(){
            .polymer_template = section_iter.next() orelse return error.InvalidFormat,
            .pair_insertion_rules = .{},
        };

        const rules_text = section_iter.next() orelse return error.InvalidFormat;

        var line_iter = std.mem.tokenize(u8, rules_text, "\n");
        while (line_iter.next()) |line| {
            var value_iter = std.mem.tokenize(u8, line, " ->");
            const key_value_pair = [2][]const u8{
                value_iter.next() orelse return error.InvalidFormat,
                value_iter.next() orelse return error.InvalidFormat,
            };
            try this.pair_insertion_rules.putNoClobber(allocator, key_value_pair[0][0..2].*, key_value_pair[1][0]);
        }

        return this;
    }

    pub fn deinit(this: *@This(), allocator: std.mem.Allocator) void {
        this.pair_insertion_rules.deinit(allocator);
        this.* = undefined;
    }
};

pub fn challenge1(allocator: std.mem.Allocator, text: []const u8) !u64 {
    var data = try TestData.parse(allocator, text);
    defer data.deinit(allocator);

    var polymer_buffers = [2]std.ArrayListUnmanaged(u8){ .{}, .{} };
    defer {
        polymer_buffers[0].deinit(allocator);
        polymer_buffers[1].deinit(allocator);
    }

    try polymer_buffers[0].appendSlice(allocator, data.polymer_template);

    var iterations: usize = 0;
    while (iterations < 10) : (iterations += 1) {
        const src = &polymer_buffers[iterations % 2];
        const dest = &polymer_buffers[(iterations + 1) % 2];

        dest.shrinkRetainingCapacity(0);
        for (src.items[0..src.items.len -| 1]) |element, i| {
            const element_pair = .{ element, src.items[i + 1] };
            const inbetween = data.pair_insertion_rules.get(element_pair).?;
            try dest.appendSlice(allocator, &.{
                element,
                inbetween,
            });
        }
        try dest.append(allocator, src.items[src.items.len - 1]);

        if (iterations < 4) {
            std.debug.print("{s}\n", .{src.items});
            std.debug.print("{s}\n", .{dest.items});
        }
    }

    var element_counts = std.AutoHashMapUnmanaged(u8, u64){};
    defer element_counts.deinit(allocator);
    for (polymer_buffers[iterations % 2].items) |element| {
        const gop = try element_counts.getOrPut(allocator, element);
        if (!gop.found_existing) {
            gop.value_ptr.* = 0;
        }
        gop.value_ptr.* += 1;
    }

    var min: u64 = std.math.maxInt(u64);
    var max: u64 = 0;
    var iter = element_counts.iterator();
    while (iter.next()) |entry| {
        std.debug.print("{c} = {}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        min = std.math.min(min, entry.value_ptr.*);
        max = std.math.max(max, entry.value_ptr.*);
    }

    return max - min;
}

test challenge1 {
    const TEST_DATA =
        \\NNCB
        \\
        \\CH -> B
        \\HH -> N
        \\CB -> H
        \\NH -> C
        \\HB -> C
        \\HC -> B
        \\HN -> C
        \\NN -> C
        \\BH -> H
        \\NC -> B
        \\NB -> B
        \\BN -> B
        \\BB -> N
        \\BC -> B
        \\CC -> N
        \\CN -> C
        \\
    ;
    try std.testing.expectEqual(@as(u64, 1588), try challenge1(std.testing.allocator, TEST_DATA));
}

const PairIterations = struct {
    pair: [2]u8,
    iterations: u8,
};

const Counts = struct {
    counts: [256]u64 = [1]u64{0} ** 256,

    pub fn add(this: @This(), that: @This()) @This() {
        var result = @This(){};
        for (this.counts) |c, i| {
            result.counts[i] = c + that.counts[i];
        }
        return result;
    }
};

pub fn calculateCountsAfterNIterations(
    rules: std.AutoHashMapUnmanaged([2]u8, u8),
    pair_iterations: PairIterations,
    cache: *std.AutoHashMap(PairIterations, Counts),
) Counts {
    if (cache.get(pair_iterations)) |answer| {
        return answer;
    }
    const inbetween = rules.get(pair_iterations.pair).?;
    if (pair_iterations.iterations == 1) {
        var result = Counts{};
        result.counts[inbetween] = 1;
        return result;
    }

    const left = .{ .pair = .{ pair_iterations.pair[0], inbetween }, .iterations = pair_iterations.iterations - 1 };
    const right = .{ .pair = .{ inbetween, pair_iterations.pair[1] }, .iterations = pair_iterations.iterations - 1 };

    const left_count = calculateCountsAfterNIterations(rules, left, cache);
    const right_count = calculateCountsAfterNIterations(rules, right, cache);
    var count = left_count.add(right_count);
    count.counts[inbetween] += 1;

    cache.put(pair_iterations, count) catch {};

    return count;
}

pub fn challenge2(allocator: std.mem.Allocator, text: []const u8) !u64 {
    var data = try TestData.parse(allocator, text);
    defer data.deinit(allocator);

    var pair_iterations_count_cache = std.AutoHashMap(PairIterations, Counts).init(allocator);
    defer pair_iterations_count_cache.deinit();

    var count_total = Counts{};
    for (data.polymer_template[0..data.polymer_template.len -| 1]) |element, i| {
        const count = calculateCountsAfterNIterations(
            data.pair_insertion_rules,
            .{ .pair = .{ element, data.polymer_template[i + 1] }, .iterations = 40 },
            &pair_iterations_count_cache,
        );
        count_total = count_total.add(count);
        count_total.counts[element] += 1;
    }
    count_total.counts[data.polymer_template[data.polymer_template.len - 1]] += 1;

    var min: u64 = std.math.maxInt(u64);
    var max: u64 = 0;
    for (count_total.counts) |count, c| {
        if (count == 0) continue;
        std.debug.print("{c} = {}\n", .{ @intCast(u8, c), count });
        min = std.math.min(min, count);
        max = std.math.max(max, count);
    }

    return max - min;
}

test challenge2 {
    const TEST_DATA =
        \\NNCB
        \\
        \\CH -> B
        \\HH -> N
        \\CB -> H
        \\NH -> C
        \\HB -> C
        \\HC -> B
        \\HN -> C
        \\NN -> C
        \\BH -> H
        \\NC -> B
        \\NB -> B
        \\BN -> B
        \\BB -> N
        \\BC -> B
        \\CC -> N
        \\CN -> C
        \\
    ;
    try std.testing.expectEqual(@as(u64, 2188189693529), try challenge2(std.testing.allocator, TEST_DATA));
}
