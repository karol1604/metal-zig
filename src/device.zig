const std = @import("std");
const c = @import("internal/c.zig").bindings;
const ErrorInfo = @import("error_info.zig").ErrorInfo;
const commands = @import("commands.zig");
const library = @import("library.zig");
const render = @import("render.zig");
const resource = @import("resource.zig");
const surface = @import("surface.zig");
const texture = @import("texture.zig");

pub const DeviceList = struct {
    items: []Device,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *DeviceList) void {
        for (self.items) |*device| {
            device.deinit();
        }
        self.allocator.free(self.items);
        self.items = &.{};
    }
};

pub const Device = struct {
    handle: c.MTLDeviceHandle,

    pub fn systemDefault() !Device {
        const device = c.mtl_create_system_default_device() orelse return error.NoDevice;
        return .{ .handle = device };
    }

    pub fn copyAllDevices(allocator: std.mem.Allocator) !DeviceList {
        const list = c.mtl_copy_all_devices();
        if (list.devices == null or list.count == 0) {
            return error.NoDevicesAvailable;
        }

        const handles = list.devices.?;
        const devices = allocator.alloc(Device, list.count) catch |err| {
            for (handles[0..list.count]) |handle| {
                if (handle) |value| {
                    c.mtl_release_device(value);
                }
            }
            c.mtl_free(@ptrCast(handles));
            return err;
        };
        errdefer allocator.free(devices);

        var initialized: usize = 0;
        errdefer {
            for (devices[0..initialized]) |*device| {
                device.deinit();
            }
            for (handles[initialized..list.count]) |handle| {
                if (handle) |value| {
                    c.mtl_release_device(value);
                }
            }
            c.mtl_free(@ptrCast(handles));
        }

        for (handles[0..list.count], devices) |handle, *device| {
            device.* = .{ .handle = handle orelse return error.InvalidDeviceList };
            initialized += 1;
        }
        c.mtl_free(@ptrCast(handles));

        return .{ .items = devices, .allocator = allocator };
    }

    pub fn deinit(self: *Device) void {
        if (self.handle) |handle| {
            c.mtl_release_device(handle);
            self.handle = null;
        }
    }

    pub fn clone(self: *const Device) Device {
        return .{ .handle = c.mtl_retain_device(self.requireHandle()) };
    }

    pub fn name(self: *const Device, allocator: std.mem.Allocator) ![]u8 {
        const handle = self.requireHandle();
        const length = c.mtl_get_device_name(handle, null, 0);
        if (length == 0) {
            return error.DeviceNameUnavailable;
        }

        const result = try allocator.alloc(u8, length);
        errdefer allocator.free(result);
        if (c.mtl_get_device_name(handle, result.ptr, result.len) != length) {
            return error.DeviceNameUnavailable;
        }
        return result;
    }

    pub fn newCommandQueue(self: *const Device) !commands.CommandQueue {
        const queue = c.mtl_new_command_queue(self.requireHandle()) orelse
            return error.CommandQueueCreationFailed;
        return .{ .handle = queue };
    }

    pub fn newLibraryWithFile(self: *const Device, path: []const u8) !library.Library {
        return self.newLibraryWithFileDetailed(path, null);
    }

    pub fn newLibraryWithFileDetailed(
        self: *const Device,
        path: []const u8,
        error_info: ?*ErrorInfo,
    ) !library.Library {
        if (error_info) |info| {
            info.clear();
        }
        if (path.len == 0) {
            return error.InvalidLibraryPath;
        }
        if (!std.unicode.utf8ValidateSlice(path) or
            std.mem.indexOfScalar(u8, path, 0) != null)
        {
            return error.InvalidLibraryPath;
        }
        const c_error_info: ?*c.MTLErrorInfo =
            if (error_info) |info| @ptrCast(info) else null;
        const metal_library = c.mtl_new_library_with_file(
            self.requireHandle(),
            path.ptr,
            path.len,
            c_error_info,
        ) orelse return error.LibraryCreationFailed;
        return .{ .handle = metal_library };
    }

    pub fn newLibraryWithData(self: *const Device, data: []const u8) !library.Library {
        return self.newLibraryWithDataDetailed(data, null);
    }

    pub fn newLibraryWithDataDetailed(
        self: *const Device,
        data: []const u8,
        error_info: ?*ErrorInfo,
    ) !library.Library {
        if (error_info) |info| {
            info.clear();
        }
        if (data.len == 0) {
            return error.EmptyLibraryData;
        }
        const c_error_info: ?*c.MTLErrorInfo =
            if (error_info) |info| @ptrCast(info) else null;
        const metal_library = c.mtl_new_library_with_data(
            self.requireHandle(),
            data.ptr,
            data.len,
            c_error_info,
        ) orelse return error.LibraryCreationFailed;
        return .{ .handle = metal_library };
    }

    pub fn newLibraryWithSource(self: *const Device, source: []const u8) !library.Library {
        return self.newLibraryWithSourceDetailed(source, null);
    }

    pub fn newLibraryWithSourceDetailed(
        self: *const Device,
        source: []const u8,
        error_info: ?*ErrorInfo,
    ) !library.Library {
        if (error_info) |info| {
            info.clear();
        }
        if (source.len == 0) {
            return error.EmptyLibrarySource;
        }
        if (!std.unicode.utf8ValidateSlice(source)) {
            return error.InvalidLibrarySourceEncoding;
        }
        const c_error_info: ?*c.MTLErrorInfo =
            if (error_info) |info| @ptrCast(info) else null;
        const metal_library = c.mtl_new_library_with_source(
            self.requireHandle(),
            source.ptr,
            source.len,
            c_error_info,
        ) orelse return error.LibraryCreationFailed;
        return .{ .handle = metal_library };
    }

    pub fn newComputePipelineStateWithFunction(
        self: *const Device,
        function: *const library.Function,
    ) !library.ComputePipelineState {
        return self.newComputePipelineStateWithFunctionDetailed(function, null);
    }

    pub fn newComputePipelineStateWithFunctionDetailed(
        self: *const Device,
        function: *const library.Function,
        error_info: ?*ErrorInfo,
    ) !library.ComputePipelineState {
        if (error_info) |info| {
            info.clear();
        }
        const c_error_info: ?*c.MTLErrorInfo =
            if (error_info) |info| @ptrCast(info) else null;
        const pipeline = c.mtl_new_compute_pipeline_state_with_function(
            self.requireHandle(),
            function.handle orelse @panic("use of deinitialized Metal function"),
            c_error_info,
        ) orelse return error.PipelineCreationFailed;

        return .{ .handle = pipeline };
    }

    pub fn newRenderPipelineState(
        self: *const Device,
        descriptor: render.RenderPipelineDescriptor,
    ) !render.RenderPipelineState {
        return self.newRenderPipelineStateDetailed(descriptor, null);
    }

    pub fn newRenderPipelineStateDetailed(
        self: *const Device,
        descriptor: render.RenderPipelineDescriptor,
        error_info: ?*ErrorInfo,
    ) !render.RenderPipelineState {
        return render.RenderPipelineState.create(
            self.requireHandle(),
            descriptor,
            error_info,
        );
    }

    pub fn newBufferWithLength(
        self: *const Device,
        length: usize,
        options: resource.ResourceOptions,
    ) !resource.Buffer {
        if (length == 0) {
            return error.InvalidBufferLength;
        }
        const buffer = c.mtl_new_buffer_with_length(
            self.requireHandle(),
            length,
            options.toRaw(),
        ) orelse return error.BufferCreationFailed;

        const actual_length = c.mtl_buffer_get_length(buffer);
        if (actual_length != length) {
            c.mtl_release_buffer(buffer);
            return error.UnexpectedBufferLength;
        }
        return .{
            .handle = buffer,
            .length = actual_length,
            .storage_mode = options.storage_mode,
        };
    }

    pub fn newBufferWithBytes(
        self: *const Device,
        bytes: []const u8,
        options: resource.ResourceOptions,
    ) !resource.Buffer {
        if (bytes.len == 0) {
            return error.EmptyBufferData;
        }
        var buffer = try self.newBufferWithLength(bytes.len, options);
        errdefer buffer.deinit();
        const destination = buffer.contents() orelse return error.BufferContentsUnavailable;
        @memcpy(destination, bytes);
        if (options.storage_mode == .managed) {
            try buffer.didModifyRange(0, bytes.len);
        }
        return buffer;
    }

    pub fn newTexture(
        self: *const Device,
        descriptor: texture.TextureDescriptor,
    ) !texture.Texture {
        if (descriptor.width == 0 or descriptor.height == 0 or descriptor.depth == 0 or
            descriptor.mipmap_level_count == 0 or descriptor.sample_count == 0 or
            descriptor.array_length == 0 or descriptor.pixel_format == .invalid)
        {
            return error.InvalidTextureDescriptor;
        }
        const c_descriptor = c.MTLZTextureDescriptor{
            .width = descriptor.width,
            .height = descriptor.height,
            .depth = descriptor.depth,
            .mipmap_level_count = descriptor.mipmap_level_count,
            .sample_count = descriptor.sample_count,
            .array_length = descriptor.array_length,
            .texture_type = @intFromEnum(descriptor.texture_type),
            .pixel_format = @intFromEnum(descriptor.pixel_format),
            .usage = descriptor.usage.toRaw(),
            .storage_mode = @intFromEnum(descriptor.storage_mode),
            .cpu_cache_mode = @intFromEnum(descriptor.cpu_cache_mode),
        };
        const handle = c.mtl_new_texture(self.requireHandle(), &c_descriptor) orelse
            return error.TextureCreationFailed;
        return texture.Texture.initOwned(handle, descriptor.mipmap_level_count);
    }

    pub fn newSamplerState(
        self: *const Device,
        descriptor: texture.SamplerDescriptor,
    ) !texture.SamplerState {
        if (descriptor.max_anisotropy == 0 or descriptor.max_anisotropy > 16) {
            return error.InvalidSamplerDescriptor;
        }
        const c_descriptor = c.MTLZSamplerDescriptor{
            .min_filter = @intFromEnum(descriptor.min_filter),
            .mag_filter = @intFromEnum(descriptor.mag_filter),
            .mip_filter = @intFromEnum(descriptor.mip_filter),
            .s_address_mode = @intFromEnum(descriptor.s_address_mode),
            .t_address_mode = @intFromEnum(descriptor.t_address_mode),
            .r_address_mode = @intFromEnum(descriptor.r_address_mode),
            .max_anisotropy = descriptor.max_anisotropy,
            .normalized_coordinates = descriptor.normalized_coordinates,
        };
        const handle = c.mtl_new_sampler_state(self.requireHandle(), &c_descriptor) orelse
            return error.SamplerStateCreationFailed;
        return texture.SamplerState.initOwned(handle);
    }

    pub fn newMetalLayer(self: *const Device) !surface.MetalLayer {
        return surface.MetalLayer.create(self.requireHandle());
    }

    pub fn setMetalLayerDevice(
        self: *const Device,
        layer: *const surface.MetalLayer,
    ) void {
        layer.setDevice(self.requireHandle());
    }

    fn requireHandle(self: *const Device) @typeInfo(c.MTLDeviceHandle).optional.child {
        return self.handle orelse @panic("use of deinitialized Metal device");
    }
};
