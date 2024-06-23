const std = @import("std");
const builtin = @import("builtin");
const windows = @import("./windows/impl.zig");

pub const P_HANDLE = u32;

pub const ProcessInformation = struct {
    pid: u32,
    name: []u8,
};

pub const MemoryMap = struct {
    base: u64,
    size: u64,
};

pub fn getProcesses() !std.ArrayList(ProcessInformation) {
    if (builtin.os.tag == .windows) {
        return windows.getProcesses();
    }

    return error.UnsupportedPlatform;
}

pub fn openProcess(processId: u32) !P_HANDLE {
    if (builtin.os.tag == .windows) {
        return windows.openProcess(processId);
    }

    return error.UnsupportedPlatform;
}

pub fn closeProcess(handleId: P_HANDLE) void {
    if (builtin.os.tag == .windows) {
        windows.closeProcess(handleId);
    }
}

pub fn getMemoryMaps(processId: u32) !std.ArrayList(MemoryMap) {
    if (builtin.os.tag == .windows) {
        return windows.getMemoryMaps(processId);
    }

    return error.UnsupportedPlatform;
}

pub fn readMemory(handleId: P_HANDLE, address: u64, size: u64, dest: [*]u8) !void {
    if (builtin.os.tag == .windows) {
        return windows.readMemory(handleId, address, size, dest);
    }

    return error.UnsupportedPlatform;
}
