const std = @import("std");
const windows = std.os.windows;
const winapi = @import("./winapi.zig");
const process = @import("../process.zig");
const allocator = std.heap.page_allocator;

pub fn getProcesses() !std.ArrayList(process.ProcessInformation) {
    var result = std.ArrayList(process.ProcessInformation).init(allocator);
    var windowMap = std.AutoHashMap(u64, []u8).init(allocator);
    defer windowMap.deinit();

    try fillWindowMap(&windowMap);

    var processes = [_]u32{0} ** 1024;
    var needed: u32 = 0;

    if (winapi.K32EnumProcesses(&processes, 4096, &needed) == 0) {
        return error.FailedToEnumProcesses;
    }

    for (processes) |pid| {
        if (pid == 0) {
            continue;
        }

        const handle = winapi.OpenProcess(winapi.PROCESS_QUERY_LIMITED_INFORMATION, 0, pid);
        if (handle == winapi.INVALID_HANDLE_VALUE) {
            continue;
        }
        defer _ = winapi.CloseHandle(handle);

        var buffer: [1024]u8 = undefined;
        var bufferLen: u32 = buffer.len;

        if (winapi.QueryFullProcessImageNameA(handle, 0, &buffer, &bufferLen) == 0) {
            continue;
        }

        const name = buffer[0..bufferLen];

        try result.append(process.ProcessInformation{
            .pid = pid,
            .path = try allocator.dupe(u8, name),
            .name = null,
            .windowName = windowMap.get(pid),
        });
    }

    return result;
}

pub fn openProcess(processId: u32) !u32 {
    // Open handle to process.
    const handle = winapi.OpenProcess(winapi.PROCESS_QUERY_INFORMATION | winapi.PROCESS_VM_READ | winapi.PROCESS_VM_OPERATION, 0, processId);
    if (handle == winapi.INVALID_HANDLE_VALUE) {
        return error.FailedToOpenHandle;
    }

    const handleId: u32 = @intCast(@intFromPtr(handle));
    return handleId;
}

pub fn closeProcess(handleId: u32) void {
    const handle = @as(windows.HANDLE, @ptrFromInt(handleId));
    _ = winapi.CloseHandle(handle);
}

pub fn getMemoryMaps(handleId: u32) !std.ArrayList(process.MemoryMap) {
    const handle = @as(windows.HANDLE, @ptrFromInt(handleId));

    // Get system memory information.
    var systemInfo: windows.SYSTEM_INFO = undefined;

    winapi.GetSystemInfo(&systemInfo);

    // Find all memory regions.
    var result = std.ArrayList(process.MemoryMap).init(allocator);
    var addrCurrent = @intFromPtr(systemInfo.lpMinimumApplicationAddress);
    const addrEnd: u64 = @intFromPtr(systemInfo.lpMaximumApplicationAddress);

    while (addrCurrent < addrEnd) {
        var info: windows.MEMORY_BASIC_INFORMATION = undefined;

        if (winapi.VirtualQueryEx(handle, @ptrFromInt(addrCurrent), &info, @sizeOf(windows.MEMORY_BASIC_INFORMATION)) == 0) {
            return error.FailedToQueryMemory;
        }

        // TODO: Stricter filter.
        if (info.State == winapi.MEM_COMMIT and
            info.Type == winapi.MEM_PRIVATE and
            (info.Protect & winapi.PAGE_GUARD) == 0 and
            (info.Protect & winapi.PAGE_NOACCESS) == 0 and
            (info.Protect & winapi.PAGE_READWRITE) == winapi.PAGE_READWRITE)
        {
            // std.log.debug("Found page at {x} to {} {x}", .{ @intFromPtr(info.BaseAddress), info.RegionSize, info.Protect });

            try result.append(process.MemoryMap{
                .base = @intFromPtr(info.BaseAddress),
                .size = info.RegionSize,
            });
        }

        addrCurrent += info.RegionSize;
    }

    return result;
}

pub fn readMemory(handleId: u32, address: usize, size: usize, dest: [*]u8) !void {
    const handle = @as(windows.HANDLE, @ptrFromInt(handleId));
    var bytesRead: usize = 0;

    if (winapi.ReadProcessMemory(handle, @ptrFromInt(address), dest, size, &bytesRead) == 0) {
        return error.MemoryReadFailed;
    }

    if (bytesRead != size) {
        return error.MemoryReadIncomplete;
    }
}

fn fillWindowMap(windowMap: *std.AutoHashMap(u64, []u8)) !void {
    if (winapi.EnumWindows(handleWindow, @intFromPtr(windowMap)) == 0) {
        return error.FailedToEnumWindows;
    }
}

fn handleWindow(windowHandle: windows.HWND, param: usize) callconv(.C) bool {
    const windowMap = @as(*std.AutoHashMap(u64, []u8), @ptrFromInt(param));

    var processId: windows.DWORD = 0;

    if (winapi.GetWindowThreadProcessId(windowHandle, &processId) == 0) {
        return true;
    }

    if (windowMap.contains(processId)) {
        return true;
    }

    // Check if main window.
    // 4 = GW_OWNER
    const windowOwner: usize = @intFromPtr(winapi.GetWindow(windowHandle, 4));
    if (windowOwner != 0) {
        return true;
    }

    var lpString: [1024]u8 = undefined;
    const lpStringLen = winapi.GetWindowTextA(windowHandle, @ptrCast(&lpString), @sizeOf(@TypeOf(lpString)));
    if (lpStringLen == 0) {
        return true;
    }

    const windowTitle = lpString[0..@intCast(lpStringLen)];
    const windowTitleCopy = allocator.dupe(u8, windowTitle) catch return true;

    windowMap.put(processId, windowTitleCopy) catch return true;

    return true;
}
