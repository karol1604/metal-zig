const std = @import("std");
const metalzig = @import("metalzig");

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    const devices = try metalzig.Device.copyAllDevices(alloc);

    for (devices, 0..) |device, i| {
        std.debug.print("Device {d}: {s}\n", .{ i, device.name() });
    }
    // var device = try metalzig.Device.systemDefault();
    var device = devices[0];
    defer device.deinit();

    var q = try device.newCommandQueue();
    defer q.deinit();

    var lib = try device.newLibraryWithURL("build-artifacts/add_arrays.metallib");
    defer lib.deinit();

    var func = try lib.newFunctionWithName("add_arrays");
    defer func.deinit();

    var pipeline = try device.newComputePipelineStateWithFunction(&func);
    defer pipeline.deinit();

    const input_len = 10_000_000;
    const output_len = input_len;

    var a_buf = try device.newBufferWithLength(input_len * @sizeOf(u32), 0);
    defer a_buf.deinit();
    var b_buf = try device.newBufferWithLength(input_len * @sizeOf(u32), 0);
    defer b_buf.deinit();

    const a_slice = a_buf.getContentsAs(u32) orelse return error.BufferContentsUnavailable;
    const b_slice = b_buf.getContentsAs(u32) orelse return error.BufferContentsUnavailable;

    var output_buffer = try device.newBufferWithLength(output_len * @sizeOf(u32), 0);
    defer output_buffer.deinit();

    for (a_slice, 0..input_len, b_slice) |*a_val, i, *b_val| {
        a_val.* = @intCast(i);
        b_val.* = @intCast(input_len - i);
    }

    var command_buffer = try q.newCommandBuffer();
    defer command_buffer.deinit();

    var encoder = try command_buffer.newComputeCommandEncoder();
    defer encoder.deinit();

    encoder.setComputePipelineState(&pipeline);

    const offset: u32 = 69;
    encoder.setBuffer(&a_buf, 0, 0);
    encoder.setBuffer(&b_buf, 0, 1);
    encoder.setBytes(std.mem.asBytes(&offset), 2);
    encoder.setBuffer(&output_buffer, 0, 3);

    encoder.dispatchThreads(input_len, 1, 1, 1000, 1, 1);
    encoder.endEncoding();

    command_buffer.commit();
    command_buffer.waitUntilCompleted();

    const res = output_buffer.getContentsAs(u32) orelse return error.BufferContentsUnavailable;
    std.debug.print("Result: {any}\n", .{res[0]});
}
