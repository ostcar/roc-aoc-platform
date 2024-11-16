const std = @import("std");
const str = @import("roc/str.zig");
const list = @import("roc/list.zig");
const clap = @import("clap");

const Part = enum(c_int) {
    part1,
    part2,
};

extern fn roc__solutionForHost_1_exposed_generic(*list.RocList, Part) void;

var allocator: std.mem.Allocator = undefined;
var skip_deallocate = false;

const Options = struct {
    part1: bool,
    part2: bool,
    skip_deallocate: bool,
    memory: usize,
};

pub fn main() void {
    const stdout = std.io.getStdOut().writer();

    const options = parseOptions() catch |err| switch (err) {
        error.Exit => return,
        else => @panic("parse options"),
    };

    const buffer = std.heap.page_allocator.alloc(u8, options.memory) catch @panic("OOM");
    var fba = std.heap.FixedBufferAllocator.init(buffer);
    allocator = fba.allocator();
    skip_deallocate = options.skip_deallocate;

    var result = list.RocList.empty();
    var timer = std.time.Timer.start() catch unreachable;

    if (options.part1) {
        roc__solutionForHost_1_exposed_generic(&result, Part.part1);
        const took1 = std.fmt.fmtDuration(timer.read());
        stdout.print("Part1 in {}, used {} of memory:\n{s}\n\n", .{ took1, std.fmt.fmtIntSizeDec(fba.end_index), rocListAsSlice(result) }) catch unreachable;

        fba.reset();
        timer.reset();
    }

    if (options.part2) {
        roc__solutionForHost_1_exposed_generic(&result, Part.part2);
        const took2 = std.fmt.fmtDuration(timer.read());
        stdout.print("Part2 in {}, used {} of memory:\n{s}\n", .{ took2, std.fmt.fmtIntSizeDec(fba.end_index), rocListAsSlice(result) }) catch unreachable;
    }
}

fn rocListAsSlice(rocList: list.RocList) []const u8 {
    if (rocList.bytes) |bytes| {
        return bytes[0..rocList.len()];
    }
    return "";
}

fn parseOptions() !Options {
    const default_memory_size = 2 << 30;
    const params = comptime clap.parseParamsComptime(
        \\-h, --help            Display this help and exit.
        \\-p, --part1           Run part1.
        \\-q, --part2           Run part2.
        \\-m, --memory <usize>  Amount of memory to use in byte. Default is 1 GiB.
        \\-d, --skip-deallocate Deactivate deallocations. Uses less memory. Can sometime be a bit faster.
        \\
    );

    var buffer: [0]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    allocator = fba.allocator();

    var res = try clap.parse(clap.Help, &params, clap.parsers.default, .{ .allocator = allocator });
    defer res.deinit();

    if (res.args.help != 0) {
        try clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
        return error.Exit;
    }

    const both = res.args.part1 == 0 and res.args.part2 == 0;

    return Options{
        .part1 = res.args.part1 != 0 or both,
        .part2 = res.args.part2 != 0 or both,
        .skip_deallocate = res.args.@"skip-deallocate" != 0,
        .memory = res.args.memory orelse default_memory_size,
    };
}

// Roc memory stuff
export fn roc_alloc(size: usize, alignment: u32) [*]u8 {
    if (skip_deallocate)
        return alloc_without_len(size, alignment)
    else
        return alloc_with_len(size, alignment);
}

fn alloc_with_len(size: usize, alignment: u32) [*]u8 {
    const zig_alignment: u32 = if (alignment <= 8) 8 else 16;
    const size_with_len = size + zig_alignment;
    const ptr = alloc_without_len(size_with_len, alignment);
    const as_usize: [*]usize = @ptrCast(@alignCast(ptr));
    as_usize[0] = size;
    return ptr + zig_alignment;
}

fn alloc_without_len(size: usize, alignment: u32) [*]u8 {
    const v = if (alignment <= 8)
        allocator.alignedAlloc(u8, 8, size)
    else
        allocator.alignedAlloc(u8, 16, size);

    if (v) |s| {
        return s.ptr;
    } else |_| {
        std.debug.panic("roc_alloc: OOM", .{});
    }
}

export fn roc_realloc(ptr: [*]u8, new_size: usize, old_size: usize, alignment: u32) [*]u8 {
    const zig_alignment: u32 = if (alignment <= 8) 8 else 16;
    const slice = if (skip_deallocate) ptr[0..old_size] else (ptr - zig_alignment)[0 .. old_size + zig_alignment];
    const real_new_size = if (skip_deallocate) new_size else new_size + zig_alignment;

    if (allocator.resize(slice, real_new_size)) {
        if (!skip_deallocate) {
            const size_pointer: [*]usize = @ptrCast(@alignCast(ptr - zig_alignment));
            size_pointer[0] = new_size;
        }
        return ptr;
    }

    const new_ptr = roc_alloc(new_size, alignment);
    const copy_size = @min(old_size, new_size);
    @memcpy(new_ptr[0..copy_size], ptr[0..copy_size]);

    roc_dealloc(ptr, alignment);
    return new_ptr;
}

export fn roc_dealloc(ptr: [*]u8, alignment: u32) void {
    if (skip_deallocate) return;

    const zig_alignment: u32 = if (alignment <= 8) 8 else 16;
    const size_pointer: [*]usize = @ptrCast(@alignCast(ptr - zig_alignment));
    const size = size_pointer[0];
    const real_size = size + zig_alignment;
    allocator.free(@as([*]u8, @ptrCast(size_pointer))[0..real_size]);
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

export fn roc_memset(dst: [*]u8, value: i32, size: usize) void {
    @memset(dst[0..size], @intCast(value));
}

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
