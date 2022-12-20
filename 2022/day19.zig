const std = @import("std");
const glfw = @import("glfw");
const gl = @import("zgl");
const nanovg = @import("nanovg");
const Grid = @import("util").Grid;
const ConstGrid = @import("util").ConstGrid;

const DATA = @embedFile("data/day19.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const out = std.io.getStdOut().writer();
    try out.print("{}\n", .{try calculateQualityLevels(arena.allocator(), DATA)});
    // try out.print("{}\n", .{try calculateExteriorSurfaceArea(arena.allocator(), DATA)});
}

const Blueprint = struct {
    id: u64,
    ore_robot_ore: i64,
    clay_robot_ore: i64,
    obsidian_robot_ore: i64,
    obsidian_robot_clay: i64,
    geode_robot_ore: i64,
    geode_robot_obsidian: i64,
};

fn calculateQualityLevels(allocator: std.mem.Allocator, input: []const u8) !u64 {
    var blueprints = std.ArrayList(Blueprint).init(allocator);
    defer blueprints.deinit();

    var line_iterator = std.mem.tokenize(u8, input, "\n");
    while (line_iterator.next()) |line| {
        var blueprint: Blueprint = undefined;

        var number_iterator = std.mem.tokenize(u8, line, "Blueprint: Each ore robot costs  ore. Each clay robot costs  ore. Each obsidian robot costs  ore and  clay. Each geode robot costs  ore and  obsidian.");
        blueprint.id = try std.fmt.parseInt(u64, number_iterator.next() orelse return error.InvalidFormat, 10);
        blueprint.ore_robot_ore = try std.fmt.parseInt(i16, number_iterator.next() orelse return error.InvalidFormat, 10);
        blueprint.clay_robot_ore = try std.fmt.parseInt(i16, number_iterator.next() orelse return error.InvalidFormat, 10);
        blueprint.obsidian_robot_ore = try std.fmt.parseInt(i16, number_iterator.next() orelse return error.InvalidFormat, 10);
        blueprint.obsidian_robot_clay = try std.fmt.parseInt(i16, number_iterator.next() orelse return error.InvalidFormat, 10);
        blueprint.geode_robot_ore = try std.fmt.parseInt(i16, number_iterator.next() orelse return error.InvalidFormat, 10);
        blueprint.geode_robot_obsidian = try std.fmt.parseInt(i16, number_iterator.next() orelse return error.InvalidFormat, 10);

        try blueprints.append(blueprint);
    }

    var total_blueprints_quality: u64 = 0;
    for (blueprints.items) |blueprint| {
        const geodes_cracked = try calculateGeodesCanCrack(allocator, blueprint, .{});
        std.debug.print("blueprints[{}] can crack {} geodes\n", .{ blueprint.id, geodes_cracked });
        total_blueprints_quality += geodes_cracked * blueprint.id;
    }

    return total_blueprints_quality;
}

const Resources = struct {
    time_left: i64 = 24,
    ore_robots: i64 = 1,
    ore: i64 = 0,
    clay_robots: i64 = 0,
    clay: i64 = 0,
    obsidian_robots: i64 = 0,
    obsidian: i64 = 0,
    geode_robots: i64 = 0,
    geodes: i64 = 0,

    fn buildOreRobot(this: @This(), blueprint: Blueprint) ?@This() {
        var next = this;
        next.ore -= blueprint.ore_robot_ore;
        if (next.ore < 0) return null;
        next = next.collectResources(1);
        next.ore_robots += 1;
        return next;
    }

    fn buildClayRobot(this: @This(), blueprint: Blueprint) ?@This() {
        var next = this;
        next.ore -= blueprint.clay_robot_ore;
        if (next.ore < 0) return null;

        next = next.collectResources(1);

        next.clay_robots += 1;
        return next;
    }

    fn buildObsidianRobot(this: @This(), blueprint: Blueprint) ?@This() {
        var next = this;
        next.ore -= blueprint.obsidian_robot_ore;
        next.clay -= blueprint.obsidian_robot_clay;
        if (next.ore < 0 or next.clay < 0) return null;

        next = next.collectResources(1);

        next.obsidian_robots += 1;
        return next;
    }

    fn buildGeodeRobot(this: @This(), blueprint: Blueprint) ?@This() {
        var next = this;
        next.ore -= blueprint.geode_robot_ore;
        next.obsidian -= blueprint.geode_robot_obsidian;
        if (next.ore < 0 or next.obsidian < 0) return null;

        next = next.collectResources(1);

        next.geode_robots += 1;
        return next;
    }

    fn collectResources(this: @This(), time_spent: i64) @This() {
        var next = this;
        next.time_left -= time_spent;

        next.ore += this.ore_robots * time_spent;
        next.clay += this.clay_robots * time_spent;
        next.obsidian += this.obsidian_robots * time_spent;
        next.geodes += this.geode_robots * time_spent;

        return next;
    }
};

const ResourcesGathered = struct {
    time_left: u16,
    ore: u16,
    clay: u16,
    obsidian: u16,
    geodes: u16,

    fn fromResource(resources: Resources) @This() {
        return @This(){
            .time_left = @intCast(u16, resources.time_left),
            .ore = @intCast(u16, resources.ore),
            .clay = @intCast(u16, resources.clay),
            .obsidian = @intCast(u16, resources.obsidian),
            .geodes = @intCast(u16, resources.geodes),
        };
    }
};

fn calculateGeodesCanCrack(allocator: std.mem.Allocator, blueprint: Blueprint, current_resources: Resources) !u64 {
    const resources_steps = try findBestPlan(allocator, blueprint, current_resources);
    defer allocator.free(resources_steps);
    for (resources_steps) |step, i| {
        std.debug.print("step[{}] = {}\n", .{ i, step });
    }
    return @intCast(u64, resources_steps[resources_steps.len - 1].geodes);
}

fn findBestPlan(allocator: std.mem.Allocator, blueprint: Blueprint, current_resources: Resources) ![]Resources {
    var max_gather_single_resource = @divFloor(current_resources.time_left * (current_resources.time_left + 1), 2);

    // inverse of the max possible geodes
    var distances = std.AutoHashMap(ResourcesGathered, i64).init(allocator);
    defer distances.deinit();

    var previous = std.AutoHashMap(Resources, Resources).init(allocator);
    defer previous.deinit();

    var next_to_check = std.PriorityQueue(Resources, ResourceCompareContext, ResourceCompareContext.compare).init(allocator, .{ .blueprint = blueprint, .max_gather_single_resource = max_gather_single_resource });
    defer next_to_check.deinit();

    try distances.put(ResourcesGathered.fromResource(current_resources), 0);
    try next_to_check.add(current_resources);

    var min_distance: i64 = std.math.maxInt(i64);
    var min_distance_resources: Resources = undefined;

    while (next_to_check.removeOrNull()) |resources| {
        const robots_built = ResourcesGathered.fromResource(resources);
        const this_distance = distances.get(robots_built).?;
        // std.debug.print("distance = {}, resources = {}\n", .{ this_distance, resources });

        if (resources.time_left <= 0) {
            if (this_distance < min_distance) {
                min_distance = this_distance;
                min_distance_resources = resources;
                std.debug.print("new min distance = {}, geodes = {}\n", .{ min_distance, min_distance_resources });
            }
            continue;
        }

        var neighbors = std.BoundedArray(Resources, 10){};
        try neighbors.append(resources.collectResources(1));
        if (resources.buildGeodeRobot(blueprint)) |with_new_robot| {
            try neighbors.append(with_new_robot);
        }
        if (resources.buildObsidianRobot(blueprint)) |with_new_robot| {
            try neighbors.append(with_new_robot);
        }
        if (resources.buildClayRobot(blueprint)) |with_new_robot| {
            try neighbors.append(with_new_robot);
        }
        if (resources.buildOreRobot(blueprint)) |with_new_robot| {
            try neighbors.append(with_new_robot);
        }

        for (neighbors.slice()) |neighbor| {
            const neighbor_robots_built = ResourcesGathered.fromResource(neighbor);
            const neighbor_distance = valueResourceCollection(max_gather_single_resource, blueprint, neighbor);
            // std.debug.print("neighbor distance = {}, resources = {}\n", .{ neighbor_distance, neighbor });

            const gop = try distances.getOrPut(neighbor_robots_built);
            if (gop.found_existing) {
                if (neighbor_distance < gop.value_ptr.*) {
                    gop.value_ptr.* = neighbor_distance;
                    try next_to_check.add(neighbor);
                    try previous.put(neighbor, resources);
                }
            } else {
                gop.value_ptr.* = neighbor_distance;
                try next_to_check.add(neighbor);
                try previous.put(neighbor, resources);
            }
        }
    }

    var best_plan = std.ArrayList(Resources).init(allocator);
    try best_plan.append(min_distance_resources);

    var step_back = previous.get(min_distance_resources).?;
    while (!std.meta.eql(step_back, current_resources)) : (step_back = previous.get(step_back).?) {
        try best_plan.append(step_back);
    }

    var steps = try best_plan.toOwnedSlice();
    std.mem.reverse(Resources, steps);

    return steps;
}

const ResourceCompareContext = struct {
    blueprint: Blueprint,
    max_gather_single_resource: i64,

    pub fn compare(this: @This(), a: Resources, b: Resources) std.math.Order {
        return std.math.order(valueResourceCollection(this.max_gather_single_resource, this.blueprint, a), valueResourceCollection(this.max_gather_single_resource, this.blueprint, b));
    }
};

fn valueResourceCollection(max_gather_single_resource: i64, blueprint: Blueprint, resources: Resources) i64 {
    const ore_value = 1;
    const clay_value = max_gather_single_resource;
    const obsidian_value = std.math.powi(i64, max_gather_single_resource, 2) catch unreachable;
    const robot_value = std.math.powi(i64, max_gather_single_resource, 3) catch unreachable;
    const geode_value = std.math.powi(i64, max_gather_single_resource, 4) catch unreachable;
    const max_value = std.math.powi(i64, max_gather_single_resource, 5) catch unreachable;

    return max_value - (geode_value * resources.geodes +
        robot_value * 0 +
        obsidian_value * (resources.obsidian + resources.geode_robots * blueprint.geode_robot_obsidian) +
        clay_value * (resources.clay + resources.obsidian_robots * blueprint.obsidian_robot_clay) +
        ore_value * (resources.ore + resources.ore_robots * blueprint.ore_robot_ore + resources.clay_robots * blueprint.clay_robot_ore + resources.obsidian_robots * blueprint.obsidian_robot_ore + resources.geode_robots * blueprint.geode_robot_ore));
}

const TEST_DATA =
    \\Blueprint 1: Each ore robot costs 4 ore. Each clay robot costs 2 ore. Each obsidian robot costs 3 ore and 14 clay. Each geode robot costs 2 ore and 7 obsidian.
    \\Blueprint 2: Each ore robot costs 2 ore. Each clay robot costs 3 ore. Each obsidian robot costs 3 ore and 8 clay. Each geode robot costs 3 ore and 12 obsidian. 
    \\
;

test "challenge 1" {
    const output = try calculateQualityLevels(std.testing.allocator, TEST_DATA);
    try std.testing.expectEqual(@as(u64, 33), output);
}

test "steps to optimal blueprint 1 usage" {
    const output = try findBestPlan(std.testing.allocator, .{
        .id = 1,
        .ore_robot_ore = 4,
        .clay_robot_ore = 2,
        .obsidian_robot_ore = 3,
        .obsidian_robot_clay = 14,
        .geode_robot_ore = 2,
        .geode_robot_obsidian = 7,
    }, .{});
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualSlices(Resources, &.{
        .{ .time_left = 23, .ore_robots = 1, .ore = 1 },
        .{ .time_left = 22, .ore_robots = 1, .ore = 2 },
        .{ .time_left = 21, .ore_robots = 1, .ore = 1, .clay_robots = 1 },
        .{ .time_left = 20, .ore_robots = 1, .ore = 2, .clay_robots = 1, .clay = 1 },
        .{ .time_left = 19, .ore_robots = 1, .ore = 1, .clay_robots = 2, .clay = 2 },
        .{ .time_left = 18, .ore_robots = 1, .ore = 2, .clay_robots = 2, .clay = 4 },
        .{ .time_left = 17, .ore_robots = 1, .ore = 1, .clay_robots = 3, .clay = 6 },
        .{ .time_left = 16, .ore_robots = 1, .ore = 2, .clay_robots = 3, .clay = 9 },
        .{ .time_left = 15, .ore_robots = 1, .ore = 3, .clay_robots = 3, .clay = 12 },
        .{ .time_left = 14, .ore_robots = 1, .ore = 4, .clay_robots = 3, .clay = 15 },
        .{ .time_left = 13, .ore_robots = 1, .ore = 2, .clay_robots = 3, .clay = 4, .obsidian_robots = 1 },
        .{ .time_left = 12, .ore_robots = 1, .ore = 1, .clay_robots = 4, .clay = 7, .obsidian_robots = 1, .obsidian = 1 },
        .{ .time_left = 11, .ore_robots = 1, .ore = 2, .clay_robots = 4, .clay = 11, .obsidian_robots = 1, .obsidian = 2 },
        .{ .time_left = 10, .ore_robots = 1, .ore = 3, .clay_robots = 4, .clay = 15, .obsidian_robots = 1, .obsidian = 3 },
        .{ .time_left = 9, .ore_robots = 1, .ore = 1, .clay_robots = 4, .clay = 5, .obsidian_robots = 2, .obsidian = 4 },
        .{ .time_left = 8, .ore_robots = 1, .ore = 2, .clay_robots = 4, .clay = 9, .obsidian_robots = 2, .obsidian = 6 },
        .{ .time_left = 7, .ore_robots = 1, .ore = 3, .clay_robots = 4, .clay = 13, .obsidian_robots = 2, .obsidian = 8 },
        .{ .time_left = 6, .ore_robots = 1, .ore = 2, .clay_robots = 4, .clay = 17, .obsidian_robots = 2, .obsidian = 3, .geode_robots = 1 },
        .{ .time_left = 5, .ore_robots = 1, .ore = 3, .clay_robots = 4, .clay = 21, .obsidian_robots = 2, .obsidian = 5, .geode_robots = 1, .geodes = 1 },
        .{ .time_left = 4, .ore_robots = 1, .ore = 4, .clay_robots = 4, .clay = 25, .obsidian_robots = 2, .obsidian = 7, .geode_robots = 1, .geodes = 2 },
        .{ .time_left = 3, .ore_robots = 1, .ore = 3, .clay_robots = 4, .clay = 29, .obsidian_robots = 2, .obsidian = 2, .geode_robots = 2, .geodes = 3 },
        .{ .time_left = 2, .ore_robots = 1, .ore = 4, .clay_robots = 4, .clay = 33, .obsidian_robots = 2, .obsidian = 4, .geode_robots = 2, .geodes = 5 },
        .{ .time_left = 1, .ore_robots = 1, .ore = 5, .clay_robots = 4, .clay = 37, .obsidian_robots = 2, .obsidian = 6, .geode_robots = 2, .geodes = 7 },
        .{ .time_left = 0, .ore_robots = 1, .ore = 6, .clay_robots = 4, .clay = 41, .obsidian_robots = 2, .obsidian = 8, .geode_robots = 2, .geodes = 9 },
    }, output);
}
