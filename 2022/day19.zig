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
    try out.print("{}\n", .{try calculateProductOfFirst3Blueprints(arena.allocator(), DATA)});
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

fn calculateProductOfFirst3Blueprints(allocator: std.mem.Allocator, input: []const u8) !u64 {
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

    var blueprints_product: u64 = 1;
    for (blueprints.items[0..@min(blueprints.items.len, 3)]) |blueprint| {
        const geodes_cracked = try calculateGeodesCanCrack(allocator, blueprint, .{ .time_left = 32 });
        std.debug.print("blueprints[{}] can crack {} geodes\n", .{ blueprint.id, geodes_cracked });
        blueprints_product *= geodes_cracked;
    }

    return blueprints_product;
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
        const time_needed = (std.math.divCeil(i64, @max(0, blueprint.ore_robot_ore - this.ore), this.ore_robots) catch return null) + 1;
        if (time_needed > this.time_left) return null;
        next = next.collectResources(time_needed);
        next.ore -= blueprint.ore_robot_ore;
        next.ore_robots += 1;
        return next;
    }

    fn buildClayRobot(this: @This(), blueprint: Blueprint) ?@This() {
        var next = this;
        const time_needed = (std.math.divCeil(i64, @max(0, blueprint.clay_robot_ore - this.ore), this.ore_robots) catch return null) + 1;
        if (time_needed > this.time_left) return null;
        next = next.collectResources(time_needed);
        next.ore -= blueprint.clay_robot_ore;
        next.clay_robots += 1;
        return next;
    }

    fn buildObsidianRobot(this: @This(), blueprint: Blueprint) ?@This() {
        var next = this;
        const time_needed = @max(
            std.math.divCeil(i64, @max(0, blueprint.obsidian_robot_ore - this.ore), this.ore_robots) catch return null,
            std.math.divCeil(i64, @max(0, blueprint.obsidian_robot_clay - this.clay), this.clay_robots) catch return null,
        ) + 1;
        if (time_needed > this.time_left) return null;
        next = next.collectResources(time_needed);
        next.ore -= blueprint.obsidian_robot_ore;
        next.clay -= blueprint.obsidian_robot_clay;
        next.obsidian_robots += 1;
        return next;
    }

    fn buildGeodeRobot(this: @This(), blueprint: Blueprint) ?@This() {
        var next = this;
        const time_needed = @max(
            std.math.divCeil(i64, @max(0, blueprint.geode_robot_ore - this.ore), this.ore_robots) catch return null,
            std.math.divCeil(i64, @max(0, blueprint.geode_robot_obsidian - this.obsidian), this.obsidian_robots) catch return null,
        ) + 1;
        if (time_needed > this.time_left) return null;
        next = next.collectResources(time_needed);
        next.ore -= blueprint.geode_robot_ore;
        next.obsidian -= blueprint.geode_robot_obsidian;
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

    fn geodesAtTime0(this: @This()) i64 {
        return this.geodes + this.time_left * this.geode_robots;
    }
};

fn calculateGeodesCanCrack(allocator: std.mem.Allocator, blueprint: Blueprint, current_resources: Resources) !u64 {
    const resources_steps = try findBestPlan(allocator, blueprint, current_resources);
    defer allocator.free(resources_steps);
    for (resources_steps) |step, i| {
        std.debug.print("step[{}] = {}\n", .{ i, step });
    }
    return @intCast(u64, resources_steps[resources_steps.len - 1].geodesAtTime0());
}

fn findBestPlan(allocator: std.mem.Allocator, blueprint: Blueprint, current_resources: Resources) ![]Resources {
    // inverse of the max possible geodes
    var distances = std.AutoHashMap(Resources, i64).init(allocator);
    defer distances.deinit();

    var previous = std.AutoHashMap(Resources, Resources).init(allocator);
    defer previous.deinit();

    var next_to_check = std.PriorityQueue(Resources, Blueprint, compareResources).init(allocator, blueprint);
    defer next_to_check.deinit();

    try distances.put(current_resources, 0);
    try next_to_check.add(current_resources);

    var max_geodes_at_time0: Resources = .{ .time_left = 0 };

    while (next_to_check.removeOrNull()) |resources| {
        // std.debug.print("resources = {}\n", .{resources});
        if (resources.geodesAtTime0() > max_geodes_at_time0.geodesAtTime0()) {
            max_geodes_at_time0 = resources;
            std.debug.print("new min distance = {}\n", .{max_geodes_at_time0});
        }
        if (resources.time_left <= 0) {
            continue;
        }

        var neighbors = std.BoundedArray(Resources, 10){};
        if (resources.buildGeodeRobot(blueprint)) |with_new_robot| {
            if (with_new_robot.time_left > 0) {
                try neighbors.append(with_new_robot);
            }
        }
        {
            const max_potentially_needed = (resources.time_left) * blueprint.geode_robot_obsidian;
            const amount_will_have = resources.time_left * resources.obsidian_robots + resources.obsidian;
            if (amount_will_have < max_potentially_needed) {
                if (resources.buildObsidianRobot(blueprint)) |with_new_robot| {
                    try neighbors.append(with_new_robot);
                }
            }
        }
        {
            // const max_potentially_needed = resources.time_left * std.mem.max(i64, &.{blueprint.obsidian_robot_clay});
            // const amount_will_have = resources.time_left * resources.clay_robots + resources.clay;
            // if (amount_will_have < max_potentially_needed) {
            if (resources.buildClayRobot(blueprint)) |with_new_robot| {
                try neighbors.append(with_new_robot);
            }
            // }
        }
        {
            const max_potentially_needed = resources.time_left * std.mem.max(i64, &.{ blueprint.ore_robot_ore, blueprint.clay_robot_ore, blueprint.obsidian_robot_ore, blueprint.geode_robot_ore });
            const amount_will_have = resources.time_left * resources.ore_robots + resources.ore;
            if (amount_will_have < max_potentially_needed) {
                if (resources.buildOreRobot(blueprint)) |with_new_robot| {
                    try neighbors.append(with_new_robot);
                }
            }
        }
        for (neighbors.slice()) |neighbor| {
            if (maxPotentialGeodes(neighbor) < max_geodes_at_time0.geodesAtTime0()) {
                continue;
            }

            try next_to_check.add(neighbor);
            try previous.put(neighbor, resources);
        }
    }

    var best_plan = std.ArrayList(Resources).init(allocator);
    defer best_plan.deinit();
    try best_plan.append(max_geodes_at_time0);

    var step_back = previous.get(max_geodes_at_time0) orelse {
        const steps = try best_plan.toOwnedSlice();
        return steps;
    };
    while (!std.meta.eql(step_back, current_resources)) : (step_back = previous.get(step_back).?) {
        try best_plan.append(step_back);
    }

    const steps = try best_plan.toOwnedSlice();
    std.mem.reverse(Resources, steps);

    return steps;
}

pub fn compareResources(blueprint: Blueprint, a: Resources, b: Resources) std.math.Order {
    _ = blueprint;
    switch (std.math.order(-maxPotentialGeodes(a), -maxPotentialGeodes(b))) {
        .lt, .gt => |order| return order,
        .eq => return std.math.order(numberOfRobotsBuilt(a), numberOfRobotsBuilt(b)),
    }
}

fn maxPotentialGeodes(resources: Resources) i64 {
    return resources.geodes + resources.geode_robots * resources.time_left + @divFloor(@max(0, resources.time_left - 1) * resources.time_left, 2);
}

fn numberOfRobotsBuilt(resources: Resources) i64 {
    return resources.geode_robots + resources.obsidian_robots + resources.clay_robots + resources.ore_robots;
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
        .{ .time_left = 21, .ore_robots = 1, .ore = 1, .clay_robots = 1 },
        .{ .time_left = 19, .ore_robots = 1, .ore = 1, .clay_robots = 2, .clay = 2 },
        .{ .time_left = 17, .ore_robots = 1, .ore = 1, .clay_robots = 3, .clay = 6 },
        .{ .time_left = 13, .ore_robots = 1, .ore = 2, .clay_robots = 3, .clay = 4, .obsidian_robots = 1 },
        .{ .time_left = 12, .ore_robots = 1, .ore = 1, .clay_robots = 4, .clay = 7, .obsidian_robots = 1, .obsidian = 1 },
        .{ .time_left = 9, .ore_robots = 1, .ore = 1, .clay_robots = 4, .clay = 5, .obsidian_robots = 2, .obsidian = 4 },
        .{ .time_left = 6, .ore_robots = 1, .ore = 2, .clay_robots = 4, .clay = 17, .obsidian_robots = 2, .obsidian = 3, .geode_robots = 1 },
        .{ .time_left = 3, .ore_robots = 1, .ore = 3, .clay_robots = 4, .clay = 29, .obsidian_robots = 2, .obsidian = 2, .geode_robots = 2, .geodes = 3 },
    }, output);
}

test "challenge 2" {
    const output = try calculateProductOfFirst3Blueprints(std.testing.allocator, TEST_DATA);
    try std.testing.expectEqual(@as(u64, 62 * 56), output);
}
