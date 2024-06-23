const std = @import("std");
const windows = std.os.windows;
const maxInt = std.math.maxInt;

const BOOL = windows.BOOL;
const DWORD = windows.DWORD;
const HANDLE = windows.HANDLE;
const LPCVOID = windows.LPCVOID;
const SIZE_T = windows.SIZE_T;
const WINAPI = windows.WINAPI;

pub const INVALID_HANDLE_VALUE = @as(HANDLE, @ptrFromInt(maxInt(usize)));

pub const PROCESS_VM_OPERATION = 0x0008;
pub const PROCESS_VM_READ = 0x0010;
pub const PROCESS_QUERY_INFORMATION = 0x0400;
pub const PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;

pub const MEM_COMMIT = 0x00001000;

pub const MEM_PRIVATE = 0x20000;

pub const PAGE_NOACCESS = 0x01;
pub const PAGE_READONLY = 0x02;
pub const PAGE_READWRITE = 0x04;
pub const PAGE_WRITECOPY = 0x08;
pub const PAGE_EXECUTE = 0x10;
pub const PAGE_EXECUTE_READ = 0x20;
pub const PAGE_EXECUTE_READWRITE = 0x40;
pub const PAGE_EXECUTE_WRITECOPY = 0x80;
pub const PAGE_GUARD = 0x100;
pub const PAGE_NOCACHE = 0x200;
pub const PAGE_WRITECOMBINE = 0x400;

pub extern "kernel32" fn GetLastError() callconv(windows.WINAPI) DWORD;

pub extern "kernel32" fn K32EnumProcesses(
    lpidProcess: [*]DWORD,
    cb: DWORD,
    lpcbNeeded: *DWORD,
) callconv(windows.WINAPI) BOOL;

pub extern "kernel32" fn OpenProcess(
    dwDesiredAccess: DWORD,
    bInheritHandle: BOOL,
    dwProcessId: DWORD,
) callconv(windows.WINAPI) HANDLE;

pub extern "kernel32" fn CloseHandle(
    hObject: HANDLE,
) callconv(windows.WINAPI) BOOL;

pub extern "kernel32" fn QueryFullProcessImageNameA(
    Process: HANDLE,
    dwFlags: DWORD,
    lpExeName: [*]u8,
    lpdwSize: *DWORD,
) callconv(windows.WINAPI) BOOL;

pub extern "kernel32" fn ReadProcessMemory(
    hProcess: HANDLE,
    lpBaseAddress: LPCVOID,
    lpBuffer: [*]u8,
    nSize: SIZE_T,
    lpNumberOfBytesRead: ?*SIZE_T,
) callconv(windows.WINAPI) BOOL;

pub extern "kernel32" fn GetSystemInfo(
    lpSystemInfo: *windows.SYSTEM_INFO,
) callconv(windows.WINAPI) void;

pub extern "kernel32" fn VirtualQueryEx(
    hProcess: HANDLE,
    lpAddress: LPCVOID,
    lpBuffer: *windows.MEMORY_BASIC_INFORMATION,
    dwLength: u32,
) callconv(windows.WINAPI) u32;
