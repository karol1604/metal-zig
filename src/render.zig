const c = @import("internal/c.zig").bindings;
const ErrorInfo = @import("error_info.zig").ErrorInfo;
const library = @import("library.zig");
const texture = @import("texture.zig");

pub const VertexFormat = enum(u32) {
    invalid = 0,
    uchar2 = 1,
    uchar3 = 2,
    uchar4 = 3,
    char2 = 4,
    char3 = 5,
    char4 = 6,
    uchar2_normalized = 7,
    uchar3_normalized = 8,
    uchar4_normalized = 9,
    char2_normalized = 10,
    char3_normalized = 11,
    char4_normalized = 12,
    ushort2 = 13,
    ushort3 = 14,
    ushort4 = 15,
    short2 = 16,
    short3 = 17,
    short4 = 18,
    ushort2_normalized = 19,
    ushort3_normalized = 20,
    ushort4_normalized = 21,
    short2_normalized = 22,
    short3_normalized = 23,
    short4_normalized = 24,
    half2 = 25,
    half3 = 26,
    half4 = 27,
    float = 28,
    float2 = 29,
    float3 = 30,
    float4 = 31,
    int = 32,
    int2 = 33,
    int3 = 34,
    int4 = 35,
    uint = 36,
    uint2 = 37,
    uint3 = 38,
    uint4 = 39,
};

pub const VertexStepFunction = enum(u32) {
    constant = 0,
    per_vertex = 1,
    per_instance = 2,
};

pub const VertexAttributeDescriptor = struct {
    format: VertexFormat,
    offset: usize,
    buffer_index: usize = 0,
};

pub const VertexBufferLayoutDescriptor = struct {
    stride: usize,
    step_function: VertexStepFunction = .per_vertex,
    step_rate: usize = 1,
};

pub const VertexDescriptor = struct {
    attributes: []const VertexAttributeDescriptor = &.{},
    layouts: []const VertexBufferLayoutDescriptor = &.{},
};

pub const BlendFactor = enum(u32) {
    zero = 0,
    one = 1,
    source_color = 2,
    one_minus_source_color = 3,
    source_alpha = 4,
    one_minus_source_alpha = 5,
    destination_color = 6,
    one_minus_destination_color = 7,
    destination_alpha = 8,
    one_minus_destination_alpha = 9,
    source_alpha_saturated = 10,
    blend_color = 11,
    one_minus_blend_color = 12,
    blend_alpha = 13,
    one_minus_blend_alpha = 14,
    source1_color = 15,
    one_minus_source1_color = 16,
    source1_alpha = 17,
    one_minus_source1_alpha = 18,
};

pub const BlendOperation = enum(u32) {
    add = 0,
    subtract = 1,
    reverse_subtract = 2,
    min = 3,
    max = 4,
};

pub const ColorWriteMask = packed struct(u8) {
    red: bool = true,
    green: bool = true,
    blue: bool = true,
    alpha: bool = true,
    _reserved: u4 = 0,

    pub fn toRaw(self: ColorWriteMask) u32 {
        return @as(u32, @as(u8, @bitCast(self)));
    }
};

pub const ColorAttachmentDescriptor = struct {
    pixel_format: texture.PixelFormat,
    blending_enabled: bool = true,
    source_rgb_blend_factor: BlendFactor = .source_alpha,
    destination_rgb_blend_factor: BlendFactor = .one_minus_source_alpha,
    rgb_blend_operation: BlendOperation = .add,
    source_alpha_blend_factor: BlendFactor = .one,
    destination_alpha_blend_factor: BlendFactor = .one_minus_source_alpha,
    alpha_blend_operation: BlendOperation = .add,
    write_mask: ColorWriteMask = .{},
};

pub const RenderPipelineDescriptor = struct {
    vertex_function: *const library.Function,
    fragment_function: *const library.Function,
    vertex_descriptor: VertexDescriptor = .{},
    color_attachment: ColorAttachmentDescriptor,
    sample_count: usize = 1,
};

pub const RenderPipelineState = struct {
    handle: c.MTLRenderPipelineStateHandle,

    pub fn deinit(self: *RenderPipelineState) void {
        if (self.handle) |handle| {
            c.mtl_release_render_pipeline_state(handle);
            self.handle = null;
        }
    }

    pub fn clone(self: *const RenderPipelineState) RenderPipelineState {
        return .{ .handle = c.mtl_retain_render_pipeline_state(self.requireHandle()) };
    }

    pub fn create(
        device_handle: c.MTLDeviceHandle,
        descriptor: RenderPipelineDescriptor,
        error_info: ?*ErrorInfo,
    ) !RenderPipelineState {
        if (descriptor.sample_count == 0) {
            return error.InvalidSampleCount;
        }
        if (descriptor.vertex_descriptor.attributes.len > 31 or
            descriptor.vertex_descriptor.layouts.len > 31)
        {
            return error.TooManyVertexDescriptorEntries;
        }
        if (error_info) |info| {
            info.clear();
        }

        var attributes: [31]c.MTLZVertexAttributeDescriptor = undefined;
        for (descriptor.vertex_descriptor.attributes, 0..) |attribute, index| {
            if (attribute.buffer_index >= 31) {
                return error.InvalidVertexBufferIndex;
            }
            attributes[index] = .{
                .format = @intFromEnum(attribute.format),
                .offset = attribute.offset,
                .buffer_index = attribute.buffer_index,
            };
        }
        var layouts: [31]c.MTLZVertexBufferLayoutDescriptor = undefined;
        for (descriptor.vertex_descriptor.layouts, 0..) |layout, index| {
            if (layout.stride == 0 or layout.step_rate == 0) {
                return error.InvalidVertexBufferLayout;
            }
            layouts[index] = .{
                .stride = layout.stride,
                .step_function = @intFromEnum(layout.step_function),
                .step_rate = layout.step_rate,
            };
        }

        const color = descriptor.color_attachment;
        const c_descriptor = c.MTLZRenderPipelineDescriptor{
            .vertex_function = descriptor.vertex_function.handle orelse
                @panic("use of deinitialized Metal vertex function"),
            .fragment_function = descriptor.fragment_function.handle orelse
                @panic("use of deinitialized Metal fragment function"),
            .vertex_attributes = if (descriptor.vertex_descriptor.attributes.len == 0)
                null
            else
                &attributes,
            .vertex_attribute_count = descriptor.vertex_descriptor.attributes.len,
            .vertex_layouts = if (descriptor.vertex_descriptor.layouts.len == 0)
                null
            else
                &layouts,
            .vertex_layout_count = descriptor.vertex_descriptor.layouts.len,
            .color_pixel_format = @intFromEnum(color.pixel_format),
            .blending_enabled = color.blending_enabled,
            .source_rgb_blend_factor = @intFromEnum(color.source_rgb_blend_factor),
            .destination_rgb_blend_factor = @intFromEnum(color.destination_rgb_blend_factor),
            .rgb_blend_operation = @intFromEnum(color.rgb_blend_operation),
            .source_alpha_blend_factor = @intFromEnum(color.source_alpha_blend_factor),
            .destination_alpha_blend_factor = @intFromEnum(color.destination_alpha_blend_factor),
            .alpha_blend_operation = @intFromEnum(color.alpha_blend_operation),
            .color_write_mask = color.write_mask.toRaw(),
            .sample_count = descriptor.sample_count,
        };
        const c_error_info: ?*c.MTLErrorInfo =
            if (error_info) |info| @ptrCast(info) else null;
        const pipeline = c.mtl_new_render_pipeline_state(
            device_handle,
            &c_descriptor,
            c_error_info,
        ) orelse return error.RenderPipelineCreationFailed;
        return .{ .handle = pipeline };
    }

    pub fn requireHandle(
        self: *const RenderPipelineState,
    ) @typeInfo(c.MTLRenderPipelineStateHandle).optional.child {
        return self.handle orelse @panic("use of deinitialized Metal render pipeline");
    }
};

pub const LoadAction = enum(u32) {
    dont_care = 0,
    load = 1,
    clear = 2,
};

pub const StoreAction = enum(u32) {
    dont_care = 0,
    store = 1,
    multisample_resolve = 2,
    store_and_multisample_resolve = 3,
};

pub const ClearColor = struct {
    red: f64 = 0,
    green: f64 = 0,
    blue: f64 = 0,
    alpha: f64 = 1,
};

pub const RenderPassDescriptor = struct {
    color_texture: *const texture.Texture,
    load_action: LoadAction = .clear,
    store_action: StoreAction = .store,
    clear_color: ClearColor = .{},
};

pub const Viewport = struct {
    origin_x: f64 = 0,
    origin_y: f64 = 0,
    width: f64,
    height: f64,
    znear: f64 = 0,
    zfar: f64 = 1,
};

pub const ScissorRect = struct {
    x: usize,
    y: usize,
    width: usize,
    height: usize,
};

pub const PrimitiveType = enum(u32) {
    point = 0,
    line = 1,
    line_strip = 2,
    triangle = 3,
    triangle_strip = 4,
};

pub const IndexType = enum(u32) {
    uint16 = 0,
    uint32 = 1,

    pub fn size(self: IndexType) usize {
        return switch (self) {
            .uint16 => @sizeOf(u16),
            .uint32 => @sizeOf(u32),
        };
    }
};
