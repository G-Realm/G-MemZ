const std = @import("std");
const builtin = @import("builtin");
const platform = @import("./platform/process.zig");
const allocator = std.heap.page_allocator;

const RC4_TABLE_SIZE = 256;
const RC4_INVALID_VALUE: u16 = 0xFFFF;
const RC4_INVALID_MASK_FLASH: u64 = 0xFFFFFF00;
const RC4_INVALID_MASK_SHOCKWAVE: u64 = 0xFFFFFFFB_FFFFFF00;

const HotelType = enum {
    FLASH,
    SHOCKWAVE,
};

const HotelSettings = struct {
    tableAlignment: u32,
    invalidMask: u64,
};

var hotelType: HotelType = HotelType.SHOCKWAVE;
var hotelSettings: HotelSettings = undefined;

pub fn main() !void {
    std.debug.print("Running G-MemZ\n", .{});

    try parseArgs();

    // Get processes.
    var processes = try platform.getProcesses();
    defer processes.clearAndFree();

    for (processes.items) |process| {
        if (hotelType == HotelType.FLASH) {
            try checkFlashProcess(process);
        } else if (hotelType == HotelType.SHOCKWAVE) {
            try checkShockwaveProcess(process);
        }
    }

    std.debug.print("Finished\n", .{});
}

fn checkFlashProcess(process: platform.ProcessInformation) !void {
    if (std.mem.containsAtLeast(u8, process.path, 1, "ppapi") or
        std.mem.containsAtLeast(u8, process.path, 1, "plugin-container") or
        std.mem.endsWith(u8, process.path, "Habbo.exe"))
    {
        try checkProcess(process);
    }
}

fn checkShockwaveProcess(process: platform.ProcessInformation) !void {
    if (std.mem.endsWith(u8, process.path, "Habbo.exe") or
        std.mem.containsAtLeast(u8, process.path, 1, "HabboHotel-"))
    {
        try checkProcess(process);
    } else if (process.name != null) {
        if (std.mem.eql(u8, process.name.?, "Habbo.exe") or
            std.mem.containsAtLeast(u8, process.name.?, 1, "HabboHotel-"))
        {
            try checkProcess(process);
        }
    } else if (process.windowName != null) {
        if (std.mem.containsAtLeast(u8, process.windowName.?, 1, "Habbo Hotel: Origins")) {
            try checkProcess(process);
        }
    }
}

fn parseArgs() !void {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip(); // Skip executable name.

    const argHotelType = args.next();
    if (argHotelType == null) {
        std.debug.print("Usage: G-MemZ <flash|shockwave>\n", .{});
        return error.InvalidArgument;
    }

    if (std.mem.eql(u8, argHotelType.?, "flash")) {
        hotelType = HotelType.FLASH;
        hotelSettings.invalidMask = RC4_INVALID_MASK_FLASH;
        hotelSettings.tableAlignment = 4;
    } else if (std.mem.eql(u8, argHotelType.?, "shockwave")) {
        hotelType = HotelType.SHOCKWAVE;
        hotelSettings.invalidMask = RC4_INVALID_MASK_SHOCKWAVE;
        hotelSettings.tableAlignment = 8;
    } else {
        std.debug.print("Usage: G-MemZ <flash|shockwave>\n", .{});
        return error.InvalidArgument;
    }

    std.debug.print("Hotel type: {s}\n", .{@tagName(hotelType)});
}

// Find all memory regions in a process.
fn checkProcess(process: platform.ProcessInformation) !void {
    std.debug.print("Dumping PID {}, Name: \"{?s}\", Window: \"{?s}\", Path: \"{s}\"\n", .{
        process.pid,
        process.name,
        process.windowName,
        process.path,
    });

    // Open process.
    const processHandle = platform.openProcess(process.pid) catch |err| switch (err) {
        error.FailedTaskForPid => {
            std.debug.print("Failed to open process: {}\n", .{process.pid});
            return;
        },
        else => return err,
    };

    defer platform.closeProcess(processHandle);

    // Get process memory maps.
    var memoryMaps = try platform.getMemoryMaps(processHandle);
    defer memoryMaps.clearAndFree();

    std.debug.print("Found {} memory maps\n", .{memoryMaps.items.len});

    for (memoryMaps.items) |map| {
        // Only check maps smaller than 4MB.
        if (map.size > 4 * 1024 * 1024) {
            continue;
        }

        try checkMap(processHandle, map);
    }
}

// Read all memory regions from the process.
fn checkMap(processHandle: u32, map: platform.MemoryMap) !void {
    const buffer = try allocator.alloc(u8, @intCast(map.size));
    defer allocator.free(buffer);

    try platform.readMemory(processHandle, map.base, map.size, buffer.ptr);

    try checkMapOffset(0, buffer, map.base, map.size);

    // Shockwave arrays are stored in memory like this
    // | D6 00 00 00 04 00 00 00 | 90 00 00 00 04 00 00 00 | 74 00 00 00 04 00 00 00 | E8 00 00 00 04 00 00 00 |
    // | A0 00 00 00 04 00 00 00 | E4 00 00 00 04 00 00 00 | D9 00 00 00 04 00 00 00 | 82 00 00 00 04 00 00 00 |
    //
    // Every array item is 8 bytes.
    //   At item[0] is the potential RC4 table value.
    //   At item[4] is always 4.
    //   Every other item should be 0.
    //
    // Windows memory is aligned by 4 bytes, but the array is aligned by 8 bytes.
    // If we step by 8 bytes, we can miss the table when it is not aligned correctly.
    if (hotelType == HotelType.SHOCKWAVE) {
        try checkMapOffset(4, buffer, map.base, map.size);
    }
}

fn checkMapOffset(startingIndex: usize, buffer: []u8, bufferAddr: u64, bufferLen: u64) !void {
    const tableAlignment = hotelSettings.tableAlignment;

    var validEntries: i64 = 0;
    var valueToIndex: [RC4_TABLE_SIZE]u16 = [_]u16{RC4_INVALID_VALUE} ** RC4_TABLE_SIZE;
    var indexToValue: [RC4_TABLE_SIZE]u16 = [_]u16{RC4_INVALID_VALUE} ** RC4_TABLE_SIZE;

    var i = startingIndex;

    while (i < bufferLen) : (i += tableAlignment) {
        const value = buffer[i];
        const tableIndex: u16 = @intCast((i / tableAlignment) % RC4_TABLE_SIZE);

        // Clear information about old value.
        const oldValue = indexToValue[tableIndex];
        if (oldValue != RC4_INVALID_VALUE) {
            valueToIndex[oldValue] = RC4_INVALID_VALUE;
            indexToValue[tableIndex] = RC4_INVALID_VALUE;
            validEntries -= 1;
        }

        // Check if value is unique.
        const isValueUnique = valueToIndex[value] == RC4_INVALID_VALUE;
        if (isValueUnique) {
            validEntries += 1;
        } else {
            // Value already exists, RC4 tables should not have duplicate values.
            // Clear the old indexToValue entry, so that the new one becomes unique.
            indexToValue[valueToIndex[value]] = RC4_INVALID_VALUE;
        }

        valueToIndex[value] = tableIndex;
        indexToValue[tableIndex] = value;

        // Check if we have found 256 unique values in a row.
        if (validEntries == RC4_TABLE_SIZE) {
            const tablePos: usize = i - ((RC4_TABLE_SIZE - 1) * tableAlignment);
            const tableAddr = bufferAddr + tablePos;
            const tableSize = RC4_TABLE_SIZE * tableAlignment;

            try checkValid(tableAddr, buffer[tablePos .. tablePos + tableSize]);
        }
    }
}

// Checks whether the found match is a valid RC4 table.
fn checkValid(address: u64, buffer: []u8) !void {
    const tableAlignment = hotelSettings.tableAlignment;
    const invalidMask = hotelSettings.invalidMask;

    var table: [256]u8 = undefined;
    var i: u32 = 0;

    while (i < buffer.len) : (i += tableAlignment) {
        const value = std.mem.readInt(u64, @ptrCast(buffer[i .. i + tableAlignment]), std.builtin.Endian.little);
        const isValid = (value & invalidMask) == 0;

        if (!isValid) {
            return;
        }

        table[@intCast(i / tableAlignment)] = @intCast(value & 0xFF);
    }

    std.debug.print("Found potential RC4 table at: 0x{x:0>8}\n", .{address});

    // Get table as hexstring.
    var hexString: [512]u8 = undefined;

    for (table, 0..) |value, out| {
        _ = try std.fmt.bufPrint(hexString[(out * 2)..], "{x:0>2}", .{value});
    }

    var stdout = std.io.getStdOut().writer();
    try stdout.print("{s}\n", .{hexString});
}
