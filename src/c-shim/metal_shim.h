#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Distinct incomplete types keep handles type-safe at the C boundary while
 * still allowing the Objective-C implementation to bridge Metal objects.
 */
typedef struct MetalZigDevice* MTLDeviceHandle;
typedef struct MetalZigCommandQueue* MTLCommandQueueHandle;
typedef struct MetalZigCommandBuffer* MTLCommandBufferHandle;
typedef struct MetalZigLibrary* MTLLibraryHandle;
typedef struct MetalZigFunction* MTLFunctionHandle;
typedef struct MetalZigComputePipelineState* MTLComputePipelineStateHandle;
typedef struct MetalZigRenderPipelineState* MTLRenderPipelineStateHandle;
typedef struct MetalZigBuffer* MTLBufferHandle;
typedef struct MetalZigTexture* MTLTextureHandle;
typedef struct MetalZigSamplerState* MTLSamplerStateHandle;
typedef struct MetalZigComputeCommandEncoder* MTLComputeCommandEncoderHandle;
typedef struct MetalZigRenderCommandEncoder* MTLRenderCommandEncoderHandle;
typedef struct MetalZigLayer* MTLLayerHandle;
typedef struct MetalZigDrawable* MTLDrawableHandle;

typedef struct {
  uint32_t format;
  size_t offset;
  size_t buffer_index;
} MTLZVertexAttributeDescriptor;

typedef struct {
  size_t stride;
  uint32_t step_function;
  size_t step_rate;
} MTLZVertexBufferLayoutDescriptor;

typedef struct {
  MTLFunctionHandle vertex_function;
  MTLFunctionHandle fragment_function;
  const MTLZVertexAttributeDescriptor* vertex_attributes;
  size_t vertex_attribute_count;
  const MTLZVertexBufferLayoutDescriptor* vertex_layouts;
  size_t vertex_layout_count;
  uint32_t color_pixel_format;
  bool blending_enabled;
  uint32_t source_rgb_blend_factor;
  uint32_t destination_rgb_blend_factor;
  uint32_t rgb_blend_operation;
  uint32_t source_alpha_blend_factor;
  uint32_t destination_alpha_blend_factor;
  uint32_t alpha_blend_operation;
  uint32_t color_write_mask;
  size_t sample_count;
} MTLZRenderPipelineDescriptor;

typedef struct {
  size_t width;
  size_t height;
  size_t depth;
  size_t mipmap_level_count;
  size_t sample_count;
  size_t array_length;
  uint32_t texture_type;
  uint32_t pixel_format;
  uint32_t usage;
  uint32_t storage_mode;
  uint32_t cpu_cache_mode;
} MTLZTextureDescriptor;

typedef struct {
  uint32_t min_filter;
  uint32_t mag_filter;
  uint32_t mip_filter;
  uint32_t s_address_mode;
  uint32_t t_address_mode;
  uint32_t r_address_mode;
  size_t max_anisotropy;
  bool normalized_coordinates;
} MTLZSamplerDescriptor;

typedef struct {
  MTLTextureHandle color_texture;
  uint32_t load_action;
  uint32_t store_action;
  double clear_red;
  double clear_green;
  double clear_blue;
  double clear_alpha;
} MTLZRenderPassDescriptor;

typedef void (*MTLCommandBufferCompletionCallback)(void* context, uint32_t status);

typedef struct {
  int64_t code;
  char* domain;
  char* message;
} MTLErrorInfo;

typedef struct {
  MTLDeviceHandle* devices;
  size_t count;
} MTLDeviceList;

void mtl_error_info_clear(MTLErrorInfo* error_info);
void mtl_free(void* ptr);

MTLDeviceHandle mtl_create_system_default_device(void);
MTLDeviceList mtl_copy_all_devices(void);
void mtl_release_device(MTLDeviceHandle device);
MTLDeviceHandle mtl_retain_device(MTLDeviceHandle device);
size_t mtl_get_device_name(MTLDeviceHandle device, char* buffer, size_t buffer_size);

MTLCommandQueueHandle mtl_new_command_queue(MTLDeviceHandle device);
void mtl_release_command_queue(MTLCommandQueueHandle queue);
MTLCommandQueueHandle mtl_retain_command_queue(MTLCommandQueueHandle queue);

MTLLibraryHandle mtl_new_library_with_file(MTLDeviceHandle device,
                                           const char* path,
                                           size_t path_length,
                                           MTLErrorInfo* error_info);
MTLLibraryHandle mtl_new_library_with_data(MTLDeviceHandle device,
                                           const void* data,
                                           size_t data_length,
                                           MTLErrorInfo* error_info);
MTLLibraryHandle mtl_new_library_with_source(MTLDeviceHandle device,
                                             const char* source,
                                             size_t source_length,
                                             MTLErrorInfo* error_info);
void mtl_release_library(MTLLibraryHandle library);
MTLLibraryHandle mtl_retain_library(MTLLibraryHandle library);

MTLFunctionHandle mtl_new_function_with_name(MTLLibraryHandle library,
                                             const char* name,
                                             size_t name_length);
void mtl_release_function(MTLFunctionHandle function);
MTLFunctionHandle mtl_retain_function(MTLFunctionHandle function);

MTLComputePipelineStateHandle mtl_new_compute_pipeline_state_with_function(
    MTLDeviceHandle device,
    MTLFunctionHandle function,
    MTLErrorInfo* error_info);
void mtl_release_compute_pipeline_state(MTLComputePipelineStateHandle pipeline_state);
MTLComputePipelineStateHandle mtl_retain_compute_pipeline_state(
    MTLComputePipelineStateHandle pipeline_state);
size_t mtl_get_max_total_threads_per_threadgroup(
    MTLComputePipelineStateHandle pipeline_state);
size_t mtl_get_thread_execution_width(MTLComputePipelineStateHandle pipeline_state);

MTLRenderPipelineStateHandle mtl_new_render_pipeline_state(
    MTLDeviceHandle device,
    const MTLZRenderPipelineDescriptor* descriptor,
    MTLErrorInfo* error_info);
void mtl_release_render_pipeline_state(MTLRenderPipelineStateHandle pipeline_state);
MTLRenderPipelineStateHandle mtl_retain_render_pipeline_state(
    MTLRenderPipelineStateHandle pipeline_state);

MTLBufferHandle mtl_new_buffer_with_length(MTLDeviceHandle device,
                                           size_t length,
                                           size_t options);
void* mtl_buffer_get_contents(MTLBufferHandle buffer);
size_t mtl_buffer_get_length(MTLBufferHandle buffer);
void mtl_buffer_did_modify_range(MTLBufferHandle buffer, size_t offset, size_t length);
void mtl_release_buffer(MTLBufferHandle buffer);
MTLBufferHandle mtl_retain_buffer(MTLBufferHandle buffer);

MTLTextureHandle mtl_new_texture(MTLDeviceHandle device,
                                 const MTLZTextureDescriptor* descriptor);
void mtl_texture_replace_region(MTLTextureHandle texture,
                                size_t x,
                                size_t y,
                                size_t width,
                                size_t height,
                                size_t mipmap_level,
                                const void* bytes,
                                size_t bytes_per_row);
size_t mtl_texture_get_width(MTLTextureHandle texture);
size_t mtl_texture_get_height(MTLTextureHandle texture);
uint32_t mtl_texture_get_pixel_format(MTLTextureHandle texture);
void mtl_release_texture(MTLTextureHandle texture);
MTLTextureHandle mtl_retain_texture(MTLTextureHandle texture);

MTLSamplerStateHandle mtl_new_sampler_state(
    MTLDeviceHandle device,
    const MTLZSamplerDescriptor* descriptor);
void mtl_release_sampler_state(MTLSamplerStateHandle sampler);
MTLSamplerStateHandle mtl_retain_sampler_state(MTLSamplerStateHandle sampler);

MTLCommandBufferHandle mtl_new_command_buffer(MTLCommandQueueHandle queue);
void mtl_release_command_buffer(MTLCommandBufferHandle command_buffer);
MTLCommandBufferHandle mtl_retain_command_buffer(MTLCommandBufferHandle command_buffer);
void mtl_command_buffer_commit(MTLCommandBufferHandle command_buffer);
bool mtl_command_buffer_wait_until_completed(MTLCommandBufferHandle command_buffer,
                                             MTLErrorInfo* error_info);
uint32_t mtl_command_buffer_get_status(MTLCommandBufferHandle command_buffer);
void mtl_command_buffer_add_completed_handler(
    MTLCommandBufferHandle command_buffer,
    MTLCommandBufferCompletionCallback callback,
    void* context);
void mtl_command_buffer_present_drawable(MTLCommandBufferHandle command_buffer,
                                         MTLDrawableHandle drawable);

MTLComputeCommandEncoderHandle mtl_new_compute_command_encoder(
    MTLCommandBufferHandle command_buffer);
void mtl_release_compute_command_encoder(MTLComputeCommandEncoderHandle encoder);
MTLComputeCommandEncoderHandle mtl_retain_compute_command_encoder(
    MTLComputeCommandEncoderHandle encoder);
void mtl_end_encoding(MTLComputeCommandEncoderHandle encoder);
void mtl_enc_set_compute_pipeline_state(
    MTLComputeCommandEncoderHandle encoder,
    MTLComputePipelineStateHandle pipeline_state);
void mtl_enc_set_buffer(MTLComputeCommandEncoderHandle encoder,
                        MTLBufferHandle buffer,
                        size_t offset,
                        size_t index);
void mtl_enc_set_bytes(MTLComputeCommandEncoderHandle encoder,
                       size_t index,
                       size_t length,
                       const void* bytes);
void mtl_enc_dispatch_threads(MTLComputeCommandEncoderHandle encoder,
                              size_t threads_per_grid_width,
                              size_t threads_per_grid_height,
                              size_t threads_per_grid_depth,
                              size_t threads_per_threadgroup_width,
                              size_t threads_per_threadgroup_height,
                              size_t threads_per_threadgroup_depth);

MTLRenderCommandEncoderHandle mtl_new_render_command_encoder(
    MTLCommandBufferHandle command_buffer,
    const MTLZRenderPassDescriptor* descriptor);
void mtl_release_render_command_encoder(MTLRenderCommandEncoderHandle encoder);
MTLRenderCommandEncoderHandle mtl_retain_render_command_encoder(
    MTLRenderCommandEncoderHandle encoder);
void mtl_render_enc_end_encoding(MTLRenderCommandEncoderHandle encoder);
void mtl_render_enc_set_pipeline_state(MTLRenderCommandEncoderHandle encoder,
                                       MTLRenderPipelineStateHandle pipeline_state);
void mtl_render_enc_set_vertex_buffer(MTLRenderCommandEncoderHandle encoder,
                                      MTLBufferHandle buffer,
                                      size_t offset,
                                      size_t index);
void mtl_render_enc_set_vertex_bytes(MTLRenderCommandEncoderHandle encoder,
                                     size_t index,
                                     size_t length,
                                     const void* bytes);
void mtl_render_enc_set_fragment_buffer(MTLRenderCommandEncoderHandle encoder,
                                        MTLBufferHandle buffer,
                                        size_t offset,
                                        size_t index);
void mtl_render_enc_set_fragment_bytes(MTLRenderCommandEncoderHandle encoder,
                                       size_t index,
                                       size_t length,
                                       const void* bytes);
void mtl_render_enc_set_fragment_texture(MTLRenderCommandEncoderHandle encoder,
                                         MTLTextureHandle texture,
                                         size_t index);
void mtl_render_enc_set_fragment_sampler(MTLRenderCommandEncoderHandle encoder,
                                         MTLSamplerStateHandle sampler,
                                         size_t index);
void mtl_render_enc_set_viewport(MTLRenderCommandEncoderHandle encoder,
                                 double origin_x,
                                 double origin_y,
                                 double width,
                                 double height,
                                 double znear,
                                 double zfar);
void mtl_render_enc_set_scissor_rect(MTLRenderCommandEncoderHandle encoder,
                                     size_t x,
                                     size_t y,
                                     size_t width,
                                     size_t height);
void mtl_render_enc_draw_primitives(MTLRenderCommandEncoderHandle encoder,
                                    uint32_t primitive_type,
                                    size_t vertex_start,
                                    size_t vertex_count,
                                    size_t instance_count);
void mtl_render_enc_draw_indexed_primitives(
    MTLRenderCommandEncoderHandle encoder,
    uint32_t primitive_type,
    size_t index_count,
    uint32_t index_type,
    MTLBufferHandle index_buffer,
    size_t index_buffer_offset,
    size_t instance_count);

MTLLayerHandle mtl_layer_create(MTLDeviceHandle device);
MTLLayerHandle mtl_layer_from_native(void* native_layer);
void* mtl_layer_get_native(MTLLayerHandle layer);
void mtl_layer_set_device(MTLLayerHandle layer, MTLDeviceHandle device);
void mtl_layer_set_pixel_format(MTLLayerHandle layer, uint32_t pixel_format);
uint32_t mtl_layer_get_pixel_format(MTLLayerHandle layer);
void mtl_layer_set_drawable_size(MTLLayerHandle layer, double width, double height);
void mtl_layer_set_framebuffer_only(MTLLayerHandle layer, bool framebuffer_only);
void mtl_layer_set_display_sync_enabled(MTLLayerHandle layer, bool enabled);
MTLDrawableHandle mtl_layer_next_drawable(MTLLayerHandle layer);
void mtl_release_layer(MTLLayerHandle layer);
MTLLayerHandle mtl_retain_layer(MTLLayerHandle layer);

MTLTextureHandle mtl_drawable_copy_texture(MTLDrawableHandle drawable);
void mtl_release_drawable(MTLDrawableHandle drawable);
MTLDrawableHandle mtl_retain_drawable(MTLDrawableHandle drawable);

#ifdef __cplusplus
}
#endif
