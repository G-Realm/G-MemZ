const std = @import("std");
const posix = std.posix;
const process = @import("../process.zig");
const allocator = std.heap.page_allocator;
// const c = @import("c.zig");

// pub extern "libc" fn proc_listpids(
//     type: u32,
//     typeInfo: u32,
//     buffer: ?[*]u8,
//     bufferSize: usize,
// ) callconv(std.builtin.CallingConvention.C) void;

pub fn getProcesses() !std.ArrayList(process.ProcessInformation) {
    const result = std.ArrayList(process.ProcessInformation).init(allocator);

    // const dataLen = c.proc_listpids(1, 0, null, 0);

    // var value: [1024]u32 = undefined;
    var len: usize = 0;

    try posix.sysctlbynameZ("kern.proc.all", null, &len, null, 0);

    // const procInfo = allocator.alloc(darwin.kinfo_proc, len);

    std.log.info("len is {}", .{len});

    return result;
}
