const std = @import("std");
const clap = @import("clap");

const str = @import("roc/str.zig");
const list = @import("roc/list.zig");
const RocResultStr = @import("RocResult.zig").RocResult(str.RocStr, str.RocStr);

const RocAllocator = @import("RocAllocator.zig");

extern fn roc__part1ForHost_1_exposed_generic(*RocResultStr, *const str.RocStr) callconv(.C) void;
extern fn roc__part2ForHost_1_exposed_generic(*RocResultStr, *const str.RocStr) callconv(.C) void;

const input_buffer_size = 1 << 20;

var roc_allocator: RocAllocator = undefined;
var startup_memory: usize = undefined;

const Options = struct {
    part1: bool,
    part2: bool,
    skip_deallocate: bool,
    memory: usize,
    puzzle_input: []const u8,
};

pub fn main() void {
    var input_buffer: [input_buffer_size]u8 = undefined;
    const options_or_exit = parseOptions(&input_buffer) catch |err| std.debug.panic("parsing options: {any}", .{err});

    const options = switch (options_or_exit) {
        OptionsOrExit.fileNotFound => |file_name| {
            const stderr = std.io.getStdErr().writer();
            stderr.print(fileNotFoundMessage, .{file_name}) catch unreachable;
            return;
        },
        OptionsOrExit.exit => return,
        OptionsOrExit.options => |options| options,
    };

    startup_memory = options.memory;

    roc_allocator = RocAllocator{ .allocator = std.heap.c_allocator, .skip_deallocate = options.skip_deallocate };

    if (options.part1) {
        runPart("part1", roc__part1ForHost_1_exposed_generic, options);
    }

    if (options.part2) {
        runPart("part2", roc__part2ForHost_1_exposed_generic, options);
    }
}

const fileNotFoundMessage =
    \\ I can not find the input file. I was looking for it at `{s}`.
    \\
    \\ You can specify an input file by providing the filename as an argument. For example:
    \\
    \\ $ roc my_day.roc -- input_file.txt
    \\
    \\ or
    \\
    \\ $ roc build my_day.roc
    \\ $ ./my_day input_file.txt
    \\
    \\ When you use `-` as filename, then I read the content from stdin.
    \\
    \\ When no filename is speficied, I am looking for an input file next to the Roc file, but with the file-extension `.input`.
    \\
;

fn runPart(name: []const u8, func: fn (*RocResultStr, *const str.RocStr) callconv(.C) void, options: Options) void {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    const aoc_input = str.RocStr.fromSlice(options.puzzle_input);
    var result: RocResultStr = undefined;

    var timer = std.time.Timer.start() catch unreachable;
    func(&result, &aoc_input);

    const took = std.fmt.fmtDuration(timer.read());
    if (result.isOk()) {
        stdout.print(
            "{s} in {}:\n{s}\n\n",
            .{
                name,
                took,
                result.payload.ok.asSlice(),
            },
        ) catch unreachable;
    } else {
        stderr.print(
            "{s} failed with: {s}\n\n",
            .{
                name,
                result.payload.err.asSlice(),
            },
        ) catch unreachable;
    }
}

const OptionsOrExit = union(enum) {
    options: Options,
    fileNotFound: []const u8,
    exit,
};

fn parseOptions(buffer: []u8) !OptionsOrExit {
    const default_memory_size = 1 << 30;
    const params = comptime clap.parseParamsComptime(
        \\-h, --help            Display this help and exit.
        \\-p, --part1           Run part1.
        \\-q, --part2           Run part2.
        \\-m, --memory <usize>  Amount of memory to use in byte. Default is 1 GiB.
        \\-d, --skip-deallocate Deactivate deallocations. Uses less memory. Can sometime be a bit faster.
        \\<str>                 Input file. `-` for stdin. The default is a `.input` file next to the roc script.
        \\
    );

    var file_name_buffer: [255]u8 = undefined; // This is for the optional input file name.
    var fba = std.heap.FixedBufferAllocator.init(&file_name_buffer);
    const allocator = fba.allocator();

    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{ .allocator = allocator }) catch {
        try clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
        return OptionsOrExit.exit;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        try clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
        return OptionsOrExit.exit;
    }

    const both_parts = res.args.part1 == 0 and res.args.part2 == 0;

    const file_name: ?[]const u8 = if (res.positionals.len > 0)
        if (std.mem.eql(u8, res.positionals[0], "-"))
            null
        else
            res.positionals[0]
    else blk: {
        const command = res.exe_arg orelse unreachable;
        var buf: [255]u8 = undefined; // This is for the command name + .input
        const size = inputExtension(command, &buf);
        break :blk buf[0..size];
    };

    const content_or_error = try readInput(file_name, buffer);
    const content = switch (content_or_error) {
        ContentOrFileNotFound.fileNotFound => |f| return OptionsOrExit{ .fileNotFound = f },
        ContentOrFileNotFound.content => |content| content,
    };

    return OptionsOrExit{ .options = Options{
        .part1 = res.args.part1 != 0 or both_parts,
        .part2 = res.args.part2 != 0 or both_parts,
        .skip_deallocate = res.args.@"skip-deallocate" != 0,
        .memory = res.args.memory orelse default_memory_size,
        .puzzle_input = content,
    } };
}

fn inputExtension(orig_path: []const u8, buffer: []u8) usize {
    const new_extension = ".input";
    const extension = std.fs.path.extension(orig_path);
    const clean_len = orig_path.len - extension.len;
    @memcpy(buffer[0..clean_len], orig_path[0..clean_len]);
    @memcpy(buffer[clean_len..][0..new_extension.len], new_extension);
    return clean_len + new_extension.len;
}

const ContentOrFileNotFound = union(enum) {
    content: []const u8,
    fileNotFound: []const u8,
};

fn readInput(may_file_name: ?[]const u8, buffer: []u8) !ContentOrFileNotFound {
    var content = if (may_file_name) |file_name| blk: {
        break :blk std.fs.cwd().readFile(file_name, buffer) catch |err|
            return switch (err) {
            error.FileNotFound => ContentOrFileNotFound{ .fileNotFound = file_name },
            else => err,
        };
    } else blk: {
        const size = try std.io.getStdIn().readAll(buffer);
        break :blk buffer[0..size];
    };

    if (content[content.len - 1] == '\n') {
        content = content[0 .. content.len - 1];
    }

    return ContentOrFileNotFound{ .content = content };
}

// Roc memory stuff
export fn roc_alloc(size: usize, alignment: u32) [*]u8 {
    return roc_allocator.alloc(size, alignment) catch printOOMError();
}

export fn roc_realloc(ptr: [*]u8, new_size: usize, old_size: usize, alignment: u32) [*]u8 {
    return roc_allocator.realloc(ptr, new_size, old_size, alignment) catch printOOMError();
}

fn printOOMError() noreturn {
    const stderr = std.io.getStdErr().writer();
    stderr.print(
        \\ Out of Memory.
        \\
    ,
        .{},
    ) catch unreachable;
    std.process.exit(1);
}

export fn roc_dealloc(ptr: [*]u8, alignment: u32) void {
    roc_allocator.dealloc(ptr, alignment);
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
