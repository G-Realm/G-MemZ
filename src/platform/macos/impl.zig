const std = @import("std");
const posix = std.posix;
const process = @import("../process.zig");
const allocator = std.heap.page_allocator;
const c = @import("c.zig");

pub fn getProcesses() !std.ArrayList(process.ProcessInformation) {
    std.debug.print("macos getProcesses\n", .{});

    var result = std.ArrayList(process.ProcessInformation).init(allocator);

    const pidDataLen: usize = @intCast(c.proc_listpids(1, 0, null, 0));
    const pidData = try allocator.alloc(u32, pidDataLen / @sizeOf(c_int));
    defer allocator.free(pidData);

    const pidCount: usize = @intCast(c.proc_listpids(1, 0, @ptrCast(pidData), @intCast(pidDataLen)));
    if (pidCount == 0) {
        return error.FailedToListPids;
    }

    var i: u32 = 0;

    while (i < pidCount) : (i += 1) {
        const pid = pidData[i];

        if (pid == 0) {
            continue;
        }

        var buffer: [1024]u8 = undefined;
        const bufferLen: c_int = c.proc_pidpath(@intCast(pid), &buffer, buffer.len);
        if (bufferLen == 0) {
            continue;
        }

        const name = buffer[0..@intCast(bufferLen)];

        try result.append(process.ProcessInformation{
            .pid = pid,
            .name = try allocator.dupe(u8, name),
        });
    }

    std.debug.print("macos out is {any}\n", .{pidCount});
    std.debug.print("macos out is {any}\n", .{pidData});

    return result;
}
