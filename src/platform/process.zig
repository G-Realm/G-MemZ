const std = @import("std");
const builtin = @import("builtin");
const windows = @import("./windows/impl.zig");
const macos = @import("./macos/impl.zig");

pub const P_HANDLE = u32;

pub const ProcessInformation = struct {
    pid: u32,
    name: []u8,
};

pub const MemoryMap = struct {
    base: usize,
    size: usize,
};

pub fn getProcesses() !std.ArrayList(ProcessInformation) {
    if (builtin.os.tag == .windows) {
        return windows.getProcesses();
    }

    if (builtin.os.tag == .macos) {
        return macos.getProcesses();
    }

    return error.UnsupportedPlatform;
}

pub fn openProcess(processId: u32) !P_HANDLE {
    if (builtin.os.tag == .windows) {
        return windows.openProcess(processId);
    }

    if (builtin.os.tag == .macos) {
        return macos.openProcess(processId);
    }

    return error.UnsupportedPlatform;
}

pub fn closeProcess(handleId: P_HANDLE) void {
    if (builtin.os.tag == .windows) {
        windows.closeProcess(handleId);
    } else if (builtin.os.tag == .macos) {
        macos.closeProcess(handleId);
    }
}

pub fn getMemoryMaps(processId: u32) !std.ArrayList(MemoryMap) {
    if (builtin.os.tag == .windows) {
        return windows.getMemoryMaps(processId);
    }

    if (builtin.os.tag == .macos) {
        return macos.getMemoryMaps(processId);
    }

    return error.UnsupportedPlatform;
}

pub fn readMemory(handleId: P_HANDLE, address: usize, size: usize, dest: [*]u8) !void {
    if (builtin.os.tag == .windows) {
        return windows.readMemory(handleId, address, size, dest);
    }

    return error.UnsupportedPlatform;
}
