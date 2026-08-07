const std = @import("std");
const c = @import("internal/c.zig").bindings;

/// Owns one retain on an MTLFunction.
pub const Function = struct {
    handle: c.MTLFunctionHandle,

    pub fn deinit(self: *Function) void {
        if (self.handle) |handle| {
            c.mtl_release_function(handle);
            self.handle = null;
        }
    }

    pub fn clone(self: *const Function) Function {
        return .{ .handle = c.mtl_retain_function(self.requireHandle()) };
    }

    fn init(handle: c.MTLFunctionHandle) Function {
        return .{ .handle = handle };
    }

    fn requireHandle(
        self: *const Function,
    ) @typeInfo(c.MTLFunctionHandle).optional.child {
        return self.handle orelse @panic("use of deinitialized Metal function");
    }
};

pub const Library = struct {
    handle: c.MTLLibraryHandle,

    pub fn deinit(self: *Library) void {
        if (self.handle) |handle| {
            c.mtl_release_library(handle);
            self.handle = null;
        }
    }

    pub fn clone(self: *const Library) Library {
        return .{ .handle = c.mtl_retain_library(self.requireHandle()) };
    }

    pub fn newFunctionWithName(self: *const Library, name: []const u8) !Function {
        if (name.len == 0) {
            return error.InvalidFunctionName;
        }
        if (!std.unicode.utf8ValidateSlice(name) or
            std.mem.indexOfScalar(u8, name, 0) != null)
        {
            return error.InvalidFunctionName;
        }
        const function =
            c.mtl_new_function_with_name(self.requireHandle(), name.ptr, name.len) orelse
            return error.FunctionCreationFailed;
        return Function.init(function);
    }

    fn init(handle: c.MTLLibraryHandle) Library {
        return .{ .handle = handle };
    }

    fn requireHandle(
        self: *const Library,
    ) @typeInfo(c.MTLLibraryHandle).optional.child {
        return self.handle orelse @panic("use of deinitialized Metal library");
    }
};

pub const ComputePipelineState = struct {
    handle: c.MTLComputePipelineStateHandle,

    pub fn deinit(self: *ComputePipelineState) void {
        if (self.handle) |handle| {
            c.mtl_release_compute_pipeline_state(handle);
            self.handle = null;
        }
    }

    pub fn clone(self: *const ComputePipelineState) ComputePipelineState {
        return .{
            .handle = c.mtl_retain_compute_pipeline_state(self.requireHandle()),
        };
    }

    pub fn maxTotalThreadsPerThreadgroup(self: *const ComputePipelineState) usize {
        return c.mtl_get_max_total_threads_per_threadgroup(self.requireHandle());
    }

    pub fn threadExecutionWidth(self: *const ComputePipelineState) usize {
        return c.mtl_get_thread_execution_width(self.requireHandle());
    }

    pub fn getMaxTotalThreadsPerThreadgroup(self: *const ComputePipelineState) usize {
        return self.maxTotalThreadsPerThreadgroup();
    }

    fn init(handle: c.MTLComputePipelineStateHandle) ComputePipelineState {
        return .{ .handle = handle };
    }

    fn requireHandle(
        self: *const ComputePipelineState,
    ) @typeInfo(c.MTLComputePipelineStateHandle).optional.child {
        return self.handle orelse @panic("use of deinitialized Metal compute pipeline");
    }
};
