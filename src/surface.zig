const c = @import("internal/c.zig").bindings;
const textures = @import("texture.zig");

pub const DrawableSize = struct {
    width: f64,
    height: f64,
};

/// Owns one retain on a CAMetalLayer. Attach `nativeHandle()` to the window
/// using AppKit, SDL, GLFW, or whichever window system owns the view.
pub const MetalLayer = struct {
    handle: c.MTLLayerHandle,

    pub fn create(device_handle: c.MTLDeviceHandle) !MetalLayer {
        const layer = c.mtl_layer_create(device_handle) orelse
            return error.MetalLayerCreationFailed;
        return .{ .handle = layer };
    }

    /// Wraps and retains an existing CAMetalLayer pointer.
    pub fn fromNative(native_layer: *anyopaque) !MetalLayer {
        const layer = c.mtl_layer_from_native(native_layer) orelse
            return error.InvalidMetalLayer;
        return .{ .handle = layer };
    }

    pub fn deinit(self: *MetalLayer) void {
        if (self.handle) |handle| {
            c.mtl_release_layer(handle);
            self.handle = null;
        }
    }

    pub fn clone(self: *const MetalLayer) MetalLayer {
        return .{ .handle = c.mtl_retain_layer(self.requireHandle()) };
    }

    /// Borrowed pointer. It remains valid only while this MetalLayer is alive.
    pub fn nativeHandle(self: *const MetalLayer) *anyopaque {
        return c.mtl_layer_get_native(self.requireHandle()).?;
    }

    pub fn setDevice(self: *const MetalLayer, device_handle: c.MTLDeviceHandle) void {
        c.mtl_layer_set_device(self.requireHandle(), device_handle);
    }

    pub fn setPixelFormat(self: *const MetalLayer, pixel_format: textures.PixelFormat) void {
        c.mtl_layer_set_pixel_format(self.requireHandle(), @intFromEnum(pixel_format));
    }

    pub fn pixelFormat(self: *const MetalLayer) textures.PixelFormat {
        return @enumFromInt(c.mtl_layer_get_pixel_format(self.requireHandle()));
    }

    pub fn setDrawableSize(self: *const MetalLayer, size: DrawableSize) !void {
        if (size.width <= 0 or size.height <= 0) {
            return error.InvalidDrawableSize;
        }
        c.mtl_layer_set_drawable_size(self.requireHandle(), size.width, size.height);
    }

    pub fn setFramebufferOnly(self: *const MetalLayer, framebuffer_only: bool) void {
        c.mtl_layer_set_framebuffer_only(self.requireHandle(), framebuffer_only);
    }

    pub fn setDisplaySyncEnabled(self: *const MetalLayer, enabled: bool) void {
        c.mtl_layer_set_display_sync_enabled(self.requireHandle(), enabled);
    }

    pub fn nextDrawable(self: *const MetalLayer) !Drawable {
        const drawable = c.mtl_layer_next_drawable(self.requireHandle()) orelse
            return error.NoDrawableAvailable;
        return .{ .handle = drawable };
    }

    pub fn requireHandle(self: *const MetalLayer) @typeInfo(c.MTLLayerHandle).optional.child {
        return self.handle orelse @panic("use of deinitialized CAMetalLayer");
    }
};

pub const Drawable = struct {
    handle: c.MTLDrawableHandle,

    pub fn deinit(self: *Drawable) void {
        if (self.handle) |handle| {
            c.mtl_release_drawable(handle);
            self.handle = null;
        }
    }

    pub fn clone(self: *const Drawable) Drawable {
        return .{ .handle = c.mtl_retain_drawable(self.requireHandle()) };
    }

    /// Returns an independently owned texture for this drawable.
    pub fn texture(self: *const Drawable) !textures.Texture {
        const owned_texture = c.mtl_drawable_copy_texture(self.requireHandle()) orelse
            return error.DrawableTextureUnavailable;
        return textures.Texture.initOwned(owned_texture, 1);
    }

    pub fn requireHandle(self: *const Drawable) @typeInfo(c.MTLDrawableHandle).optional.child {
        return self.handle orelse @panic("use of deinitialized Metal drawable");
    }
};
