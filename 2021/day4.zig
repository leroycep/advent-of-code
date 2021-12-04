const std = @import("std");

const DATA = @embedFile("./data/day4.txt");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try challenge1(&arena.allocator, DATA)});
}

pub fn challenge1(allocator: *std.mem.Allocator, data: []const u8) !u64 {
    const bingo = try parseFile(allocator, data);
    defer {
        allocator.free(bingo.numbers);
        allocator.free(bingo.boards);
    }

    var marked: [][5][5]bool = try allocator.alloc([5][5]bool, bingo.boards.len);
    defer allocator.free(marked);
    std.mem.set([5][5]bool, marked, [_][5]bool{[_]bool{false} ** 5} ** 5);

    const winner = bingo: {
        for (bingo.numbers) |number| {
            // Mark boards
            for (bingo.boards) |board, board_id| {
                for (board) |row, y| {
                    for (row) |board_number, x| {
                        if (board_number == number) {
                            marked[board_id][y][x] = true;
                        }
                    }
                }
            }

            // Check for a winner
            for (bingo.boards) |_, board_id| {
                check_rows: for (marked[board_id]) |row, y| {
                    for (row) |is_marked| {
                        if (!is_marked) continue :check_rows;
                    }
                    std.log.debug("board {} won with row {}", .{ board_id, y });
                    break :bingo Winner{
                        .number = number,
                        .boardId = board_id,
                        .rowOrCol = .{ .row = y },
                    };
                }
                check_cols: for (marked[board_id]) |_, x| {
                    for (marked[board_id]) |_, y| {
                        const is_marked = marked[board_id][y][x];
                        if (!is_marked) continue :check_cols;
                    }
                    std.log.debug("board {} won with col {}", .{ board_id, x });
                    break :bingo Winner{
                        .number = number,
                        .boardId = board_id,
                        .rowOrCol = .{ .col = x },
                    };
                }
            }
        }
        return error.NoWinner;
    };

    const winner_unmarked_sum = calcUnmarkedNumbers(bingo.boards[winner.boardId], marked[winner.boardId]);

    return winner.number * winner_unmarked_sum;
}

const Bingo = struct {
    numbers: []u64,
    boards: [][5][5]u64,
};

const Winner = struct {
    number: u64,
    boardId: usize,
    rowOrCol: RowOrCol,
};

const RowOrCol = union(enum) {
    row: usize,
    col: usize,
};

pub fn parseFile(allocator: *std.mem.Allocator, contents: []const u8) !Bingo {
    var item_iter = std.mem.split(u8, contents, "\n\n");

    const numbers_text = item_iter.next() orelse return error.InvalidFormat;
    const numbers = try parseNumbersText(allocator, numbers_text);

    var boards = std.ArrayList([5][5]u64).init(allocator);
    while (item_iter.next()) |board_text| {
        if (std.mem.eql(u8, "", std.mem.trim(u8, board_text, " \n"))) {
            continue;
        }
        try boards.append(try parseBoard(board_text));
    }

    return Bingo{
        .numbers = numbers,
        .boards = boards.toOwnedSlice(),
    };
}

pub fn parseNumbersText(allocator: *std.mem.Allocator, contents: []const u8) ![]u64 {
    var array = std.ArrayList(u64).init(allocator);

    var number_text_iter = std.mem.tokenize(u8, contents, ",");
    while (number_text_iter.next()) |number_text| {
        try array.append(try std.fmt.parseInt(u64, number_text, 10));
    }

    return array.toOwnedSlice();
}

pub fn parseBoard(contents: []const u8) ![5][5]u64 {
    var board: [5][5]u64 = undefined;

    var pos_y: usize = 0;

    var row_iter = std.mem.split(u8, contents, "\n");
    while (row_iter.next()) |row_text| : (pos_y += 1) {
        var pos_x: usize = 0;
        var col_iter = std.mem.tokenize(u8, row_text, " ");
        while (col_iter.next()) |col| : (pos_x += 1) {
            board[pos_y][pos_x] = try std.fmt.parseInt(u64, col, 10);
        }
        if (pos_x != 5) return error.InvalidFormat;
    }

    if (pos_y != 5) return error.InvalidFormat;

    return board;
}

fn calcUnmarkedNumbers(numbers: [5][5]u64, marked: [5][5]bool) u64 {
    var sum: u64 = 0;
    for (numbers) |row, y| {
        for (row) |number, x| {
            if (!marked[y][x]) {
                sum += number;
            }
        }
    }
    return sum;
}

const TEST_CASE =
    \\7,4,9,5,11,17,23,2,0,14,21,24,10,16,13,6,15,25,12,22,18,20,8,19,3,26,1
    \\
    \\22 13 17 11  0
    \\ 8  2 23  4 24
    \\21  9 14 16  7
    \\ 6 10  3 18  5
    \\ 1 12 20 15 19
    \\
    \\ 3 15  0  2 22
    \\ 9 18 13 17  5
    \\19  8  7 25 23
    \\20 11 10 24  4
    \\14 21 16 12  6
    \\
    \\14 21 17 24  4
    \\10 16 15  9 19
    \\18  8 23 26 20
    \\22 11 13  6  5
    \\ 2  0 12  3  7
;

test "challenge1" {
    try std.testing.expectEqual(@as(u64, 4512), try challenge1(std.testing.allocator, TEST_CASE));
}
