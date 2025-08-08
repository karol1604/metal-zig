const std = @import("std");
const c = @cImport({
    @cInclude("metal_shim.h");
});

pub const MTLSize = struct {
    width: usize,
    height: usize,
    depth: usize,

    pub fn init(width: usize, height: usize, depth: usize) MTLSize {
        return MTLSize{ .width = width, .height = height, .depth = depth };
    }
};

pub const ComputeCommandEncoder = struct {
    handle: *c.MTLComputeCommandEncoderHandle,
    pub fn deinit(self: *ComputeCommandEncoder) void {
        c.mtl_release_compute_command_encoder(self.handle);
    }

    pub fn setComputePipelineState(self: *ComputeCommandEncoder, pipeline: *ComputePipelineState) void {
        c.mtl_enc_set_compute_pipeline_state(self.handle, pipeline.handle);
    }

    pub fn setBuffer(self: *ComputeCommandEncoder, buffer: *Buffer, offset: usize, index: u32) void {
        c.mtl_enc_set_buffer(self.handle, buffer.handle, @intCast(offset), @intCast(index));
    }

    pub fn dispatchThreads(self: *ComputeCommandEncoder, threadsPerGridX: usize, threadsPerGridY: usize, threadsPerGridZ: usize, threadsPerThreadgroupX: usize, threadsPerThreadgroupY: usize, threadsPerThreadgroupZ: usize) void {
        c.mtl_enc_dispatch_threads(
            self.handle,
            @intCast(threadsPerGridX),
            @intCast(threadsPerGridY),
            @intCast(threadsPerGridZ),
            @intCast(threadsPerThreadgroupX),
            @intCast(threadsPerThreadgroupY),
            @intCast(threadsPerThreadgroupZ),
        );
    }

    pub fn endEncoding(self: *ComputeCommandEncoder) void {
        c.mtl_end_encoding(self.handle);
    }
};

pub const CommandBuffer = struct {
    handle: *c.MTLCommandBufferHandle,
    pub fn deinit(self: *CommandBuffer) void {
        c.mtl_release_command_buffer(self.handle);
    }

    pub fn newComputeCommandEncoder(self: *CommandBuffer) !ComputeCommandEncoder {
        const encoder = c.mtl_new_compute_command_encoder(self.handle);
        if (encoder == null) return error.ComputeCommandEncoderCreationFailed;
        return ComputeCommandEncoder{ .handle = encoder.? };
    }

    pub fn commit(self: *CommandBuffer) void {
        c.mtl_command_buffer_commit(self.handle);
    }

    pub fn waitUntilCompleted(self: *CommandBuffer) void {
        c.mtl_command_buffer_wait_until_completed(self.handle);
    }
};

pub const CommandQueue = struct {
    handle: *c.MTLCommandQueueHandle,
    pub fn deinit(self: *CommandQueue) void {
        c.mtl_release_command_queue(self.handle);
    }

    pub fn newCommandBuffer(self: *CommandQueue) !CommandBuffer {
        const command_buffer = c.mtl_new_command_buffer(self.handle);
        if (command_buffer == null) return error.CommandBufferCreationFailed;
        return CommandBuffer{ .handle = command_buffer.? };
    }
};

pub const Function = struct {
    handle: *c.MTLFunctionHandle,
    pub fn deinit(self: *Function) void {
        c.mtl_release_function(self.handle);
    }
};

pub const Library = struct {
    handle: *c.MTLLibraryHandle,
    pub fn deinit(self: *Library) void {
        c.mtl_release_library(self.handle);
    }

    pub fn newFunctionWithName(self: *Library, name: [*c]const u8) !Function {
        const function = c.mtl_new_function_with_name(self.handle, name);
        if (function == null) return error.FunctionCreationFailed;
        return Function{ .handle = function.? };
    }
};

pub const ComputePipelineState = struct {
    handle: *c.MTLComputePipelineStateHandle,
    pub fn deinit(self: *ComputePipelineState) void {
        c.mtl_release_compute_pipeline_state(self.handle);
    }
};

pub const Buffer = struct {
    handle: *c.MTLBufferHandle,
    len: usize,

    pub fn deinit(self: *Buffer) void {
        c.mtl_release_buffer(self.handle);
    }

    pub fn getContents(self: *Buffer) ?[]u8 {
        const contents: [*]u8 = @ptrCast(c.mtl_buffer_get_contents(self.handle));
        // if (contents == null) return null;
        return contents[0..self.len];
    }

    pub fn getContentsAs(self: *Buffer, comptime T: type) ?[]T {
        const contents = self.getContents() orelse return null;
        return @alignCast(std.mem.bytesAsSlice(T, contents));
    }
};

pub const Device = struct {
    handle: *c.MTLDeviceHandle,
    pub fn init() !Device {
        const device = c.mtl_create_system_default_device();
        if (device == null) return error.NoDevice;
        return Device{ .handle = device.? };
    }

    pub fn deinit(self: *Device) void {
        c.mtl_release_device(self.handle);
    }

    pub fn newCommandQueue(self: *Device) !CommandQueue {
        const queue = c.mtl_new_command_queue(self.handle);
        if (queue == null) return error.CommandQueueCreationFailed;
        return CommandQueue{ .handle = queue.? };
    }

    pub fn newLibraryWithURL(self: *Device, url: [*c]const u8) !Library {
        const library = c.mtl_new_library_with_url(self.handle, url);
        if (library == null) return error.LibraryCreationFailed;
        return Library{ .handle = library.? };
    }

    pub fn newComputePipelineStateWithFunction(self: *Device, function: *Function) !ComputePipelineState {
        const pipeline = c.mtl_new_compute_pipeline_state_with_function(self.handle, function.handle);
        if (pipeline == null) return error.PipelineCreationFailed;
        return ComputePipelineState{ .handle = pipeline.? };
    }

    pub fn newBufferWithLength(self: *Device, length: usize, options: c.MTLResourceOptionsHandle) !Buffer {
        const buffer = c.mtl_new_buffer_with_length(self.handle, @intCast(length), options);
        if (buffer == null) return error.BufferCreationFailed;
        return Buffer{ .handle = buffer.?, .len = length };
    }
};

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

    const input_len = 100_000_000;
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

    const res = output_buffer.getContentsAs(f32) orelse return error.BufferContentsUnavailable;
    std.debug.print("Result: {d}\n", .{res[0]});
}
