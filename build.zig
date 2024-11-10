const std = @import("std");
const Build = std.Build;
const OptimizeMode = std.builtin.OptimizeMode;
const LazyPath = std.Build.LazyPath;
const Compile = std.Build.Step.Compile;

pub fn build(b: *Build) !void {
    const optimize = b.standardOptimizeOption(.{});

    buildDynhost(b, optimize);
    try buildLegacy(b, optimize);
}

fn buildDynhost(b: *Build, optimize: std.builtin.OptimizeMode) void {
    //const target = b.resolveTargetQuery(.{ .cpu_arch = .x86_64, .os_tag = .linux });
    const target = b.standardTargetOptions(.{});

    // Build libapp.so
    const build_libapp_so = b.addSystemCommand(&.{"roc"});
    build_libapp_so.addArgs(&.{ "build", "--lib" });
    build_libapp_so.addFileArg(b.path("examples/day.roc"));
    build_libapp_so.addArg("--output");
    const libapp_filename = build_libapp_so.addOutputFileArg("libapp.so");

    // Build dynhost
    const dynhost = b.addExecutable(.{
        .name = "dynhost",
        .root_source_file = b.path("host/host.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    dynhost.pie = true;
    dynhost.rdynamic = true;
    dynhost.bundle_compiler_rt = true;
    dynhost.root_module.stack_check = false;
    dynhost.addObjectFile(libapp_filename);

    const clap = b.dependency("clap", .{});
    dynhost.root_module.addImport("clap", clap.module("clap"));

    // Copy dynhost to platform
    const copy_dynhost = b.addWriteFiles();
    copy_dynhost.addCopyFileToSource(dynhost.getEmittedBin(), "platform/dynhost");
    copy_dynhost.step.dependOn(&dynhost.step);

    // Preprocess host
    const preprocess_host = b.addSystemCommand(&.{"roc"});
    preprocess_host.addArg("preprocess-host");
    preprocess_host.addFileArg(dynhost.getEmittedBin());
    preprocess_host.addFileArg(b.path("platform/main.roc"));
    preprocess_host.addFileArg(libapp_filename);
    preprocess_host.step.dependOn(&copy_dynhost.step);

    b.getInstallStep().dependOn(&preprocess_host.step);
}

fn buildLegacy(b: *Build, optimize: std.builtin.OptimizeMode) !void {
    const targets: []const std.Target.Query = &.{
        .{ .cpu_arch = .aarch64, .os_tag = .macos },
        .{ .cpu_arch = .x86_64, .os_tag = .macos },
        .{ .cpu_arch = .aarch64, .os_tag = .linux },
        .{ .cpu_arch = .x86_64, .os_tag = .linux },
    };

    const clap = b.dependency("clap", .{});

    for (targets) |target| {
        const lib = b.addStaticLibrary(.{
            .name = "linux-x86",
            .root_source_file = b.path("host/host.zig"),
            .target = b.resolveTargetQuery(target),
            .optimize = optimize,
            .link_libc = true,
        });

        lib.root_module.stack_check = false;
        lib.pie = true;

        lib.root_module.addImport("clap", clap.module("clap"));

        const os_name = @tagName(target.os_tag.?);
        const cpu_name = switch (target.cpu_arch.?) {
            .aarch64 => "arm64",
            .x86_64 => "x64",
            else => unreachable,
        };

        const name = try std.fmt.allocPrint(b.allocator, "platform/{s}-{s}.o", .{
            os_name,
            cpu_name,
        });

        const copy_legacy = b.addWriteFiles();
        //const copy_legacy = b.addUpdateSourceFiles(); // for zig 0.14
        copy_legacy.addCopyFileToSource(lib.getEmittedBin(), name);
        copy_legacy.step.dependOn(&lib.step);

        b.getInstallStep().dependOn(&copy_legacy.step);
    }
}
