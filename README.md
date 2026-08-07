# metal-zig

A minimal, typesafe Zig wrapper for Apple's Metal framework. This library makes it possible to use Metal from Zig without ever touching Objective‑C directly.

This is NOT a complete Metal wrapper. I just add things as i need them.

## Requirements

- macOS with the Metal and Foundation frameworks
- Zig 0.16.0 or newer
- the full Xcode Metal toolchain (`xcrun --find metal`) 

## Example

```zig
const std = @import("std");
const metalzig = @import("metalzig");

pub fn main() !void {
    var device = try metalzig.Device.systemDefault();
    defer device.deinit();

    var queue = try device.newCommandQueue();
    defer queue.deinit();

    const source =
        \\kernel void add_one(
        \\    device const uint* input [[buffer(0)]],
        \\    device uint* output [[buffer(1)]],
        \\    uint index [[thread_position_in_grid]])
        \\{
        \\    output[index] = input[index] + 1;
        \\}
    ;

    var diagnostics = metalzig.ErrorInfo.init();
    defer diagnostics.deinit();

    var library = device.newLibraryWithSourceDetailed(source, &diagnostics) catch |err| {
        std.debug.print("Metal compiler error: {s}\n", .{diagnostics.message()});
        return err;
    };
    defer library.deinit();

    var function = try library.newFunctionWithName("add_one");
    defer function.deinit();

    var pipeline =
        try device.newComputePipelineStateWithFunctionDetailed(&function, &diagnostics);
    defer pipeline.deinit();

    const element_count = 1024;
    var input =
        try device.newBufferWithLength(element_count * @sizeOf(u32), .{});
    defer input.deinit();
    var output =
        try device.newBufferWithLength(element_count * @sizeOf(u32), .{});
    defer output.deinit();

    const values = try input.contentsAs(u32);
    for (values, 0..) |*value, index| {
        value.* = @intCast(index);
    }

    var command_buffer = try queue.newCommandBuffer();
    defer command_buffer.deinit();
    var encoder = try command_buffer.newComputeCommandEncoder();
    defer encoder.deinit();

    encoder.setComputePipelineState(&pipeline);
    try encoder.setBuffer(&input, 0, 0);
    try encoder.setBuffer(&output, 0, 1);

    const group_width = pipeline.threadExecutionWidth();
    try encoder.dispatchThreads(
        .oneDimensional(element_count),
        .oneDimensional(group_width),
    );
    try encoder.endEncoding();

    try command_buffer.commit();
    command_buffer.waitUntilCompletedDetailed(&diagnostics) catch |err| {
        std.debug.print("Metal execution error: {s}\n", .{diagnostics.message()});
        return err;
    };
}
```
