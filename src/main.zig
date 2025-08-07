const std = @import("std");
const c = @cImport({
    @cInclude("metal_shim.h");
});

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    const device = c.mtl_create_system_default_device();
    defer c.mtl_release_device(device);

    const q = c.mtl_new_command_queue(device);
    defer c.mtl_release_command_queue(q);

    const lib = c.mtl_new_library_with_url(device, "test.metallib");
    defer c.mtl_release_library(lib);

    const func = c.mtl_new_function_with_name(lib, "add_arrays");
    defer c.mtl_release_function(func);

    const pipeline = c.mtl_new_compute_pipeline_state_with_function(device, func);
    defer c.mtl_release_compute_pipeline_state(pipeline);

    const input_len = 1000;
    const a_buf = c.mtl_new_buffer_with_length(device, input_len * @sizeOf(f32), 0);
    defer c.mtl_release_buffer(a_buf);
    const b_buf = c.mtl_new_buffer_with_length(device, input_len * @sizeOf(f32), 0);
    defer c.mtl_release_buffer(b_buf);

    const a_ptr: [*]f32 = @ptrCast(@alignCast(c.mtl_buffer_get_contents(a_buf)));
    const b_ptr: [*]f32 = @ptrCast(@alignCast(c.mtl_buffer_get_contents(b_buf)));

    const output_len = 1000;
    const output_buffer = c.mtl_new_buffer_with_length(device, output_len * @sizeOf(f32), 0);
    defer c.mtl_release_buffer(output_buffer);
    // const output_slice = output_buffer[0..output_len];

    for (a_ptr, 0..input_len, b_ptr) |*a_val, i, *b_val| {
        a_val.* = @floatFromInt(i);
        b_val.* = @floatFromInt(input_len - i);
    }

    const command_buffer = c.mtl_new_command_buffer(q);
    defer c.mtl_release_command_buffer(command_buffer);

    const encoder = c.mtl_new_compute_command_encoder(command_buffer);
    defer c.mtl_release_compute_command_encoder(encoder);

    c.mtl_enc_set_compute_pipeline_state(encoder, pipeline);

    c.mtl_enc_set_buffer(encoder, a_buf, 0, 0);
    c.mtl_enc_set_buffer(encoder, b_buf, 0, 1);
    c.mtl_enc_set_buffer(encoder, output_buffer, 0, 2);

    c.mtl_enc_dispatch_threads(encoder, input_len, 1, 1, 1000, 1, 1);
    c.mtl_end_encoding(encoder);
    //
    c.mtl_command_buffer_commit(command_buffer);
    c.mtl_command_buffer_wait_until_completed(command_buffer);

    // std.debug.print("Device: {any}= Q: {any}, lib: {any}, func: {any}, pipeline: {any}, a_buf: {any}, b_buf: {any}, out_buf: {any}, command_buf: {any}, encoder: {any}\n", .{
    //     device,
    //     q,
    //     lib,
    //     func,
    //     pipeline,
    //     a_buf,
    //     b_buf,
    //     output_buffer,
    //     command_buffer,
    //     encoder,
    // });

    const res: [*]f32 = @ptrCast(@alignCast(c.mtl_buffer_get_contents(output_buffer)));
    std.debug.print("Result: {d}\n", .{res[0]});
}
