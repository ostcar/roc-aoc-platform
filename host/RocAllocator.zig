const std = @import("std");

allocator: std.mem.Allocator,
skip_deallocate: bool = false,

const this = @This();

pub fn alloc(self: this, size: usize, alignment: u32) ![*]u8 {
    if (self.skip_deallocate)
        return self.alloc_without_len(size, alignment);

    return self.alloc_with_len(size, alignment);
}

fn alloc_with_len(self: this, size: usize, alignment: u32) ![*]u8 {
    const zig_alignment: u32 = if (alignment <= 8) 8 else 16;
    const size_with_len = size + zig_alignment;
    const ptr = try self.alloc_without_len(size_with_len, zig_alignment);
    const as_usize: [*]usize = @ptrCast(@alignCast(ptr));
    as_usize[0] = size;
    return ptr + zig_alignment;
}

fn alloc_without_len(self: this, size: usize, alignment: u32) ![*]u8 {
    // Only alignment of 8 or 16 are realistic. See
    // https://roc.zulipchat.com/#narrow/channel/302903-platform-development/topic/roc_alloc.20and.20alignment/near/482227735
    const v = if (alignment <= 8)
        try self.allocator.alignedAlloc(u8, 8, size)
    else
        try self.allocator.alignedAlloc(u8, 16, size);

    return v.ptr;
}

pub fn realloc(self: this, ptr: [*]u8, new_size: usize, old_size: usize, alignment: u32) ![*]u8 {
    const zig_alignment: u32 = if (alignment <= 8) 8 else 16;
    const real_new_size = if (self.skip_deallocate) new_size else new_size + zig_alignment;
    const slice = if (self.skip_deallocate) ptr[0..old_size] else (ptr - zig_alignment)[0 .. old_size + zig_alignment];

    const slice_aligned = if (alignment <= 8)
        @as([]align(8) u8, @ptrCast(@alignCast(slice)))
    else
        @as([]align(16) u8, @ptrCast(@alignCast(slice)));

    const new_slice = try self.allocator.realloc(slice_aligned, real_new_size);
    return new_slice.ptr + zig_alignment;
}

pub fn dealloc(self: this, ptr: [*]u8, alignment: u32) void {
    if (self.skip_deallocate) return;

    const zig_alignment: u32 = if (alignment <= 8) 8 else 16;
    const size_pointer: [*]usize = @ptrCast(@alignCast(ptr - zig_alignment));
    const size = size_pointer[0];
    const real_size = size + zig_alignment;

    const slice = if (alignment <= 8)
        @as([*]align(8) u8, @ptrCast(@alignCast(size_pointer)))[0..real_size]
    else
        @as([*]align(16) u8, @ptrCast(@alignCast(size_pointer)))[0..real_size];

    self.allocator.free(slice);
}
