const std = @import("std");
const str = @import("roc/str.zig");
const list = @import("roc/list.zig");

const Part = enum(c_int) {
    part1,
    part2,
};

extern fn roc__solutionForHost_1_exposed_generic(*list.RocList, Part) void;

const default_memory_size = 2 << 30;
var allocator: std.mem.Allocator = undefined;
var used_memory: usize = 0;

pub fn main() u8 {
    const stdout = std.io.getStdOut().writer();

    const buffer = std.heap.page_allocator.alloc(u8, default_memory_size) catch @panic("OOM");
    var fba = std.heap.FixedBufferAllocator.init(buffer);
    allocator = fba.allocator();

    var result = list.RocList.empty();
    var timer = std.time.Timer.start() catch unreachable;
    roc__solutionForHost_1_exposed_generic(&result, Part.part1);
    const took1 = std.fmt.fmtDuration(timer.read());

    stdout.print("Part1 in {}, used {} bytes:\n{s}\n\n", .{ took1, used_memory, rocListAsSlice(result) }) catch unreachable;

    fba.reset();
    used_memory = 0;

    timer.reset();
    roc__solutionForHost_1_exposed_generic(&result, Part.part2);
    const took2 = std.fmt.fmtDuration(timer.read());

    stdout.print("Part2 in {}, used {} bytes:\n{s}\n", .{ took2, used_memory, rocListAsSlice(result) }) catch unreachable;
    return 0;
}

fn rocListAsSlice(rocList: list.RocList) []const u8 {
    if (rocList.bytes) |bytes| {
        return bytes[0..rocList.len()];
    }
    return "";
}

// Roc memory stuff
extern fn memcpy(dst: [*]u8, src: [*]u8, size: usize) callconv(.C) void;
extern fn memset(dst: [*]u8, value: i32, size: usize) callconv(.C) void;

const bitsize = @sizeOf(usize);

export fn roc_alloc(size: usize, alignment: u32) [*]u8 {
    _ = alignment;
    const mem = allocator.alloc(u8, size) catch @panic("roc_alloc: OOM");
    used_memory += size;
    return mem.ptr;
}

export fn roc_realloc(ptr: [*]u8, new_size: usize, old_size: usize, alignment: u32) [*]u8 {
    if (allocator.resize(ptr[0..old_size], new_size)) {
        used_memory += new_size - old_size;
        return ptr;
    }

    roc_dealloc(ptr, alignment);
    return roc_alloc(new_size, alignment);
}

export fn roc_dealloc(ptr: [*]u8, alignment: u32) void {
    _ = ptr;
    _ = alignment;
    // TODO: Optional dealloc
}

export fn roc_panic(msg: *str.RocStr, tag_id: u32) callconv(.C) void {
    const stderr = std.io.getStdErr().writer();
    switch (tag_id) {
        0 => {
            stderr.print("Roc standard library crashed with message\n\n    {s}\n\nShutting down\n", .{msg.asSlice()}) catch unreachable;
        },
        1 => {
            stderr.print("Application crashed with message\n\n    {s}\n\nShutting down\n", .{msg.asSlice()}) catch unreachable;
        },
        else => unreachable,
    }
    std.process.exit(1);
}

export fn roc_dbg(loc: *str.RocStr, msg: *str.RocStr, src: *str.RocStr) callconv(.C) void {
    const stderr = std.io.getStdErr().writer();
    stderr.print("[{s}] {s} = {s}\n", .{ loc.asSlice(), src.asSlice(), msg.asSlice() }) catch unreachable;
}

export fn roc_memset(dst: [*]u8, value: i32, size: usize) callconv(.C) void {
    return memset(dst, value, size);
}

extern fn kill(pid: c_int, sig: c_int) c_int;
extern fn shm_open(name: *const i8, oflag: c_int, mode: c_uint) c_int;
extern fn mmap(addr: ?*anyopaque, length: c_uint, prot: c_int, flags: c_int, fd: c_int, offset: c_uint) *anyopaque;
extern fn getppid() c_int;

fn roc_getppid() callconv(.C) c_int {
    return getppid();
}

fn roc_shm_open(name: *const i8, oflag: c_int, mode: c_uint) callconv(.C) c_int {
    return shm_open(name, oflag, mode);
}
fn roc_mmap(addr: ?*anyopaque, length: c_uint, prot: c_int, flags: c_int, fd: c_int, offset: c_uint) callconv(.C) *anyopaque {
    return mmap(addr, length, prot, flags, fd, offset);
}

comptime {
    @export(roc_getppid, .{ .name = "roc_getppid", .linkage = .strong });
    @export(roc_mmap, .{ .name = "roc_mmap", .linkage = .strong });
    @export(roc_shm_open, .{ .name = "roc_shm_open", .linkage = .strong });
}
