const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    if (target.result.os.tag != .macos) {
        @panic("metal-zig currently supports macOS targets only");
    }
    const optimize = b.standardOptimizeOption(.{});

    const metalzig = b.addModule("metalzig", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    configureMetalModule(b, metalzig);

    const example_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "metalzig", .module = metalzig },
        },
    });
    const example = b.addExecutable(.{
        .name = "metal_zig",
        .root_module = example_module,
    });
    b.installArtifact(example);

    const run_example = b.addRunArtifact(example);
    run_example.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_example.addArgs(args);
    }
    const run_step = b.step("run", "Run the compute example");
    run_step.dependOn(&run_example.step);

    addKernelStep(b);

    // Keep the test build step available for when tests are added.
    const library_tests = b.addTest(.{ .root_module = metalzig });
    const run_library_tests = b.addRunArtifact(library_tests);
    const example_tests = b.addTest(.{ .root_module = example_module });
    const run_example_tests = b.addRunArtifact(example_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_library_tests.step);
    test_step.dependOn(&run_example_tests.step);
}

fn configureMetalModule(b: *std.Build, module: *std.Build.Module) void {
    const sdk_root = b.sysroot orelse std.mem.trim(
        u8,
        b.run(&.{ "xcrun", "--sdk", "macosx", "--show-sdk-path" }),
        &std.ascii.whitespace,
    );
    module.addSystemFrameworkPath(.{
        .cwd_relative = b.pathJoin(&.{ sdk_root, "System/Library/Frameworks" }),
    });
    module.addCSourceFile(.{
        .file = b.path("src/c-shim/metal_shim.m"),
        .flags = &.{"-fobjc-arc"},
    });
    module.addIncludePath(b.path("src/c-shim"));
    module.linkFramework("Metal", .{});
    module.linkFramework("Foundation", .{});
    module.linkFramework("QuartzCore", .{});
}

fn addKernelStep(b: *std.Build) void {
    const compile_air = b.addSystemCommand(&.{
        "xcrun",
        "-sdk",
        "macosx",
        "metal",
        "-c",
    });
    compile_air.addFileArg(b.path("kernels/add_arrays.metal"));
    compile_air.addArg("-o");
    const air = compile_air.addOutputFileArg("add_arrays.air");

    const link_library = b.addSystemCommand(&.{
        "xcrun",
        "-sdk",
        "macosx",
        "metallib",
    });
    link_library.addFileArg(air);
    link_library.addArg("-o");
    const metallib = link_library.addOutputFileArg("add_arrays.metallib");

    const install_metallib = b.addInstallFile(metallib, "lib/add_arrays.metallib");
    const kernels_step = b.step("kernels", "Compile and install Metal kernels");
    kernels_step.dependOn(&install_metallib.step);
}
