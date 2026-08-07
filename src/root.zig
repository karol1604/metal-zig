pub const ErrorInfo = @import("error_info.zig").ErrorInfo;

const resource = @import("resource.zig");
pub const Buffer = resource.Buffer;
pub const BufferContentsError = resource.BufferContentsError;
pub const BufferRangeError = resource.BufferRangeError;
pub const CpuCacheMode = resource.CpuCacheMode;
pub const StorageMode = resource.StorageMode;
pub const HazardTrackingMode = resource.HazardTrackingMode;
pub const ResourceOptions = resource.ResourceOptions;

const texture = @import("texture.zig");
pub const PixelFormat = texture.PixelFormat;
pub const TextureType = texture.TextureType;
pub const TextureUsage = texture.TextureUsage;
pub const TextureDescriptor = texture.TextureDescriptor;
pub const TextureRegion = texture.Region;
pub const Texture = texture.Texture;
pub const SamplerMinMagFilter = texture.SamplerMinMagFilter;
pub const SamplerMipFilter = texture.SamplerMipFilter;
pub const SamplerAddressMode = texture.SamplerAddressMode;
pub const SamplerDescriptor = texture.SamplerDescriptor;
pub const SamplerState = texture.SamplerState;

const library = @import("library.zig");
pub const Function = library.Function;
pub const Library = library.Library;
pub const ComputePipelineState = library.ComputePipelineState;

const render = @import("render.zig");
pub const VertexFormat = render.VertexFormat;
pub const VertexStepFunction = render.VertexStepFunction;
pub const VertexAttributeDescriptor = render.VertexAttributeDescriptor;
pub const VertexBufferLayoutDescriptor = render.VertexBufferLayoutDescriptor;
pub const VertexDescriptor = render.VertexDescriptor;
pub const BlendFactor = render.BlendFactor;
pub const BlendOperation = render.BlendOperation;
pub const ColorWriteMask = render.ColorWriteMask;
pub const ColorAttachmentDescriptor = render.ColorAttachmentDescriptor;
pub const RenderPipelineDescriptor = render.RenderPipelineDescriptor;
pub const RenderPipelineState = render.RenderPipelineState;
pub const LoadAction = render.LoadAction;
pub const StoreAction = render.StoreAction;
pub const ClearColor = render.ClearColor;
pub const RenderPassDescriptor = render.RenderPassDescriptor;
pub const Viewport = render.Viewport;
pub const ScissorRect = render.ScissorRect;
pub const PrimitiveType = render.PrimitiveType;
pub const IndexType = render.IndexType;

const commands = @import("commands.zig");
pub const Size = commands.Size;
pub const MTLSize = Size;
pub const ComputeCommandEncoder = commands.ComputeCommandEncoder;
pub const RenderCommandEncoder = commands.RenderCommandEncoder;
pub const CommandBufferStatus = commands.CommandBufferStatus;
pub const CommandBufferCompletionFn = commands.CommandBufferCompletionFn;
pub const CommandBuffer = commands.CommandBuffer;
pub const CommandQueue = commands.CommandQueue;

const surface = @import("surface.zig");
pub const DrawableSize = surface.DrawableSize;
pub const MetalLayer = surface.MetalLayer;
pub const Drawable = surface.Drawable;

const device = @import("device.zig");
pub const Device = device.Device;
pub const DeviceList = device.DeviceList;
