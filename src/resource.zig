const c = @import("internal/c.zig").bindings;

pub const CpuCacheMode = enum(u1) {
    default_cache = 0,
    write_combined = 1,
};

pub const StorageMode = enum(u2) {
    shared = 0,
    managed = 1,
    private = 2,
    memoryless = 3,
};

pub const HazardTrackingMode = enum(u2) {
    default = 0,
    untracked = 1,
    tracked = 2,
};

pub const ResourceOptions = struct {
    cpu_cache_mode: CpuCacheMode = .default_cache,
    storage_mode: StorageMode = .shared,
    hazard_tracking_mode: HazardTrackingMode = .default,

    pub fn toRaw(self: ResourceOptions) usize {
        return @as(usize, @intFromEnum(self.cpu_cache_mode)) |
            (@as(usize, @intFromEnum(self.storage_mode)) << 4) |
            (@as(usize, @intFromEnum(self.hazard_tracking_mode)) << 8);
    }
};

pub const BufferContentsError = error{
    BufferContentsUnavailable,
    ZeroSizedElement,
    BufferLengthNotMultipleOfElementSize,
    MisalignedBufferContents,
};

pub const BufferRangeError = error{
    InvalidStorageMode,
    InvalidRange,
};

pub const Buffer = struct {
    handle: c.MTLBufferHandle,
    length: usize,
    storage_mode: StorageMode,

    pub fn deinit(self: *Buffer) void {
        if (self.handle) |handle| {
            c.mtl_release_buffer(handle);
            self.handle = null;
        }
    }

    pub fn clone(self: *const Buffer) Buffer {
        const handle = self.requireHandle();
        return .{
            .handle = c.mtl_retain_buffer(handle),
            .length = self.length,
            .storage_mode = self.storage_mode,
        };
    }

    pub fn len(self: *const Buffer) usize {
        _ = self.requireHandle();
        return self.length;
    }

    pub fn storageMode(self: *const Buffer) StorageMode {
        _ = self.requireHandle();
        return self.storage_mode;
    }

    /// Returns buffer contents as a slice of bytes
    pub fn contents(self: *const Buffer) ?[]u8 {
        const raw = c.mtl_buffer_get_contents(self.requireHandle()) orelse return null;
        const ptr: [*]u8 = @ptrCast(raw);
        return ptr[0..self.length];
    }

    /// Returns buffer contents as a slice of `T`'s
    pub fn contentsAs(self: *const Buffer, comptime T: type) BufferContentsError![]T {
        if (@sizeOf(T) == 0) {
            return error.ZeroSizedElement;
        }

        const bytes = self.contents() orelse return error.BufferContentsUnavailable;
        if (bytes.len % @sizeOf(T) != 0) {
            return error.BufferLengthNotMultipleOfElementSize;
        }
        if (@intFromPtr(bytes.ptr) % @alignOf(T) != 0) {
            return error.MisalignedBufferContents;
        }

        const ptr: [*]T = @ptrCast(@alignCast(bytes.ptr));
        return ptr[0 .. bytes.len / @sizeOf(T)];
    }

    pub fn didModifyRange(self: *const Buffer, offset: usize, length: usize) BufferRangeError!void {
        if (self.storageMode() != .managed) {
            return error.InvalidStorageMode;
        }
        if (offset > self.length or length > self.length - offset) {
            return error.InvalidRange;
        }
        c.mtl_buffer_did_modify_range(self.requireHandle(), offset, length);
    }

    fn init(
        handle: c.MTLBufferHandle,
        length: usize,
        storage_mode: StorageMode,
    ) Buffer {
        return .{
            .handle = handle,
            .length = length,
            .storage_mode = storage_mode,
        };
    }

    fn requireHandle(self: *const Buffer) c.MTLBufferHandle {
        return self.handle orelse @panic("use of deinitialized Metal buffer");
    }
};
