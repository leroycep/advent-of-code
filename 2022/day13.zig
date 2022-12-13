const std = @import("std");

const DATA = @embedFile("data/day13.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(arena.allocator(), DATA)});
    try out.print("{}\n", .{try challenge2(arena.allocator(), DATA)});
}

pub fn challenge1(allocator: std.mem.Allocator, input: []const u8) !u64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var pair_index_sum: u64 = 0;

    var lines_iterator = std.mem.split(u8, input, "\n");
    var pair_index: u64 = 1;
    while (true) : (pair_index += 1) {
        const left_line = lines_iterator.next() orelse break;
        const right_line = lines_iterator.next() orelse break;

        if (left_line.len == 0 or right_line.len == 0) break;

        const left = try Packet.parse(arena.allocator(), left_line);
        const right = try Packet.parse(arena.allocator(), right_line);

        const order = left.order(right);
        if (order == .lt) {
            pair_index_sum += pair_index;
        }

        // skip blank line
        _ = lines_iterator.next() orelse break;
    }

    return pair_index_sum;
}

pub fn challenge2(allocator: std.mem.Allocator, input: []const u8) !u64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var packets = std.ArrayList(Packet).init(arena.allocator());

    const dividers = [2]Packet{
        try Packet.parse(arena.allocator(), "[[2]]"), try Packet.parse(arena.allocator(), "[[6]]"),
    };
    try packets.appendSlice(&dividers);

    var lines_iterator = std.mem.split(u8, input, "\n");
    while (lines_iterator.next()) |line| {
        if (line.len == 0) continue;

        const packet = try Packet.parse(arena.allocator(), line);

        try packets.append(packet);
    }

    std.sort.sort(Packet, packets.items, {}, Packet.lessThan);

    var divider2_index: usize = std.math.maxInt(usize);
    var divider6_index: usize = std.math.maxInt(usize);
    for (packets.items) |packet, index| {
        if (packet.order(dividers[0]) == .eq) {
            divider2_index = index;
        }
        if (packet.order(dividers[1]) == .eq) {
            divider6_index = index;
        }
    }

    return (divider2_index + 1) * (divider6_index + 1);
}

const TEST_DATA =
    \\[1,1,3,1,1]
    \\[1,1,5,1,1]
    \\
    \\[[1],[2,3,4]]
    \\[[1],4]
    \\
    \\[9]
    \\[[8,7,6]]
    \\
    \\[[4,4],4,4]
    \\[[4,4],4,4,4]
    \\
    \\[7,7,7,7]
    \\[7,7,7]
    \\
    \\[]
    \\[3]
    \\
    \\[[[]]]
    \\[[]]
    \\
    \\[1,[2,[3,[4,[5,6,7]]]],8,9]
    \\[1,[2,[3,[4,[5,6,0]]]],8,9]
    \\
;

test challenge1 {
    const output = try challenge1(std.testing.allocator, TEST_DATA);
    try std.testing.expectEqual(@as(u64, 13), output);
}

test challenge2 {
    const output = try challenge2(std.testing.allocator, TEST_DATA);
    try std.testing.expectEqual(@as(u64, 140), output);
}

const Packet = union(enum) {
    int: u8,
    list: []const Packet,

    pub fn parse(allocator: std.mem.Allocator, string: []const u8) !@This() {
        var pos: usize = 0;
        return try parseInternal(allocator, string, &pos);
    }

    pub fn parseInternal(allocator: std.mem.Allocator, string: []const u8, pos: *usize) !@This() {
        if (string[pos.*] != '[') return error.InvalidFormat;
        pos.* += 1;
        var list = std.ArrayList(Packet).init(allocator);
        while (pos.* < string.len) : (pos.* += 1) {
            switch (string[pos.*]) {
                '[' => try list.append(try parseInternal(allocator, string, pos)),
                '0'...'9' => {
                    const end_of_int = std.mem.indexOfAnyPos(u8, string, pos.*, ",]") orelse return error.InvalidFormat;
                    const int = try std.fmt.parseInt(u8, string[pos.*..end_of_int], 10);
                    pos.* = end_of_int - 1;
                    try list.append(.{ .int = int });
                },
                ',' => {},
                else => return error.InvalidFormat,

                ']' => {
                    return @This(){ .list = list.toOwnedSlice() };
                },
            }
        }
        return error.InvalidFormat;
    }

    test parse {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const packet = try parse(arena.allocator(), "[[1],[2,3,4]]");
        try std.testing.expect(packet == .list);
        try std.testing.expect(packet.list.len == 2);

        try std.testing.expect(packet.list[0] == .list);
        try std.testing.expect(packet.list[0].list[0] == .int);
    }

    pub fn lessThan(_: void, a: @This(), b: @This()) bool {
        return order(a, b) == .lt;
    }

    pub fn order(a: @This(), b: @This()) std.math.Order {
        if (a == .int and b == .int) {
            return std.math.order(a.int, b.int);
        } else if (a == .list and b == .list) {
            for (a.list) |child_a, index| {
                if (index >= b.list.len) return .gt;

                switch (order(child_a, b.list[index])) {
                    .eq => {},
                    else => |ord| return ord,
                }
            } else if (a.list.len < b.list.len) {
                return .lt;
            }

            return .eq;
        } else if (a == .int and b == .list) {
            return order(Packet{ .list = &.{a} }, b);
        } else if (a == .list and b == .int) {
            return order(a, Packet{ .list = &.{b} });
        }
        unreachable;
    }

    test order {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        try std.testing.expectEqual(std.math.Order.lt, order(try parse(arena.allocator(), "[1,1,3,1,1]"), try parse(arena.allocator(), "[1,1,5,1,1]")));
        try std.testing.expectEqual(std.math.Order.lt, order(try parse(arena.allocator(), "[[1],[2,3,4]]"), try parse(arena.allocator(), "[[1],4]")));
        try std.testing.expectEqual(std.math.Order.gt, order(try parse(arena.allocator(), "[[9]]"), try parse(arena.allocator(), "[[8,7,6]]")));
        try std.testing.expectEqual(std.math.Order.lt, order(try parse(arena.allocator(), "[[4,4],4,4]"), try parse(arena.allocator(), "[[4,4],4,4,4]")));
        try std.testing.expectEqual(std.math.Order.gt, order(try parse(arena.allocator(), "[7,7,7,7]"), try parse(arena.allocator(), "[7,7,7]")));
        try std.testing.expectEqual(std.math.Order.lt, order(try parse(arena.allocator(), "[]"), try parse(arena.allocator(), "[3]")));
        try std.testing.expectEqual(std.math.Order.gt, order(try parse(arena.allocator(), "[[[]]]"), try parse(arena.allocator(), "[[]]")));
        try std.testing.expectEqual(std.math.Order.gt, order(try parse(arena.allocator(), "[1,[2,[3,[4,[5,6,7]]]],8,9]"), try parse(arena.allocator(), "[1,[2,[3,[4,[5,6,0]]]],8,9]")));
    }
};
