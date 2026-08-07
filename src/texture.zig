const std = @import("std");
const c = @import("internal/c.zig").bindings;
const resource = @import("resource.zig");

pub const PixelFormat = enum(u32) {
    invalid = 0,
    a8_unorm = 1,
    r8_unorm = 10,
    r8_unorm_srgb = 11,
    rg8_unorm = 30,
    rg8_unorm_srgb = 31,
    rgba8_unorm = 70,
    rgba8_unorm_srgb = 71,
    bgra8_unorm = 80,
    bgra8_unorm_srgb = 81,
    rgb10a2_unorm = 90,
    rgba16_float = 115,
    depth32_float = 252,
    _,
};

pub const TextureType = enum(u32) {
    one_dimensional = 0,
    one_dimensional_array = 1,
    two_dimensional = 2,
    two_dimensional_array = 3,
    two_dimensional_multisample = 4,
    cube = 5,
    cube_array = 6,
    three_dimensional = 7,
    two_dimensional_multisample_array = 8,
    texture_buffer = 9,
};

pub const TextureUsage = packed struct(u32) {
    shader_read: bool = false,
    shader_write: bool = false,
    render_target: bool = false,
    _reserved_3: bool = false,
    pixel_format_view: bool = false,
    shader_atomic: bool = false,
    _reserved: u26 = 0,

    pub fn toRaw(self: TextureUsage) u32 {
        return @bitCast(self);
    }
};

pub const TextureDescriptor = struct {
    texture_type: TextureType = .two_dimensional,
    pixel_format: PixelFormat = .rgba8_unorm,
    width: usize,
    height: usize,
    depth: usize = 1,
    mipmap_level_count: usize = 1,
    sample_count: usize = 1,
    array_length: usize = 1,
    usage: TextureUsage = .{ .shader_read = true },
    storage_mode: resource.StorageMode = .shared,
    cpu_cache_mode: resource.CpuCacheMode = .default_cache,
};

pub const Region = struct {
    x: usize = 0,
    y: usize = 0,
    width: usize,
    height: usize,
};

pub const Texture = struct {
    handle: c.MTLTextureHandle,
    width_value: usize,
    height_value: usize,
    pixel_format: PixelFormat,
    mipmap_level_count: usize,

    pub fn deinit(self: *Texture) void {
        if (self.handle) |handle| {
            c.mtl_release_texture(handle);
            self.handle = null;
        }
    }

    pub fn clone(self: *const Texture) Texture {
        return .{
            .handle = c.mtl_retain_texture(self.requireHandle()),
            .width_value = self.width_value,
            .height_value = self.height_value,
            .pixel_format = self.pixel_format,
            .mipmap_level_count = self.mipmap_level_count,
        };
    }

    pub fn width(self: *const Texture) usize {
        _ = self.requireHandle();
        return self.width_value;
    }

    pub fn height(self: *const Texture) usize {
        _ = self.requireHandle();
        return self.height_value;
    }

    pub fn pixelFormat(self: *const Texture) PixelFormat {
        _ = self.requireHandle();
        return self.pixel_format;
    }

    pub fn replaceRegion(
        self: *const Texture,
        region: Region,
        mipmap_level: usize,
        bytes: []const u8,
        bytes_per_row: usize,
    ) !void {
        if (region.width == 0 or region.height == 0 or bytes_per_row == 0) {
            return error.InvalidTextureRegion;
        }
        if (mipmap_level >= self.mipmap_level_count) {
            return error.InvalidMipmapLevel;
        }
        if (region.x > self.width_value or region.width > self.width_value - region.x or
            region.y > self.height_value or region.height > self.height_value - region.y)
        {
            return error.TextureRegionOutOfBounds;
        }
        const required_bytes = std.math.mul(usize, bytes_per_row, region.height) catch
            return error.TextureDataTooSmall;
        if (bytes.len < required_bytes) {
            return error.TextureDataTooSmall;
        }

        c.mtl_texture_replace_region(
            self.requireHandle(),
            region.x,
            region.y,
            region.width,
            region.height,
            mipmap_level,
            bytes.ptr,
            bytes_per_row,
        );
    }

    pub fn initOwned(handle: c.MTLTextureHandle, mipmap_level_count: usize) Texture {
        const required = handle orelse @panic("cannot initialize Texture from null handle");
        return .{
            .handle = required,
            .width_value = c.mtl_texture_get_width(required),
            .height_value = c.mtl_texture_get_height(required),
            .pixel_format = @enumFromInt(c.mtl_texture_get_pixel_format(required)),
            .mipmap_level_count = mipmap_level_count,
        };
    }

    pub fn requireHandle(self: *const Texture) @typeInfo(c.MTLTextureHandle).optional.child {
        return self.handle orelse @panic("use of deinitialized Metal texture");
    }
};

pub const SamplerMinMagFilter = enum(u32) {
    nearest = 0,
    linear = 1,
};

pub const SamplerMipFilter = enum(u32) {
    nearest = 0,
    linear = 1,
    not_mipmapped = 2,
};

pub const SamplerAddressMode = enum(u32) {
    clamp_to_edge = 0,
    mirror_clamp_to_edge = 1,
    repeat = 2,
    mirror_repeat = 3,
    clamp_to_zero = 4,
    clamp_to_border_color = 5,
};

pub const SamplerDescriptor = struct {
    min_filter: SamplerMinMagFilter = .linear,
    mag_filter: SamplerMinMagFilter = .linear,
    mip_filter: SamplerMipFilter = .not_mipmapped,
    s_address_mode: SamplerAddressMode = .clamp_to_edge,
    t_address_mode: SamplerAddressMode = .clamp_to_edge,
    r_address_mode: SamplerAddressMode = .clamp_to_edge,
    max_anisotropy: usize = 1,
    normalized_coordinates: bool = true,
};

pub const SamplerState = struct {
    handle: c.MTLSamplerStateHandle,

    pub fn deinit(self: *SamplerState) void {
        if (self.handle) |handle| {
            c.mtl_release_sampler_state(handle);
            self.handle = null;
        }
    }

    pub fn clone(self: *const SamplerState) SamplerState {
        return .{ .handle = c.mtl_retain_sampler_state(self.requireHandle()) };
    }

    pub fn initOwned(handle: c.MTLSamplerStateHandle) SamplerState {
        return .{ .handle = handle orelse @panic("cannot initialize SamplerState from null handle") };
    }

    pub fn requireHandle(
        self: *const SamplerState,
    ) @typeInfo(c.MTLSamplerStateHandle).optional.child {
        return self.handle orelse @panic("use of deinitialized Metal sampler state");
    }
};
