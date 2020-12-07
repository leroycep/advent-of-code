const std = @import("std");

const BagRule = struct {
    count: u64,
    color: []const u8,
};

pub fn parseBagRules(allocator: *std.mem.Allocator, rulesText: []const u8) !std.StringHashMap([]BagRule) {
    var rules = std.StringHashMap([]BagRule).init(allocator);
    errdefer {
        var contained_iter = rules.iterator();
        while (contained_iter.next()) |contained| {
            allocator.free(contained.value);
        }
        rules.deinit();
    }

    var rules_iter = std.mem.tokenize(rulesText, "\n\r");
    while (rules_iter.next()) |rule_line| {
        var rule_part_iter = std.mem.split(rule_line, " contain ");

        const color_untrimmed = std.mem.trim(u8, rule_part_iter.next() orelse continue, " ");
        const color = color_untrimmed[0..color_untrimmed.len - 5]; // Get rid of " bags" on the end of the color

        var contained = std.ArrayList(BagRule).init(allocator);
        errdefer contained.deinit();

        var contained_bags_iter = std.mem.split(rule_part_iter.rest(), ", ");
        while (contained_bags_iter.next()) |contained_bag_text_l| {
            var end = contained_bag_text_l.len;
            if (std.mem.endsWith(u8, contained_bag_text_l, " bag")) end -= 4 //
            else if (std.mem.endsWith(u8, contained_bag_text_l, " bags")) end -= 5 //
            else if (std.mem.endsWith(u8, contained_bag_text_l, " bag.")) end -= 5 //
            else if (std.mem.endsWith(u8, contained_bag_text_l, " bags.")) end -= 6;

            const contained_bag_text = contained_bag_text_l[0..end];

            if (std.mem.eql(u8, "no other", contained_bag_text)) {
                continue;
            }

            var contained_bag_iter = std.mem.split(contained_bag_text, " ");

            const count = try std.fmt.parseInt(u64, contained_bag_iter.next().?, 10);
            const contained_color = contained_bag_iter.rest();

            try contained.append(.{ .count = count, .color = contained_color });
        }

        try rules.put(color, contained.toOwnedSlice());
    }

    return rules;
}

fn numCanContain(allocator: *std.mem.Allocator, rules: std.StringHashMap([]BagRule), colorToCheck: []const u8) !u64 {
    var cache = std.StringHashMap(bool).init(allocator);
    defer cache.deinit();

    var countTotal: u64 = 0;

    var rules_iter = rules.iterator();
    while (rules_iter.next()) |rule| {
        if (std.mem.eql(u8, colorToCheck, rule.key)) continue;

        if (try canContainInternal(rules, &cache, colorToCheck, rule.key)) {
            countTotal += 1;
        }
    }

    return countTotal;
}

fn canContainInternal(rules: std.StringHashMap([]BagRule), cache: *std.StringHashMap(bool), colorToCheck: []const u8, currentColor: []const u8) error{OutOfMemory}!bool {
    if (cache.get(currentColor)) |contains_color| {
        return contains_color;
    }
    const contained_bags = rules.get(currentColor) orelse return false;

    for (contained_bags) |contained| {
        if (std.mem.eql(u8, colorToCheck, contained.color)) {
            try cache.put(currentColor, true);
            return true;
        } else if (try canContainInternal(rules, cache, colorToCheck, contained.color)) {
            try cache.put(currentColor, true);
            return true;
        }
    }

    try cache.put(currentColor, false);
    return false;
}

test "fdas" {
    const input =
        \\ light red bags contain 1 bright white bag, 2 muted yellow bags.
        \\ dark orange bags contain 3 bright white bags, 4 muted yellow bags.
        \\ bright white bags contain 1 shiny gold bag.
        \\ muted yellow bags contain 2 shiny gold bags, 9 faded blue bags.
        \\ shiny gold bags contain 1 dark olive bag, 2 vibrant plum bags.
        \\ dark olive bags contain 3 faded blue bags, 4 dotted black bags.
        \\ vibrant plum bags contain 5 faded blue bags, 6 dotted black bags.
        \\ faded blue bags contain no other bags.
        \\ dotted black bags contain no other bags.
    ;

    var rules = try parseBagRules(std.testing.allocator, input);
    defer {
        var contained_iter = rules.iterator();
        while (contained_iter.next()) |contained| {
            std.testing.allocator.free(contained.value);
        }
        rules.deinit();
    }

    var contained_iter = rules.iterator();
    while (contained_iter.next()) |contained| {
        std.log.warn("contained: {}", .{contained});
    }

    const num = try numCanContain(std.testing.allocator, rules, "shiny gold");
    std.log.warn("num can contain: {}", .{num});
}

const INPUT = @embedFile("./day7.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    const out = std.io.getStdOut().writer();
    
    var rules = try parseBagRules(std.testing.allocator, INPUT);
    defer {
        var contained_iter = rules.iterator();
        while (contained_iter.next()) |contained| {
            std.testing.allocator.free(contained.value);
        }
        rules.deinit();
    }

    const num = try numCanContain(std.testing.allocator, rules, "shiny gold");
    try out.print("{} bags can contained shiny gold\n", .{num});
}
