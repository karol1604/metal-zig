const std = @import("std");
const c = @import("internal/c.zig").bindings;

pub const ErrorInfo = extern struct {
    code: i64,
    domain_ptr: ?[*:0]u8,
    message_ptr: ?[*:0]u8,

    pub fn init() ErrorInfo {
        return .{
            .code = 0,
            .domain_ptr = null,
            .message_ptr = null,
        };
    }

    pub fn deinit(self: *ErrorInfo) void {
        self.clear();
    }

    pub fn clear(self: *ErrorInfo) void {
        c.mtl_error_info_clear(@ptrCast(self));
        self.* = init();
    }

    pub fn domain(self: *const ErrorInfo) []const u8 {
        const ptr = self.domain_ptr orelse return "";
        return std.mem.span(ptr);
    }

    pub fn message(self: *const ErrorInfo) []const u8 {
        const ptr = self.message_ptr orelse return "";
        return std.mem.span(ptr);
    }
};

comptime {
    if (@sizeOf(ErrorInfo) != @sizeOf(c.MTLErrorInfo) or
        @alignOf(ErrorInfo) != @alignOf(c.MTLErrorInfo) or
        @offsetOf(ErrorInfo, "code") != @offsetOf(c.MTLErrorInfo, "code") or
        @offsetOf(ErrorInfo, "domain_ptr") != @offsetOf(c.MTLErrorInfo, "domain") or
        @offsetOf(ErrorInfo, "message_ptr") != @offsetOf(c.MTLErrorInfo, "message"))
    {
        @compileError("ErrorInfo must remain ABI-compatible with MTLErrorInfo");
    }
}
