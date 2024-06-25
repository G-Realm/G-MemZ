const std = @import("std");
const posix = std.posix;
const process = @import("../process.zig");
const allocator = std.heap.page_allocator;
const c = @import("darwin.zig");

pub fn getProcesses() !std.ArrayList(process.ProcessInformation) {
    var result = std.ArrayList(process.ProcessInformation).init(allocator);

    const pidBytesLen: usize = @intCast(c.proc_listpids(1, 0, null, 0));
    const pidDataLen = pidBytesLen / @sizeOf(c_int);
    const pidData = try allocator.alloc(c_int, pidDataLen);
    defer allocator.free(pidData);

    const pidsReceived: usize = @intCast(c.proc_listpids(1, 0, @ptrCast(pidData), @intCast(pidBytesLen)));
    if (pidsReceived == 0) {
        return error.FailedToListPids;
    }

    const pidsTotal = pidsReceived / @sizeOf(c_int);
    var i: u32 = 0;

    while (i < pidsTotal) : (i += 1) {
        const pid = pidData[i];
        if (pid == 0) {
            continue;
        }

        var buffer: [1024]u8 = undefined;

        // Read proc path.
        var bufferLen: c_int = c.proc_pidpath(@intCast(pid), &buffer, buffer.len);
        if (bufferLen == 0) {
            continue;
        }

        const path = try allocator.dupe(u8, buffer[0..@intCast(bufferLen)]);

        // Read proc name.
        bufferLen = c.proc_name(@intCast(pid), &buffer, buffer.len);
        if (bufferLen == 0) {
            continue;
        }

        const name = try allocator.dupe(u8, buffer[0..@intCast(bufferLen)]);

        try result.append(process.ProcessInformation{
            .pid = @intCast(pid),
            .path = try allocator.dupe(u8, path),
            .name = name,
        });
    }

    return result;
}

pub fn openProcess(processId: u32) !u32 {
    var task: c_uint = 0;

    // TODO: Probably needs root.
    // https://os-tres.net/blog/2010/02/17/mac-os-x-and-task-for-pid-mach-call/
    const kRet = c.task_for_pid(c.mach_task_self(), @intCast(processId), &task);
    if (kRet != 0) {
        return process.PlatformError.FailedTaskForPid;
    }

    return task;
}

pub fn closeProcess(taskId: u32) void {
    _ = c.mach_port_deallocate(c.mach_task_self(), taskId);
}

pub fn getMemoryMaps(taskId: u32) !std.ArrayList(process.MemoryMap) {
    var result = std.ArrayList(process.MemoryMap).init(allocator);

    var address: u64 = 0;
    var size: u64 = 0;
    var info: c.vm_region_basic_info_64 = undefined;
    var infoCnt: c_uint = 9; // VM_REGION_BASIC_INFO_COUNT_64
    var objName: c_uint = 0;

    while (true) : (address += size) {
        const kRet = c.mach_vm_region(taskId, &address, &size, c.VM_REGION_BASIC_INFO_64, @ptrCast(&info), &infoCnt, &objName);
        if (kRet != c.KERN_SUCCESS) {
            if (kRet == c.KERN_INVALID_ADDRESS) {
                break;
            }

            return error.FailedMemoryMap;
        }

        // Check if info.protection is READ and WRITE.
        if ((info.protection & c.VM_PROT_READ) == 0 or (info.protection & c.VM_PROT_WRITE) == 0) {
            continue;
        }

        // std.debug.print("Region {x:0>8}-{x:0>8} Prot {x} Shared {} Reserved {}\n", .{ address, address + size, info.protection, info.shared, info.reserved });

        try result.append(process.MemoryMap{
            .base = address,
            .size = size,
        });
    }

    return result;
}

pub fn readMemory(taskId: u32, address: usize, size: usize, dest: [*]u8) !void {
    var dataRead: u64 = 0;

    const kRet = c.mach_vm_read_overwrite(taskId, address, size, @intFromPtr(dest), &dataRead);
    if (kRet != c.KERN_SUCCESS) {
        return;
    }

    if (dataRead != size) {
        return error.MemoryReadIncomplete;
    }
}
