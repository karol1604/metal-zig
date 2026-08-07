const std = @import("std");
const c = @import("internal/c.zig").bindings;
const ErrorInfo = @import("error_info.zig").ErrorInfo;
const library = @import("library.zig");
const render = @import("render.zig");
const resource = @import("resource.zig");
const surface = @import("surface.zig");
const texture = @import("texture.zig");

pub const Size = struct {
    width: usize,
    height: usize,
    depth: usize,

    pub fn init(width: usize, height: usize, depth: usize) Size {
        return .{ .width = width, .height = height, .depth = depth };
    }

    pub fn oneDimensional(width: usize) Size {
        return .{ .width = width, .height = 1, .depth = 1 };
    }
};

pub const ComputeCommandEncoder = struct {
    handle: c.MTLComputeCommandEncoderHandle,
    ended: bool = false,
    max_threads_per_threadgroup: ?usize = null,

    pub fn deinit(self: *ComputeCommandEncoder) void {
        if (self.handle) |handle| {
            c.mtl_release_compute_command_encoder(handle);
            self.handle = null;
        }
    }

    pub fn setComputePipelineState(
        self: *ComputeCommandEncoder,
        pipeline: *const library.ComputePipelineState,
    ) void {
        const pipeline_handle =
            pipeline.handle orelse @panic("use of deinitialized Metal compute pipeline");
        c.mtl_enc_set_compute_pipeline_state(
            self.requireActiveHandle(),
            pipeline_handle,
        );
        self.max_threads_per_threadgroup =
            c.mtl_get_max_total_threads_per_threadgroup(pipeline_handle);
    }

    pub fn setBuffer(
        self: *const ComputeCommandEncoder,
        buffer: ?*const resource.Buffer,
        offset: usize,
        index: usize,
    ) !void {
        if (buffer) |value| {
            if (offset > value.length) {
                return error.BufferOffsetOutOfBounds;
            }
        } else if (offset != 0) {
            return error.BufferOffsetWithoutBuffer;
        }
        c.mtl_enc_set_buffer(
            self.requireActiveHandle(),
            if (buffer) |value|
                value.handle orelse @panic("use of deinitialized Metal buffer")
            else
                null,
            offset,
            index,
        );
    }

    pub fn setBytes(self: *const ComputeCommandEncoder, bytes: []const u8, index: usize) !void {
        if (bytes.len == 0) {
            return error.EmptyBytes;
        }
        c.mtl_enc_set_bytes(self.requireActiveHandle(), index, bytes.len, bytes.ptr);
    }

    pub fn dispatchThreads(
        self: *const ComputeCommandEncoder,
        threads_per_grid: Size,
        threads_per_threadgroup: Size,
    ) !void {
        if (threads_per_grid.width == 0 or
            threads_per_grid.height == 0 or
            threads_per_grid.depth == 0 or
            threads_per_threadgroup.width == 0 or
            threads_per_threadgroup.height == 0 or
            threads_per_threadgroup.depth == 0)
        {
            return error.InvalidDispatchSize;
        }
        const max_threads = self.max_threads_per_threadgroup orelse
            return error.ComputePipelineStateNotSet;
        const threadgroup_xy = std.math.mul(
            usize,
            threads_per_threadgroup.width,
            threads_per_threadgroup.height,
        ) catch return error.InvalidDispatchSize;
        const threadgroup_total = std.math.mul(
            usize,
            threadgroup_xy,
            threads_per_threadgroup.depth,
        ) catch return error.InvalidDispatchSize;
        if (threadgroup_total > max_threads) {
            return error.ThreadgroupTooLarge;
        }

        c.mtl_enc_dispatch_threads(
            self.requireActiveHandle(),
            threads_per_grid.width,
            threads_per_grid.height,
            threads_per_grid.depth,
            threads_per_threadgroup.width,
            threads_per_threadgroup.height,
            threads_per_threadgroup.depth,
        );
    }

    pub fn endEncoding(self: *ComputeCommandEncoder) !void {
        if (self.ended) {
            return error.EncodingAlreadyEnded;
        }
        c.mtl_end_encoding(self.requireHandle());
        self.ended = true;
    }

    fn init(handle: c.MTLComputeCommandEncoderHandle) ComputeCommandEncoder {
        return .{ .handle = handle };
    }

    fn requireActiveHandle(
        self: *const ComputeCommandEncoder,
    ) @typeInfo(c.MTLComputeCommandEncoderHandle).optional.child {
        if (self.ended) {
            @panic("cannot encode commands after endEncoding");
        }
        return self.requireHandle();
    }

    fn requireHandle(
        self: *const ComputeCommandEncoder,
    ) @typeInfo(c.MTLComputeCommandEncoderHandle).optional.child {
        return self.handle orelse @panic("use of deinitialized Metal compute encoder");
    }
};

pub const RenderCommandEncoder = struct {
    handle: c.MTLRenderCommandEncoderHandle,
    ended: bool = false,
    pipeline_state_set: bool = false,
    target_width: usize,
    target_height: usize,

    pub fn deinit(self: *RenderCommandEncoder) void {
        if (self.handle) |handle| {
            c.mtl_release_render_command_encoder(handle);
            self.handle = null;
        }
    }

    pub fn setRenderPipelineState(
        self: *RenderCommandEncoder,
        pipeline: *const render.RenderPipelineState,
    ) void {
        c.mtl_render_enc_set_pipeline_state(
            self.requireActiveHandle(),
            pipeline.requireHandle(),
        );
        self.pipeline_state_set = true;
    }

    pub fn setVertexBuffer(
        self: *const RenderCommandEncoder,
        buffer: ?*const resource.Buffer,
        offset: usize,
        index: usize,
    ) !void {
        try validateBufferBinding(buffer, offset);
        c.mtl_render_enc_set_vertex_buffer(
            self.requireActiveHandle(),
            if (buffer) |value| value.handle else null,
            offset,
            index,
        );
    }

    pub fn setVertexBytes(
        self: *const RenderCommandEncoder,
        bytes: []const u8,
        index: usize,
    ) !void {
        if (bytes.len == 0) {
            return error.EmptyBytes;
        }
        c.mtl_render_enc_set_vertex_bytes(
            self.requireActiveHandle(),
            index,
            bytes.len,
            bytes.ptr,
        );
    }

    pub fn setFragmentBuffer(
        self: *const RenderCommandEncoder,
        buffer: ?*const resource.Buffer,
        offset: usize,
        index: usize,
    ) !void {
        try validateBufferBinding(buffer, offset);
        c.mtl_render_enc_set_fragment_buffer(
            self.requireActiveHandle(),
            if (buffer) |value| value.handle else null,
            offset,
            index,
        );
    }

    pub fn setFragmentBytes(
        self: *const RenderCommandEncoder,
        bytes: []const u8,
        index: usize,
    ) !void {
        if (bytes.len == 0) {
            return error.EmptyBytes;
        }
        c.mtl_render_enc_set_fragment_bytes(
            self.requireActiveHandle(),
            index,
            bytes.len,
            bytes.ptr,
        );
    }

    pub fn setFragmentTexture(
        self: *const RenderCommandEncoder,
        value: ?*const texture.Texture,
        index: usize,
    ) void {
        c.mtl_render_enc_set_fragment_texture(
            self.requireActiveHandle(),
            if (value) |present| present.handle else null,
            index,
        );
    }

    pub fn setFragmentSamplerState(
        self: *const RenderCommandEncoder,
        sampler: ?*const texture.SamplerState,
        index: usize,
    ) void {
        c.mtl_render_enc_set_fragment_sampler(
            self.requireActiveHandle(),
            if (sampler) |present| present.handle else null,
            index,
        );
    }

    pub fn setViewport(self: *const RenderCommandEncoder, viewport: render.Viewport) !void {
        if (!std.math.isFinite(viewport.origin_x) or
            !std.math.isFinite(viewport.origin_y) or
            !std.math.isFinite(viewport.width) or
            !std.math.isFinite(viewport.height) or
            !std.math.isFinite(viewport.znear) or
            !std.math.isFinite(viewport.zfar) or
            viewport.width <= 0 or
            viewport.height <= 0 or
            viewport.znear > viewport.zfar)
        {
            return error.InvalidViewport;
        }
        c.mtl_render_enc_set_viewport(
            self.requireActiveHandle(),
            viewport.origin_x,
            viewport.origin_y,
            viewport.width,
            viewport.height,
            viewport.znear,
            viewport.zfar,
        );
    }

    pub fn setScissorRect(self: *const RenderCommandEncoder, rect: render.ScissorRect) !void {
        if (rect.width == 0 or rect.height == 0 or
            rect.x > self.target_width or rect.width > self.target_width - rect.x or
            rect.y > self.target_height or rect.height > self.target_height - rect.y)
        {
            return error.InvalidScissorRect;
        }
        c.mtl_render_enc_set_scissor_rect(
            self.requireActiveHandle(),
            rect.x,
            rect.y,
            rect.width,
            rect.height,
        );
    }

    pub fn drawPrimitives(
        self: *const RenderCommandEncoder,
        primitive_type: render.PrimitiveType,
        vertex_start: usize,
        vertex_count: usize,
        instance_count: usize,
    ) !void {
        if (!self.pipeline_state_set) {
            return error.RenderPipelineStateNotSet;
        }
        if (vertex_count == 0 or instance_count == 0) {
            return error.InvalidDrawCount;
        }
        c.mtl_render_enc_draw_primitives(
            self.requireActiveHandle(),
            @intFromEnum(primitive_type),
            vertex_start,
            vertex_count,
            instance_count,
        );
    }

    pub fn drawIndexedPrimitives(
        self: *const RenderCommandEncoder,
        primitive_type: render.PrimitiveType,
        index_count: usize,
        index_type: render.IndexType,
        index_buffer: *const resource.Buffer,
        index_buffer_offset: usize,
        instance_count: usize,
    ) !void {
        if (!self.pipeline_state_set) {
            return error.RenderPipelineStateNotSet;
        }
        if (index_count == 0 or instance_count == 0) {
            return error.InvalidDrawCount;
        }
        const index_size = index_type.size();
        if (index_buffer_offset % index_size != 0) {
            return error.MisalignedIndexBufferOffset;
        }
        const index_bytes = std.math.mul(usize, index_count, index_size) catch
            return error.IndexBufferOutOfBounds;
        if (index_buffer_offset > index_buffer.length or
            index_bytes > index_buffer.length - index_buffer_offset)
        {
            return error.IndexBufferOutOfBounds;
        }
        c.mtl_render_enc_draw_indexed_primitives(
            self.requireActiveHandle(),
            @intFromEnum(primitive_type),
            index_count,
            @intFromEnum(index_type),
            index_buffer.handle,
            index_buffer_offset,
            instance_count,
        );
    }

    pub fn endEncoding(self: *RenderCommandEncoder) !void {
        if (self.ended) {
            return error.EncodingAlreadyEnded;
        }
        c.mtl_render_enc_end_encoding(self.requireHandle());
        self.ended = true;
    }

    fn init(
        handle: c.MTLRenderCommandEncoderHandle,
        target_width: usize,
        target_height: usize,
    ) RenderCommandEncoder {
        return .{
            .handle = handle,
            .target_width = target_width,
            .target_height = target_height,
        };
    }

    fn requireActiveHandle(
        self: *const RenderCommandEncoder,
    ) @typeInfo(c.MTLRenderCommandEncoderHandle).optional.child {
        if (self.ended) {
            @panic("cannot encode commands after endEncoding");
        }
        return self.requireHandle();
    }

    fn requireHandle(
        self: *const RenderCommandEncoder,
    ) @typeInfo(c.MTLRenderCommandEncoderHandle).optional.child {
        return self.handle orelse @panic("use of deinitialized Metal render encoder");
    }

    fn validateBufferBinding(buffer: ?*const resource.Buffer, offset: usize) !void {
        if (buffer) |value| {
            if (offset > value.length) {
                return error.BufferOffsetOutOfBounds;
            }
            _ = value.handle orelse @panic("use of deinitialized Metal buffer");
        } else if (offset != 0) {
            return error.BufferOffsetWithoutBuffer;
        }
    }
};

pub const CommandBufferStatus = enum(u32) {
    not_enqueued = 0,
    enqueued = 1,
    committed = 2,
    scheduled = 3,
    completed = 4,
    failed = 5,
};

pub const CommandBufferCompletionFn =
    *const fn (context: ?*anyopaque, status: CommandBufferStatus) callconv(.c) void;

pub const CommandBuffer = struct {
    handle: c.MTLCommandBufferHandle,
    committed: bool = false,

    pub fn deinit(self: *CommandBuffer) void {
        if (self.handle) |handle| {
            c.mtl_release_command_buffer(handle);
            self.handle = null;
        }
    }

    pub fn newComputeCommandEncoder(self: *const CommandBuffer) !ComputeCommandEncoder {
        if (self.committed) {
            return error.CommandBufferAlreadyCommitted;
        }
        const encoder = c.mtl_new_compute_command_encoder(self.requireHandle()) orelse
            return error.ComputeCommandEncoderCreationFailed;
        return ComputeCommandEncoder.init(encoder);
    }

    pub fn newRenderCommandEncoder(
        self: *const CommandBuffer,
        descriptor: render.RenderPassDescriptor,
    ) !RenderCommandEncoder {
        if (self.committed) {
            return error.CommandBufferAlreadyCommitted;
        }
        const target = descriptor.color_texture;
        const c_descriptor = c.MTLZRenderPassDescriptor{
            .color_texture = target.requireHandle(),
            .load_action = @intFromEnum(descriptor.load_action),
            .store_action = @intFromEnum(descriptor.store_action),
            .clear_red = descriptor.clear_color.red,
            .clear_green = descriptor.clear_color.green,
            .clear_blue = descriptor.clear_color.blue,
            .clear_alpha = descriptor.clear_color.alpha,
        };
        const encoder = c.mtl_new_render_command_encoder(
            self.requireHandle(),
            &c_descriptor,
        ) orelse return error.RenderCommandEncoderCreationFailed;
        return RenderCommandEncoder.init(encoder, target.width(), target.height());
    }

    pub fn present(self: *const CommandBuffer, drawable: *const surface.Drawable) !void {
        if (self.committed) {
            return error.CommandBufferAlreadyCommitted;
        }
        c.mtl_command_buffer_present_drawable(
            self.requireHandle(),
            drawable.requireHandle(),
        );
    }

    /// The callback may run on any system-managed thread. The caller owns the
    /// context and must keep it alive until the callback fires.
    pub fn addCompletedHandler(
        self: *const CommandBuffer,
        callback: CommandBufferCompletionFn,
        context: ?*anyopaque,
    ) !void {
        if (self.committed) {
            return error.CommandBufferAlreadyCommitted;
        }
        c.mtl_command_buffer_add_completed_handler(
            self.requireHandle(),
            @ptrCast(callback),
            context,
        );
    }

    pub fn status(self: *const CommandBuffer) CommandBufferStatus {
        return @enumFromInt(c.mtl_command_buffer_get_status(self.requireHandle()));
    }

    pub fn commit(self: *CommandBuffer) !void {
        if (self.committed) {
            return error.CommandBufferAlreadyCommitted;
        }
        c.mtl_command_buffer_commit(self.requireHandle());
        self.committed = true;
    }

    pub fn waitUntilCompleted(self: *const CommandBuffer) !void {
        return self.waitUntilCompletedDetailed(null);
    }

    pub fn waitUntilCompletedDetailed(
        self: *const CommandBuffer,
        error_info: ?*ErrorInfo,
    ) !void {
        if (error_info) |info| {
            info.clear();
        }
        if (!self.committed) {
            return error.CommandBufferNotCommitted;
        }
        const c_error_info: ?*c.MTLErrorInfo =
            if (error_info) |info| @ptrCast(info) else null;
        if (!c.mtl_command_buffer_wait_until_completed(
            self.requireHandle(),
            c_error_info,
        )) {
            return error.CommandBufferExecutionFailed;
        }
    }

    fn init(handle: c.MTLCommandBufferHandle) CommandBuffer {
        return .{ .handle = handle };
    }

    fn requireHandle(
        self: *const CommandBuffer,
    ) @typeInfo(c.MTLCommandBufferHandle).optional.child {
        return self.handle orelse @panic("use of deinitialized Metal command buffer");
    }
};

pub const CommandQueue = struct {
    handle: c.MTLCommandQueueHandle,

    pub fn deinit(self: *CommandQueue) void {
        if (self.handle) |handle| {
            c.mtl_release_command_queue(handle);
            self.handle = null;
        }
    }

    pub fn clone(self: *const CommandQueue) CommandQueue {
        return .{ .handle = c.mtl_retain_command_queue(self.requireHandle()) };
    }

    pub fn newCommandBuffer(self: *const CommandQueue) !CommandBuffer {
        const command_buffer = c.mtl_new_command_buffer(self.requireHandle()) orelse
            return error.CommandBufferCreationFailed;
        return CommandBuffer.init(command_buffer);
    }

    fn init(handle: c.MTLCommandQueueHandle) CommandQueue {
        return .{ .handle = handle };
    }

    fn requireHandle(
        self: *const CommandQueue,
    ) @typeInfo(c.MTLCommandQueueHandle).optional.child {
        return self.handle orelse @panic("use of deinitialized Metal command queue");
    }
};
