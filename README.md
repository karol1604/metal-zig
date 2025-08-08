# metal-zig

A minimal, typesafe Zig wrapper for Apple's [Metal](https://developer.apple.com/metal/) framework.
This library makes it possible to use Metal from Zig without ever touching Objective‑C directly.

## Notes
- This is **not** a complete Metal wrapper. I basically add stuff as I need it.
- The library is designed more for compute workloads than graphics (cause i know nothig about graphics lol).
- I basically made this thing in order to create a macOS NN library in Zig for learning purposes. I really don't know what i'm doing, so please don't expect this to be production-ready.

## Getting Started

### Pre-requisites
To use this library, you need:
- A macOS system with Xcode installed
- Zig installed (version 0.11.0 or later)
- `xcrun` in your PATH

### Building the library
To build the whole thing, run:
```bash
make
```
To only compile your kernels, run:
```bash
make kernels
```

## Example Usage
Below is a simple example of how to use the library to run a Metal kernel:

```zig
pub fn main() !void {
    var device = try Device.init();
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
    var a_buf = try device.newBufferWithLength(input_len * @sizeOf(f32), 0);
    defer a_buf.deinit();
    var b_buf = try device.newBufferWithLength(input_len * @sizeOf(f32), 0);
    defer b_buf.deinit();

    const a_ptr = a_buf.getContentsAs(f32) orelse return error.BufferContentsUnavailable;
    const b_ptr = b_buf.getContentsAs(f32) orelse return error.BufferContentsUnavailable;

    const output_len = 10_000_000;
    var output_buffer = try device.newBufferWithLength(output_len * @sizeOf(f32), 0);
    defer output_buffer.deinit();

    for (a_ptr, 0..input_len, b_ptr) |*a_val, i, *b_val| {
        a_val.* = @floatFromInt(i);
        b_val.* = @floatFromInt(input_len - i);
    }

    var command_buffer = try q.newCommandBuffer();
    defer command_buffer.deinit();

    var encoder = try command_buffer.newComputeCommandEncoder();
    defer encoder.deinit();

    encoder.setComputePipelineState(&pipeline);

    encoder.setBuffer(&a_buf, 0, 0);
    encoder.setBuffer(&b_buf, 0, 1);
    encoder.setBuffer(&output_buffer, 0, 2);

    encoder.dispatchThreads(input_len, 1, 1, 1000, 1, 1);
    encoder.endEncoding();

    command_buffer.commit();
    command_buffer.waitUntilCompleted();
}
```
