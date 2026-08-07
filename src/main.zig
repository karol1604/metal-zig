const std = @import("std");
const metalzig = @import("metalzig");

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    var devices = try metalzig.Device.copyAllDevices(alloc);
    defer devices.deinit();

    for (devices.items, 0..) |*available_device, i| {
        const name = try available_device.name(alloc);
        defer alloc.free(name);
        std.debug.print("Device {d}: {s}\n", .{ i, name });
    }
    var device = try metalzig.Device.systemDefault();
    // var device = devices[0];
    defer device.deinit();

    var q = try device.newCommandQueue();
    defer q.deinit();
    //
    // // const lib_data = @embedFile("add_arrays.metallib");
    //
    // var lib = try device.newLibraryWithFile("build-artifacts/add_arrays.metallib");
    // // var lib = try device.newLibraryWithData(std.mem.sliceAsBytes(lib_data));
    const source =
        \\kernel void add_arrays(
        \\               device const uint* inA [[buffer(0)]],
        \\               device const uint* inB [[buffer(1)]],
        \\               constant uint& offset [[buffer(2)]],
        \\               device uint* result [[buffer(3)]],
        \\               uint index [[thread_position_in_grid]])
        \\{
        \\    result[index] = inA[index] + inB[index] + offset;
        \\}
    ;
    var diagnostics = metalzig.ErrorInfo.init();
    defer diagnostics.deinit();
    var lib = device.newLibraryWithSourceDetailed(source, &diagnostics) catch |err| {
        std.debug.print("Metal library error: {s}\n", .{diagnostics.message()});
        return err;
    };

    defer lib.deinit();

    var func = try lib.newFunctionWithName("add_arrays");
    defer func.deinit();

    var pipeline = try device.newComputePipelineStateWithFunction(&func);
    defer pipeline.deinit();

    const input_len = 10_000_000;
    const output_len = input_len;

    var a_buf = try device.newBufferWithLength(input_len * @sizeOf(u32), .{});
    defer a_buf.deinit();
    var b_buf = try device.newBufferWithLength(input_len * @sizeOf(u32), .{});
    defer b_buf.deinit();

    const a_slice = try a_buf.contentsAs(u32);
    const b_slice = try b_buf.contentsAs(u32);

    var output_buffer = try device.newBufferWithLength(output_len * @sizeOf(u32), .{});
    defer output_buffer.deinit();

    for (a_slice, 0..input_len, b_slice) |*a_val, i, *b_val| {
        a_val.* = @intCast(i);
        b_val.* = @intCast(input_len - i);
    }
    std.debug.print("b_slice[100] = {d}\n", .{b_slice[100]});

    var command_buffer = try q.newCommandBuffer();
    defer command_buffer.deinit();

    var encoder = try command_buffer.newComputeCommandEncoder();
    defer encoder.deinit();

    encoder.setComputePipelineState(&pipeline);

    const offset: u32 = 69;
    try encoder.setBuffer(&a_buf, 0, 0);
    try encoder.setBuffer(&b_buf, 0, 1);
    try encoder.setBytes(std.mem.asBytes(&offset), 2);
    try encoder.setBuffer(&output_buffer, 0, 3);

    try encoder.dispatchThreads(
        .oneDimensional(input_len),
        .oneDimensional(pipeline.threadExecutionWidth()),
    );
    try encoder.endEncoding();

    try command_buffer.commit();
    command_buffer.waitUntilCompletedDetailed(&diagnostics) catch |err| {
        std.debug.print("Metal command buffer error: {s}\n", .{diagnostics.message()});
        return err;
    };

    const res = try output_buffer.contentsAs(u32);
    std.debug.print("Result: {any}\n", .{res[0]});
}
