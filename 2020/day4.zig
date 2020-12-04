const std = @import("std");

const byr = 0b00000001;
const iyr = 0b00000010;
const eyr = 0b00000100;
const hgt = 0b00001000;
const hcl = 0b00010000;
const ecl = 0b00100000;
const pid = 0b01000000;
const cid = 0b10000000;

const Fields = u8;
const REQUIRED_FIELDS = byr | iyr | eyr | hgt | hcl | ecl | pid;

pub fn countValidPassports(data: []const u8) usize {
    var valid_passports: usize = 0;
    var record_iter = std.mem.split(data, "\n\n");
    while (record_iter.next()) |record| {
        var valid_fields: Fields = 0;

        var entry_iter = std.mem.tokenize(record, "\r\n ");
        while (entry_iter.next()) |entry| {
            var kv_iter = std.mem.split(entry, ":");
            const key = kv_iter.next() orelse continue;
            const value = kv_iter.rest();

            if (std.mem.eql(u8, "byr", key)) {
                const birth_year = std.fmt.parseInt(u64, value, 10) catch continue;
                if (birth_year < 1920 or 2002 < birth_year) continue;
                valid_fields |= byr;
            } else if (std.mem.eql(u8, "iyr", key)) {
                const issue_year = std.fmt.parseInt(u64, value, 10) catch continue;
                if (issue_year < 2010 or 2020 < issue_year) continue;
                valid_fields |= iyr;
            } else if (std.mem.eql(u8, "eyr", key)) {
                const expiration_year = std.fmt.parseInt(u64, value, 10) catch continue;
                if (expiration_year < 2020 or 2030 < expiration_year) continue;
                valid_fields |= eyr;
            } else if (std.mem.eql(u8, "hgt", key)) {
                if (std.mem.endsWith(u8, value, "in")) {
                    const height = std.fmt.parseInt(u64, value[0 .. value.len - 2], 10) catch continue;
                    if (height < 59 or 76 < height) continue;
                    valid_fields |= hgt;
                } else if (std.mem.endsWith(u8, value, "cm")) {
                    const height = std.fmt.parseInt(u64, value[0 .. value.len - 2], 10) catch continue;
                    if (height < 150 or 193 < height) continue;
                    valid_fields |= hgt;
                }
            } else if (std.mem.eql(u8, "hcl", key)) {
                if (value.len != 7) continue;
                if (value[0] != '#') continue;
                for (value[1..]) |char| {
                    if (!std.ascii.isDigit(char) or !(char >= 'a' and char <= 'f')) {
                        continue;
                    }
                }
                valid_fields |= hcl;
            } else if (std.mem.eql(u8, "ecl", key)) {
                const VALID_EYE_COLORS = [_][]const u8{
                    "amb", "blu", "brn", "gry", "grn", "hzl", "oth",
                };
                for (VALID_EYE_COLORS) |color| {
                    if (std.mem.eql(u8, color, value)) {
                        valid_fields |= ecl;
                        continue;
                    }
                }
            } else if (std.mem.eql(u8, "pid", key)) {
                if (value.len != 9) continue;
                for (value) |char| {
                    if (!std.ascii.isDigit(char)) {
                        continue;
                    }
                }
                valid_fields |= pid;
            } else if (std.mem.eql(u8, "cid", key)) {
                valid_fields |= cid;
            }
        }

        if (valid_fields & REQUIRED_FIELDS == REQUIRED_FIELDS) {
            valid_passports += 1;
        }
    }

    return valid_passports;
}

pub fn main() !void {
    const data = @embedFile("./day4.txt");

    const valid_passports = countValidPassports(data);

    const out = std.io.getStdOut().writer();
    try out.print("There are {} valid passports\n", .{valid_passports});
}

test "read passports" {
    const data =
        \\ ecl:gry pid:860033327 eyr:2020 hcl:#fffffd
        \\ byr:1937 iyr:2017 cid:147 hgt:183cm
        \\
        \\ iyr:2013 ecl:amb cid:350 eyr:2023 pid:028048884
        \\ hcl:#cfa07d byr:1929
        \\
        \\ hcl:#ae17e1 iyr:2013
        \\ eyr:2024
        \\ ecl:brn pid:760753108 byr:1931
        \\ hgt:179cm
        \\
        \\ hcl:#cfa07d eyr:2025 pid:166559648
        \\ iyr:2011 ecl:brn hgt:59in
    ;

    const valid_passports = countValidPassports(data);

    std.testing.expectEqual(@as(usize, 2), valid_passports);
}
