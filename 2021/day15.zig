const std = @import("std");

const DATA = @embedFile("./data/day15.txt");

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
    width: usize,
    danger_levels: []const u8,

    pub fn parse(allocator: std.mem.Allocator, text: []const u8) !TestData {
        var width: usize = 0;
        var danger_levels = std.ArrayList(u8).init(allocator);
        defer danger_levels.deinit();

        var line_iter = std.mem.tokenize(u8, text, "\n");
        while (line_iter.next()) |line| {
            width = line.len;
            for (line) |c| {
                try danger_levels.append(c - '0');
            }
        }

        return @This(){
            .width = width,
            .danger_levels = try danger_levels.toOwnedSlice(),
        };
    }

    pub fn deinit(this: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(this.danger_levels);
        this.* = undefined;
    }
};

pub fn findCheapestPath(allocator: std.mem.Allocator, data: TestData) !u64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const size = @Vector(2, i32){ @intCast(i32, data.width), @intCast(i32, data.danger_levels.len / data.width) };
    const start = [2]i32{ 0, 0 };
    const finish = [2]i32{ size[0] - 1, size[1] - 1 };

    const came_from = try arena.allocator().alloc(u32, data.danger_levels.len);
    std.mem.set(u32, came_from, std.math.maxInt(u32));

    const cost_to_path = try arena.allocator().alloc(u64, data.danger_levels.len);
    std.mem.set(u64, cost_to_path, std.math.maxInt(u64));
    cost_to_path[0] = 0;

    const estimated_cost_from_node = try arena.allocator().alloc(u64, data.danger_levels.len);
    std.mem.set(u64, estimated_cost_from_node, std.math.maxInt(u64));
    estimated_cost_from_node[0] = manhattanDistance(start, finish);

    var next = std.PriorityQueue([2]i32, MapContext, MapContext.compare).init(arena.allocator(), .{ .width = data.width, .estimated_cost_from_node = estimated_cost_from_node });
    try next.add(start);

    while (next.removeOrNull()) |current_pos| {
        if (std.mem.eql(i32, &current_pos, &finish)) {
            break;
        }
        for (NEIGHBORS) |offset| {
            const neighbor_pos = @as(@Vector(2, i32), current_pos) + @as(@Vector(2, i32), offset);
            if (@reduce(.Or, neighbor_pos < @splat(2, @as(i32, 0))) or @reduce(.Or, neighbor_pos >= size)) {
                continue;
            }
            const current = posToIndex(data.width, current_pos);
            const neighbor = posToIndex(data.width, neighbor_pos);
            const tentative_cost = cost_to_path[current] + data.danger_levels[neighbor];
            if (tentative_cost < cost_to_path[neighbor]) {
                came_from[neighbor] = current;
                cost_to_path[neighbor] = tentative_cost;
                estimated_cost_from_node[neighbor] = tentative_cost + manhattanDistance(neighbor_pos, finish);
                try next.add(neighbor_pos);
            }
        }
    } else {
        return 0;
    }

    return cost_to_path[posToIndex(data.width, finish)];
}

pub fn challenge1(allocator: std.mem.Allocator, text: []const u8) !u64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const data = try TestData.parse(arena.allocator(), text);

    return findCheapestPath(allocator, data);
}

const NEIGHBORS = [_][2]i32{ .{ 1, 0 }, .{ 0, 1 }, .{ -1, 0 }, .{ 0, -1 } };

fn manhattanDistance(a: @Vector(2, i32), b: @Vector(2, i32)) u64 {
    return @intCast(u64, @reduce(.Add, b - a));
}

fn posToIndex(width: usize, pos: [2]i32) u32 {
    return @intCast(u32, pos[1]) * @intCast(u32, width) + @intCast(u32, pos[0]);
}

const MapContext = struct {
    width: usize,
    estimated_cost_from_node: []u64,

    fn compare(this: @This(), a: [2]i32, b: [2]i32) std.math.Order {
        const index_a = posToIndex(this.width, a);
        const index_b = posToIndex(this.width, b);
        return std.math.order(this.estimated_cost_from_node[index_a], this.estimated_cost_from_node[index_b]);
    }
};

test challenge1 {
    const TEST_DATA =
        \\1163751742
        \\1381373672
        \\2136511328
        \\3694931569
        \\7463417111
        \\1319128137
        \\1359912421
        \\3125421639
        \\1293138521
        \\2311944581
        \\
    ;
    try std.testing.expectEqual(@as(u64, 40), try challenge1(std.testing.allocator, TEST_DATA));
}

pub fn challenge2(allocator: std.mem.Allocator, text: []const u8) !u64 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const data = try TestData.parse(arena.allocator(), text);
    const expanded = try expandMap(arena.allocator(), data);
    return findCheapestPath(allocator, expanded);
}

test challenge2 {
    const TEST_DATA =
        \\1163751742
        \\1381373672
        \\2136511328
        \\3694931569
        \\7463417111
        \\1319128137
        \\1359912421
        \\3125421639
        \\1293138521
        \\2311944581
        \\
    ;
    try std.testing.expectEqual(@as(u64, 315), try challenge2(std.testing.allocator, TEST_DATA));
}

fn expandMap(allocator: std.mem.Allocator, data: TestData) !TestData {
    const data_size = @Vector(2, i32){ @intCast(i32, data.width), @intCast(i32, data.danger_levels.len / data.width) };
    const expanded_size = data_size * @Vector(2, i32){ 5, 5 };

    const expanded_map = try allocator.alloc(u8, @intCast(usize, @reduce(.Mul, expanded_size)));
    var pos = @Vector(2, i32){ 0, 0 };
    while (pos[1] < expanded_size[1]) : (pos[1] += 1) {
        pos[0] = 0;
        while (pos[0] < expanded_size[0]) : (pos[0] += 1) {
            const tile = @divFloor(pos, data_size);
            const danger_offset = @intCast(u8, @reduce(.Add, tile));
            const original_index = posToIndex(@intCast(usize, data_size[0]), @mod(pos, data_size));
            const original_value = data.danger_levels[original_index];
            expanded_map[posToIndex(@intCast(usize, expanded_size[0]), pos)] = ((original_value + danger_offset - 1) % 9) + 1;
        }
    }
    return TestData{
        .width = @intCast(usize, expanded_size[0]),
        .danger_levels = expanded_map,
    };
}

test expandMap {
    const TEST_DATA =
        \\1163751742
        \\1381373672
        \\2136511328
        \\3694931569
        \\7463417111
        \\1319128137
        \\1359912421
        \\3125421639
        \\1293138521
        \\2311944581
        \\
    ;
    const EXPECTED_DATA =
        \\11637517422274862853338597396444961841755517295286
        \\13813736722492484783351359589446246169155735727126
        \\21365113283247622439435873354154698446526571955763
        \\36949315694715142671582625378269373648937148475914
        \\74634171118574528222968563933317967414442817852555
        \\13191281372421239248353234135946434524615754563572
        \\13599124212461123532357223464346833457545794456865
        \\31254216394236532741534764385264587549637569865174
        \\12931385212314249632342535174345364628545647573965
        \\23119445813422155692453326671356443778246755488935
        \\22748628533385973964449618417555172952866628316397
        \\24924847833513595894462461691557357271266846838237
        \\32476224394358733541546984465265719557637682166874
        \\47151426715826253782693736489371484759148259586125
        \\85745282229685639333179674144428178525553928963666
        \\24212392483532341359464345246157545635726865674683
        \\24611235323572234643468334575457944568656815567976
        \\42365327415347643852645875496375698651748671976285
        \\23142496323425351743453646285456475739656758684176
        \\34221556924533266713564437782467554889357866599146
        \\33859739644496184175551729528666283163977739427418
        \\35135958944624616915573572712668468382377957949348
        \\43587335415469844652657195576376821668748793277985
        \\58262537826937364893714847591482595861259361697236
        \\96856393331796741444281785255539289636664139174777
        \\35323413594643452461575456357268656746837976785794
        \\35722346434683345754579445686568155679767926678187
        \\53476438526458754963756986517486719762859782187396
        \\34253517434536462854564757396567586841767869795287
        \\45332667135644377824675548893578665991468977611257
        \\44961841755517295286662831639777394274188841538529
        \\46246169155735727126684683823779579493488168151459
        \\54698446526571955763768216687487932779859814388196
        \\69373648937148475914825958612593616972361472718347
        \\17967414442817852555392896366641391747775241285888
        \\46434524615754563572686567468379767857948187896815
        \\46833457545794456865681556797679266781878137789298
        \\64587549637569865174867197628597821873961893298417
        \\45364628545647573965675868417678697952878971816398
        \\56443778246755488935786659914689776112579188722368
        \\55172952866628316397773942741888415385299952649631
        \\57357271266846838237795794934881681514599279262561
        \\65719557637682166874879327798598143881961925499217
        \\71484759148259586125936169723614727183472583829458
        \\28178525553928963666413917477752412858886352396999
        \\57545635726865674683797678579481878968159298917926
        \\57944568656815567976792667818781377892989248891319
        \\75698651748671976285978218739618932984172914319528
        \\56475739656758684176786979528789718163989182927419
        \\67554889357866599146897761125791887223681299833479
        \\
    ;
    var test_data = try TestData.parse(std.testing.allocator, TEST_DATA);
    defer test_data.deinit(std.testing.allocator);

    var expected_data = try TestData.parse(std.testing.allocator, EXPECTED_DATA);
    defer expected_data.deinit(std.testing.allocator);

    var actual = try expandMap(std.testing.allocator, test_data);
    defer actual.deinit(std.testing.allocator);

    try std.testing.expectEqual(expected_data.width, actual.width);
    try std.testing.expectEqualSlices(u8, expected_data.danger_levels, actual.danger_levels);
}
