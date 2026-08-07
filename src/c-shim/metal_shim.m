#import "metal_shim.h"

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <dispatch/dispatch.h>

#include <stdlib.h>
#include <string.h>

static void mtl_set_error_info(MTLErrorInfo* error_info, NSError* error) {
  if (error_info == NULL) {
    return;
  }

  mtl_error_info_clear(error_info);
  if (error == nil) {
    return;
  }

  error_info->code = (int64_t)error.code;

  const char* domain = error.domain.UTF8String;
  if (domain != NULL) {
    error_info->domain = strdup(domain);
  }

  const char* message = error.localizedDescription.UTF8String;
  if (message != NULL) {
    error_info->message = strdup(message);
  }
}

static NSString* mtl_string_from_utf8(const char* bytes, size_t length) {
  if (bytes == NULL) {
    return nil;
  }

  return [[NSString alloc] initWithBytes:bytes
                                 length:length
                               encoding:NSUTF8StringEncoding];
}

void mtl_error_info_clear(MTLErrorInfo* error_info) {
  if (error_info == NULL) {
    return;
  }

  free(error_info->domain);
  free(error_info->message);
  error_info->code = 0;
  error_info->domain = NULL;
  error_info->message = NULL;
}

void mtl_free(void* ptr) {
  free(ptr);
}

MTLDeviceHandle mtl_create_system_default_device(void) {
  @autoreleasepool {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    return (__bridge_retained MTLDeviceHandle)device;
  }
}

MTLDeviceList mtl_copy_all_devices(void) {
  @autoreleasepool {
    NSArray<id<MTLDevice>>* devices = MTLCopyAllDevices();
    const size_t count = devices.count;
    if (count == 0) {
      return (MTLDeviceList){.devices = NULL, .count = 0};
    }

    MTLDeviceHandle* handles = calloc(count, sizeof(*handles));
    if (handles == NULL) {
      return (MTLDeviceList){.devices = NULL, .count = 0};
    }

    for (size_t index = 0; index < count; ++index) {
      handles[index] = (__bridge_retained MTLDeviceHandle)devices[index];
    }

    return (MTLDeviceList){.devices = handles, .count = count};
  }
}

void mtl_release_device(MTLDeviceHandle device) {
  if (device != NULL) {
    CFRelease(device);
  }
}

MTLDeviceHandle mtl_retain_device(MTLDeviceHandle device) {
  if (device != NULL) {
    CFRetain(device);
  }
  return device;
}

size_t mtl_get_device_name(MTLDeviceHandle device, char* buffer, size_t buffer_size) {
  @autoreleasepool {
    if (device == NULL) {
      return 0;
    }

    id<MTLDevice> metal_device = (__bridge id<MTLDevice>)device;
    NSData* utf8 = [metal_device.name dataUsingEncoding:NSUTF8StringEncoding];
    const size_t length = utf8.length;

    if (buffer != NULL && buffer_size >= length) {
      memcpy(buffer, utf8.bytes, length);
    }
    return length;
  }
}

MTLCommandQueueHandle mtl_new_command_queue(MTLDeviceHandle device) {
  @autoreleasepool {
    if (device == NULL) {
      return NULL;
    }
    id<MTLDevice> metal_device = (__bridge id<MTLDevice>)device;
    id<MTLCommandQueue> queue = [metal_device newCommandQueue];
    return (__bridge_retained MTLCommandQueueHandle)queue;
  }
}

void mtl_release_command_queue(MTLCommandQueueHandle queue) {
  if (queue != NULL) {
    CFRelease(queue);
  }
}

MTLCommandQueueHandle mtl_retain_command_queue(MTLCommandQueueHandle queue) {
  if (queue != NULL) {
    CFRetain(queue);
  }
  return queue;
}

MTLLibraryHandle mtl_new_library_with_file(MTLDeviceHandle device,
                                           const char* path,
                                           size_t path_length,
                                           MTLErrorInfo* error_info) {
  @autoreleasepool {
    if (error_info != NULL) {
      mtl_error_info_clear(error_info);
    }
    if (device == NULL || path == NULL) {
      return NULL;
    }

    NSString* file_path = mtl_string_from_utf8(path, path_length);
    if (file_path == nil) {
      return NULL;
    }

    NSURL* file_url = [NSURL fileURLWithPath:file_path];
    NSError* error = nil;
    id<MTLDevice> metal_device = (__bridge id<MTLDevice>)device;
    id<MTLLibrary> library = [metal_device newLibraryWithURL:file_url error:&error];
    if (library == nil) {
      mtl_set_error_info(error_info, error);
      return NULL;
    }

    return (__bridge_retained MTLLibraryHandle)library;
  }
}

MTLLibraryHandle mtl_new_library_with_data(MTLDeviceHandle device,
                                           const void* data,
                                           size_t data_length,
                                           MTLErrorInfo* error_info) {
  @autoreleasepool {
    if (error_info != NULL) {
      mtl_error_info_clear(error_info);
    }
    if (device == NULL || data == NULL || data_length == 0) {
      return NULL;
    }

    void* owned_data = malloc(data_length);
    if (owned_data == NULL) {
      return NULL;
    }
    memcpy(owned_data, data, data_length);

    dispatch_data_t dispatch_data = dispatch_data_create(
        owned_data, data_length, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0),
        DISPATCH_DATA_DESTRUCTOR_FREE);
    if (dispatch_data == nil) {
      free(owned_data);
      return NULL;
    }

    NSError* error = nil;
    id<MTLDevice> metal_device = (__bridge id<MTLDevice>)device;
    id<MTLLibrary> library = [metal_device newLibraryWithData:dispatch_data error:&error];
    if (library == nil) {
      mtl_set_error_info(error_info, error);
      return NULL;
    }

    return (__bridge_retained MTLLibraryHandle)library;
  }
}

MTLLibraryHandle mtl_new_library_with_source(MTLDeviceHandle device,
                                             const char* source,
                                             size_t source_length,
                                             MTLErrorInfo* error_info) {
  @autoreleasepool {
    if (error_info != NULL) {
      mtl_error_info_clear(error_info);
    }
    if (device == NULL || source == NULL) {
      return NULL;
    }

    NSString* source_string = mtl_string_from_utf8(source, source_length);
    if (source_string == nil) {
      return NULL;
    }

    NSError* error = nil;
    id<MTLDevice> metal_device = (__bridge id<MTLDevice>)device;
    id<MTLLibrary> library =
        [metal_device newLibraryWithSource:source_string options:nil error:&error];
    if (library == nil) {
      mtl_set_error_info(error_info, error);
      return NULL;
    }

    return (__bridge_retained MTLLibraryHandle)library;
  }
}

void mtl_release_library(MTLLibraryHandle library) {
  if (library != NULL) {
    CFRelease(library);
  }
}

MTLLibraryHandle mtl_retain_library(MTLLibraryHandle library) {
  if (library != NULL) {
    CFRetain(library);
  }
  return library;
}

MTLFunctionHandle mtl_new_function_with_name(MTLLibraryHandle library,
                                             const char* name,
                                             size_t name_length) {
  @autoreleasepool {
    if (library == NULL || name == NULL) {
      return NULL;
    }

    NSString* function_name = mtl_string_from_utf8(name, name_length);
    if (function_name == nil) {
      return NULL;
    }

    id<MTLLibrary> metal_library = (__bridge id<MTLLibrary>)library;
    id<MTLFunction> function = [metal_library newFunctionWithName:function_name];
    return (__bridge_retained MTLFunctionHandle)function;
  }
}

void mtl_release_function(MTLFunctionHandle function) {
  if (function != NULL) {
    CFRelease(function);
  }
}

MTLFunctionHandle mtl_retain_function(MTLFunctionHandle function) {
  if (function != NULL) {
    CFRetain(function);
  }
  return function;
}

MTLComputePipelineStateHandle mtl_new_compute_pipeline_state_with_function(
    MTLDeviceHandle device,
    MTLFunctionHandle function,
    MTLErrorInfo* error_info) {
  @autoreleasepool {
    if (error_info != NULL) {
      mtl_error_info_clear(error_info);
    }
    if (device == NULL || function == NULL) {
      return NULL;
    }

    NSError* error = nil;
    id<MTLDevice> metal_device = (__bridge id<MTLDevice>)device;
    id<MTLFunction> metal_function = (__bridge id<MTLFunction>)function;
    id<MTLComputePipelineState> pipeline =
        [metal_device newComputePipelineStateWithFunction:metal_function error:&error];
    if (pipeline == nil) {
      mtl_set_error_info(error_info, error);
      return NULL;
    }

    return (__bridge_retained MTLComputePipelineStateHandle)pipeline;
  }
}

void mtl_release_compute_pipeline_state(MTLComputePipelineStateHandle pipeline_state) {
  if (pipeline_state != NULL) {
    CFRelease(pipeline_state);
  }
}

MTLComputePipelineStateHandle mtl_retain_compute_pipeline_state(
    MTLComputePipelineStateHandle pipeline_state) {
  if (pipeline_state != NULL) {
    CFRetain(pipeline_state);
  }
  return pipeline_state;
}

size_t mtl_get_max_total_threads_per_threadgroup(
    MTLComputePipelineStateHandle pipeline_state) {
  if (pipeline_state == NULL) {
    return 0;
  }
  id<MTLComputePipelineState> pipeline =
      (__bridge id<MTLComputePipelineState>)pipeline_state;
  return pipeline.maxTotalThreadsPerThreadgroup;
}

size_t mtl_get_thread_execution_width(MTLComputePipelineStateHandle pipeline_state) {
  if (pipeline_state == NULL) {
    return 0;
  }
  id<MTLComputePipelineState> pipeline =
      (__bridge id<MTLComputePipelineState>)pipeline_state;
  return pipeline.threadExecutionWidth;
}

MTLRenderPipelineStateHandle mtl_new_render_pipeline_state(
    MTLDeviceHandle device,
    const MTLZRenderPipelineDescriptor* descriptor,
    MTLErrorInfo* error_info) {
  @autoreleasepool {
    if (error_info != NULL) {
      mtl_error_info_clear(error_info);
    }
    if (device == NULL || descriptor == NULL ||
        descriptor->vertex_function == NULL ||
        descriptor->fragment_function == NULL) {
      return NULL;
    }

    MTLRenderPipelineDescriptor* pipeline_descriptor =
        [[MTLRenderPipelineDescriptor alloc] init];
    pipeline_descriptor.vertexFunction =
        (__bridge id<MTLFunction>)descriptor->vertex_function;
    pipeline_descriptor.fragmentFunction =
        (__bridge id<MTLFunction>)descriptor->fragment_function;
    pipeline_descriptor.sampleCount = descriptor->sample_count;

    if (descriptor->vertex_attribute_count != 0 ||
        descriptor->vertex_layout_count != 0) {
      MTLVertexDescriptor* vertex_descriptor =
          [[MTLVertexDescriptor alloc] init];
      for (size_t index = 0; index < descriptor->vertex_attribute_count; ++index) {
        const MTLZVertexAttributeDescriptor attribute =
            descriptor->vertex_attributes[index];
        vertex_descriptor.attributes[index].format = (MTLVertexFormat)attribute.format;
        vertex_descriptor.attributes[index].offset = attribute.offset;
        vertex_descriptor.attributes[index].bufferIndex = attribute.buffer_index;
      }
      for (size_t index = 0; index < descriptor->vertex_layout_count; ++index) {
        const MTLZVertexBufferLayoutDescriptor layout =
            descriptor->vertex_layouts[index];
        vertex_descriptor.layouts[index].stride = layout.stride;
        vertex_descriptor.layouts[index].stepFunction =
            (MTLVertexStepFunction)layout.step_function;
        vertex_descriptor.layouts[index].stepRate = layout.step_rate;
      }
      pipeline_descriptor.vertexDescriptor = vertex_descriptor;
    }

    MTLRenderPipelineColorAttachmentDescriptor* color_attachment =
        pipeline_descriptor.colorAttachments[0];
    color_attachment.pixelFormat = (MTLPixelFormat)descriptor->color_pixel_format;
    color_attachment.blendingEnabled = descriptor->blending_enabled;
    color_attachment.sourceRGBBlendFactor =
        (MTLBlendFactor)descriptor->source_rgb_blend_factor;
    color_attachment.destinationRGBBlendFactor =
        (MTLBlendFactor)descriptor->destination_rgb_blend_factor;
    color_attachment.rgbBlendOperation =
        (MTLBlendOperation)descriptor->rgb_blend_operation;
    color_attachment.sourceAlphaBlendFactor =
        (MTLBlendFactor)descriptor->source_alpha_blend_factor;
    color_attachment.destinationAlphaBlendFactor =
        (MTLBlendFactor)descriptor->destination_alpha_blend_factor;
    color_attachment.alphaBlendOperation =
        (MTLBlendOperation)descriptor->alpha_blend_operation;
    color_attachment.writeMask = (MTLColorWriteMask)descriptor->color_write_mask;

    NSError* error = nil;
    id<MTLDevice> metal_device = (__bridge id<MTLDevice>)device;
    id<MTLRenderPipelineState> pipeline =
        [metal_device newRenderPipelineStateWithDescriptor:pipeline_descriptor
                                                     error:&error];
    if (pipeline == nil) {
      mtl_set_error_info(error_info, error);
      return NULL;
    }
    return (__bridge_retained MTLRenderPipelineStateHandle)pipeline;
  }
}

void mtl_release_render_pipeline_state(MTLRenderPipelineStateHandle pipeline_state) {
  if (pipeline_state != NULL) {
    CFRelease(pipeline_state);
  }
}

MTLRenderPipelineStateHandle mtl_retain_render_pipeline_state(
    MTLRenderPipelineStateHandle pipeline_state) {
  if (pipeline_state != NULL) {
    CFRetain(pipeline_state);
  }
  return pipeline_state;
}

MTLBufferHandle mtl_new_buffer_with_length(MTLDeviceHandle device,
                                           size_t length,
                                           size_t options) {
  @autoreleasepool {
    if (device == NULL || length == 0) {
      return NULL;
    }

    id<MTLDevice> metal_device = (__bridge id<MTLDevice>)device;
    id<MTLBuffer> buffer = [metal_device newBufferWithLength:length
                                                    options:(MTLResourceOptions)options];
    return (__bridge_retained MTLBufferHandle)buffer;
  }
}

void* mtl_buffer_get_contents(MTLBufferHandle buffer) {
  if (buffer == NULL) {
    return NULL;
  }
  id<MTLBuffer> metal_buffer = (__bridge id<MTLBuffer>)buffer;
  return metal_buffer.contents;
}

size_t mtl_buffer_get_length(MTLBufferHandle buffer) {
  if (buffer == NULL) {
    return 0;
  }
  id<MTLBuffer> metal_buffer = (__bridge id<MTLBuffer>)buffer;
  return metal_buffer.length;
}

void mtl_buffer_did_modify_range(MTLBufferHandle buffer, size_t offset, size_t length) {
  if (buffer == NULL) {
    return;
  }
  id<MTLBuffer> metal_buffer = (__bridge id<MTLBuffer>)buffer;
  [metal_buffer didModifyRange:NSMakeRange(offset, length)];
}

void mtl_release_buffer(MTLBufferHandle buffer) {
  if (buffer != NULL) {
    CFRelease(buffer);
  }
}

MTLBufferHandle mtl_retain_buffer(MTLBufferHandle buffer) {
  if (buffer != NULL) {
    CFRetain(buffer);
  }
  return buffer;
}

MTLTextureHandle mtl_new_texture(MTLDeviceHandle device,
                                 const MTLZTextureDescriptor* descriptor) {
  @autoreleasepool {
    if (device == NULL || descriptor == NULL) {
      return NULL;
    }
    MTLTextureDescriptor* texture_descriptor = [[MTLTextureDescriptor alloc] init];
    texture_descriptor.textureType = (MTLTextureType)descriptor->texture_type;
    texture_descriptor.pixelFormat = (MTLPixelFormat)descriptor->pixel_format;
    texture_descriptor.width = descriptor->width;
    texture_descriptor.height = descriptor->height;
    texture_descriptor.depth = descriptor->depth;
    texture_descriptor.mipmapLevelCount = descriptor->mipmap_level_count;
    texture_descriptor.sampleCount = descriptor->sample_count;
    texture_descriptor.arrayLength = descriptor->array_length;
    texture_descriptor.usage = (MTLTextureUsage)descriptor->usage;
    texture_descriptor.storageMode = (MTLStorageMode)descriptor->storage_mode;
    texture_descriptor.cpuCacheMode = (MTLCPUCacheMode)descriptor->cpu_cache_mode;

    id<MTLDevice> metal_device = (__bridge id<MTLDevice>)device;
    id<MTLTexture> texture = [metal_device newTextureWithDescriptor:texture_descriptor];
    return (__bridge_retained MTLTextureHandle)texture;
  }
}

void mtl_texture_replace_region(MTLTextureHandle texture,
                                size_t x,
                                size_t y,
                                size_t width,
                                size_t height,
                                size_t mipmap_level,
                                const void* bytes,
                                size_t bytes_per_row) {
  if (texture == NULL || bytes == NULL) {
    return;
  }
  id<MTLTexture> metal_texture = (__bridge id<MTLTexture>)texture;
  const MTLRegion region = MTLRegionMake2D(x, y, width, height);
  [metal_texture replaceRegion:region
                   mipmapLevel:mipmap_level
                     withBytes:bytes
                   bytesPerRow:bytes_per_row];
}

size_t mtl_texture_get_width(MTLTextureHandle texture) {
  if (texture == NULL) {
    return 0;
  }
  return ((__bridge id<MTLTexture>)texture).width;
}

size_t mtl_texture_get_height(MTLTextureHandle texture) {
  if (texture == NULL) {
    return 0;
  }
  return ((__bridge id<MTLTexture>)texture).height;
}

uint32_t mtl_texture_get_pixel_format(MTLTextureHandle texture) {
  if (texture == NULL) {
    return 0;
  }
  return (uint32_t)((__bridge id<MTLTexture>)texture).pixelFormat;
}

void mtl_release_texture(MTLTextureHandle texture) {
  if (texture != NULL) {
    CFRelease(texture);
  }
}

MTLTextureHandle mtl_retain_texture(MTLTextureHandle texture) {
  if (texture != NULL) {
    CFRetain(texture);
  }
  return texture;
}

MTLSamplerStateHandle mtl_new_sampler_state(
    MTLDeviceHandle device,
    const MTLZSamplerDescriptor* descriptor) {
  @autoreleasepool {
    if (device == NULL || descriptor == NULL) {
      return NULL;
    }
    MTLSamplerDescriptor* sampler_descriptor = [[MTLSamplerDescriptor alloc] init];
    sampler_descriptor.minFilter = (MTLSamplerMinMagFilter)descriptor->min_filter;
    sampler_descriptor.magFilter = (MTLSamplerMinMagFilter)descriptor->mag_filter;
    sampler_descriptor.mipFilter = (MTLSamplerMipFilter)descriptor->mip_filter;
    sampler_descriptor.sAddressMode =
        (MTLSamplerAddressMode)descriptor->s_address_mode;
    sampler_descriptor.tAddressMode =
        (MTLSamplerAddressMode)descriptor->t_address_mode;
    sampler_descriptor.rAddressMode =
        (MTLSamplerAddressMode)descriptor->r_address_mode;
    sampler_descriptor.maxAnisotropy = descriptor->max_anisotropy;
    sampler_descriptor.normalizedCoordinates = descriptor->normalized_coordinates;

    id<MTLDevice> metal_device = (__bridge id<MTLDevice>)device;
    id<MTLSamplerState> sampler =
        [metal_device newSamplerStateWithDescriptor:sampler_descriptor];
    return (__bridge_retained MTLSamplerStateHandle)sampler;
  }
}

void mtl_release_sampler_state(MTLSamplerStateHandle sampler) {
  if (sampler != NULL) {
    CFRelease(sampler);
  }
}

MTLSamplerStateHandle mtl_retain_sampler_state(MTLSamplerStateHandle sampler) {
  if (sampler != NULL) {
    CFRetain(sampler);
  }
  return sampler;
}

MTLCommandBufferHandle mtl_new_command_buffer(MTLCommandQueueHandle queue) {
  @autoreleasepool {
    if (queue == NULL) {
      return NULL;
    }
    id<MTLCommandQueue> metal_queue = (__bridge id<MTLCommandQueue>)queue;
    id<MTLCommandBuffer> command_buffer = metal_queue.commandBuffer;
    return (__bridge_retained MTLCommandBufferHandle)command_buffer;
  }
}

void mtl_release_command_buffer(MTLCommandBufferHandle command_buffer) {
  if (command_buffer != NULL) {
    CFRelease(command_buffer);
  }
}

MTLCommandBufferHandle mtl_retain_command_buffer(MTLCommandBufferHandle command_buffer) {
  if (command_buffer != NULL) {
    CFRetain(command_buffer);
  }
  return command_buffer;
}

void mtl_command_buffer_commit(MTLCommandBufferHandle command_buffer) {
  if (command_buffer == NULL) {
    return;
  }
  id<MTLCommandBuffer> metal_command_buffer =
      (__bridge id<MTLCommandBuffer>)command_buffer;
  [metal_command_buffer commit];
}

bool mtl_command_buffer_wait_until_completed(MTLCommandBufferHandle command_buffer,
                                             MTLErrorInfo* error_info) {
  @autoreleasepool {
    if (error_info != NULL) {
      mtl_error_info_clear(error_info);
    }
    if (command_buffer == NULL) {
      return false;
    }

    id<MTLCommandBuffer> metal_command_buffer =
        (__bridge id<MTLCommandBuffer>)command_buffer;
    [metal_command_buffer waitUntilCompleted];
    if (metal_command_buffer.status == MTLCommandBufferStatusError) {
      mtl_set_error_info(error_info, metal_command_buffer.error);
      return false;
    }
    return metal_command_buffer.status == MTLCommandBufferStatusCompleted;
  }
}

uint32_t mtl_command_buffer_get_status(MTLCommandBufferHandle command_buffer) {
  if (command_buffer == NULL) {
    return 0;
  }
  return (uint32_t)((__bridge id<MTLCommandBuffer>)command_buffer).status;
}

void mtl_command_buffer_add_completed_handler(
    MTLCommandBufferHandle command_buffer,
    MTLCommandBufferCompletionCallback callback,
    void* context) {
  if (command_buffer == NULL || callback == NULL) {
    return;
  }
  id<MTLCommandBuffer> metal_command_buffer =
      (__bridge id<MTLCommandBuffer>)command_buffer;
  [metal_command_buffer addCompletedHandler:^(id<MTLCommandBuffer> completed) {
    callback(context, (uint32_t)completed.status);
  }];
}

void mtl_command_buffer_present_drawable(MTLCommandBufferHandle command_buffer,
                                         MTLDrawableHandle drawable) {
  if (command_buffer == NULL || drawable == NULL) {
    return;
  }
  id<MTLCommandBuffer> metal_command_buffer =
      (__bridge id<MTLCommandBuffer>)command_buffer;
  id<CAMetalDrawable> metal_drawable = (__bridge id<CAMetalDrawable>)drawable;
  [metal_command_buffer presentDrawable:metal_drawable];
}

MTLComputeCommandEncoderHandle mtl_new_compute_command_encoder(
    MTLCommandBufferHandle command_buffer) {
  @autoreleasepool {
    if (command_buffer == NULL) {
      return NULL;
    }
    id<MTLCommandBuffer> metal_command_buffer =
        (__bridge id<MTLCommandBuffer>)command_buffer;
    id<MTLComputeCommandEncoder> encoder = metal_command_buffer.computeCommandEncoder;
    return (__bridge_retained MTLComputeCommandEncoderHandle)encoder;
  }
}

void mtl_release_compute_command_encoder(MTLComputeCommandEncoderHandle encoder) {
  if (encoder != NULL) {
    CFRelease(encoder);
  }
}

MTLComputeCommandEncoderHandle mtl_retain_compute_command_encoder(
    MTLComputeCommandEncoderHandle encoder) {
  if (encoder != NULL) {
    CFRetain(encoder);
  }
  return encoder;
}

void mtl_end_encoding(MTLComputeCommandEncoderHandle encoder) {
  if (encoder == NULL) {
    return;
  }
  id<MTLComputeCommandEncoder> metal_encoder =
      (__bridge id<MTLComputeCommandEncoder>)encoder;
  [metal_encoder endEncoding];
}

void mtl_enc_set_compute_pipeline_state(
    MTLComputeCommandEncoderHandle encoder,
    MTLComputePipelineStateHandle pipeline_state) {
  if (encoder == NULL || pipeline_state == NULL) {
    return;
  }
  id<MTLComputeCommandEncoder> metal_encoder =
      (__bridge id<MTLComputeCommandEncoder>)encoder;
  id<MTLComputePipelineState> pipeline =
      (__bridge id<MTLComputePipelineState>)pipeline_state;
  [metal_encoder setComputePipelineState:pipeline];
}

void mtl_enc_set_buffer(MTLComputeCommandEncoderHandle encoder,
                        MTLBufferHandle buffer,
                        size_t offset,
                        size_t index) {
  if (encoder == NULL) {
    return;
  }
  id<MTLComputeCommandEncoder> metal_encoder =
      (__bridge id<MTLComputeCommandEncoder>)encoder;
  id<MTLBuffer> metal_buffer = (__bridge id<MTLBuffer>)buffer;
  [metal_encoder setBuffer:metal_buffer offset:offset atIndex:index];
}

void mtl_enc_set_bytes(MTLComputeCommandEncoderHandle encoder,
                       size_t index,
                       size_t length,
                       const void* bytes) {
  if (encoder == NULL || bytes == NULL || length == 0) {
    return;
  }
  id<MTLComputeCommandEncoder> metal_encoder =
      (__bridge id<MTLComputeCommandEncoder>)encoder;
  [metal_encoder setBytes:bytes length:length atIndex:index];
}

void mtl_enc_dispatch_threads(MTLComputeCommandEncoderHandle encoder,
                              size_t threads_per_grid_width,
                              size_t threads_per_grid_height,
                              size_t threads_per_grid_depth,
                              size_t threads_per_threadgroup_width,
                              size_t threads_per_threadgroup_height,
                              size_t threads_per_threadgroup_depth) {
  if (encoder == NULL) {
    return;
  }

  const MTLSize threads_per_grid = MTLSizeMake(
      threads_per_grid_width, threads_per_grid_height, threads_per_grid_depth);
  const MTLSize threads_per_threadgroup =
      MTLSizeMake(threads_per_threadgroup_width, threads_per_threadgroup_height,
                  threads_per_threadgroup_depth);
  id<MTLComputeCommandEncoder> metal_encoder =
      (__bridge id<MTLComputeCommandEncoder>)encoder;
  [metal_encoder dispatchThreads:threads_per_grid
           threadsPerThreadgroup:threads_per_threadgroup];
}

MTLRenderCommandEncoderHandle mtl_new_render_command_encoder(
    MTLCommandBufferHandle command_buffer,
    const MTLZRenderPassDescriptor* descriptor) {
  @autoreleasepool {
    if (command_buffer == NULL || descriptor == NULL ||
        descriptor->color_texture == NULL) {
      return NULL;
    }
    MTLRenderPassDescriptor* render_pass = [MTLRenderPassDescriptor renderPassDescriptor];
    MTLRenderPassColorAttachmentDescriptor* color = render_pass.colorAttachments[0];
    color.texture = (__bridge id<MTLTexture>)descriptor->color_texture;
    color.loadAction = (MTLLoadAction)descriptor->load_action;
    color.storeAction = (MTLStoreAction)descriptor->store_action;
    color.clearColor = MTLClearColorMake(descriptor->clear_red,
                                         descriptor->clear_green,
                                         descriptor->clear_blue,
                                         descriptor->clear_alpha);
    id<MTLCommandBuffer> metal_command_buffer =
        (__bridge id<MTLCommandBuffer>)command_buffer;
    id<MTLRenderCommandEncoder> encoder =
        [metal_command_buffer renderCommandEncoderWithDescriptor:render_pass];
    return (__bridge_retained MTLRenderCommandEncoderHandle)encoder;
  }
}

void mtl_release_render_command_encoder(MTLRenderCommandEncoderHandle encoder) {
  if (encoder != NULL) {
    CFRelease(encoder);
  }
}

MTLRenderCommandEncoderHandle mtl_retain_render_command_encoder(
    MTLRenderCommandEncoderHandle encoder) {
  if (encoder != NULL) {
    CFRetain(encoder);
  }
  return encoder;
}

void mtl_render_enc_end_encoding(MTLRenderCommandEncoderHandle encoder) {
  if (encoder != NULL) {
    [(__bridge id<MTLRenderCommandEncoder>)encoder endEncoding];
  }
}

void mtl_render_enc_set_pipeline_state(MTLRenderCommandEncoderHandle encoder,
                                       MTLRenderPipelineStateHandle pipeline_state) {
  if (encoder == NULL || pipeline_state == NULL) {
    return;
  }
  [(__bridge id<MTLRenderCommandEncoder>)encoder
      setRenderPipelineState:(__bridge id<MTLRenderPipelineState>)pipeline_state];
}

void mtl_render_enc_set_vertex_buffer(MTLRenderCommandEncoderHandle encoder,
                                      MTLBufferHandle buffer,
                                      size_t offset,
                                      size_t index) {
  if (encoder != NULL) {
    [(__bridge id<MTLRenderCommandEncoder>)encoder
        setVertexBuffer:(__bridge id<MTLBuffer>)buffer
                 offset:offset
                atIndex:index];
  }
}

void mtl_render_enc_set_vertex_bytes(MTLRenderCommandEncoderHandle encoder,
                                     size_t index,
                                     size_t length,
                                     const void* bytes) {
  if (encoder != NULL && bytes != NULL && length != 0) {
    [(__bridge id<MTLRenderCommandEncoder>)encoder setVertexBytes:bytes
                                                          length:length
                                                         atIndex:index];
  }
}

void mtl_render_enc_set_fragment_buffer(MTLRenderCommandEncoderHandle encoder,
                                        MTLBufferHandle buffer,
                                        size_t offset,
                                        size_t index) {
  if (encoder != NULL) {
    [(__bridge id<MTLRenderCommandEncoder>)encoder
        setFragmentBuffer:(__bridge id<MTLBuffer>)buffer
                   offset:offset
                  atIndex:index];
  }
}

void mtl_render_enc_set_fragment_bytes(MTLRenderCommandEncoderHandle encoder,
                                       size_t index,
                                       size_t length,
                                       const void* bytes) {
  if (encoder != NULL && bytes != NULL && length != 0) {
    [(__bridge id<MTLRenderCommandEncoder>)encoder setFragmentBytes:bytes
                                                            length:length
                                                           atIndex:index];
  }
}

void mtl_render_enc_set_fragment_texture(MTLRenderCommandEncoderHandle encoder,
                                         MTLTextureHandle texture,
                                         size_t index) {
  if (encoder != NULL) {
    [(__bridge id<MTLRenderCommandEncoder>)encoder
        setFragmentTexture:(__bridge id<MTLTexture>)texture
                    atIndex:index];
  }
}

void mtl_render_enc_set_fragment_sampler(MTLRenderCommandEncoderHandle encoder,
                                         MTLSamplerStateHandle sampler,
                                         size_t index) {
  if (encoder != NULL) {
    [(__bridge id<MTLRenderCommandEncoder>)encoder
        setFragmentSamplerState:(__bridge id<MTLSamplerState>)sampler
                        atIndex:index];
  }
}

void mtl_render_enc_set_viewport(MTLRenderCommandEncoderHandle encoder,
                                 double origin_x,
                                 double origin_y,
                                 double width,
                                 double height,
                                 double znear,
                                 double zfar) {
  if (encoder != NULL) {
    const MTLViewport viewport = {origin_x, origin_y, width, height, znear, zfar};
    [(__bridge id<MTLRenderCommandEncoder>)encoder setViewport:viewport];
  }
}

void mtl_render_enc_set_scissor_rect(MTLRenderCommandEncoderHandle encoder,
                                     size_t x,
                                     size_t y,
                                     size_t width,
                                     size_t height) {
  if (encoder != NULL) {
    const MTLScissorRect rect = {x, y, width, height};
    [(__bridge id<MTLRenderCommandEncoder>)encoder setScissorRect:rect];
  }
}

void mtl_render_enc_draw_primitives(MTLRenderCommandEncoderHandle encoder,
                                    uint32_t primitive_type,
                                    size_t vertex_start,
                                    size_t vertex_count,
                                    size_t instance_count) {
  if (encoder != NULL) {
    [(__bridge id<MTLRenderCommandEncoder>)encoder
        drawPrimitives:(MTLPrimitiveType)primitive_type
           vertexStart:vertex_start
           vertexCount:vertex_count
         instanceCount:instance_count];
  }
}

void mtl_render_enc_draw_indexed_primitives(
    MTLRenderCommandEncoderHandle encoder,
    uint32_t primitive_type,
    size_t index_count,
    uint32_t index_type,
    MTLBufferHandle index_buffer,
    size_t index_buffer_offset,
    size_t instance_count) {
  if (encoder != NULL && index_buffer != NULL) {
    [(__bridge id<MTLRenderCommandEncoder>)encoder
        drawIndexedPrimitives:(MTLPrimitiveType)primitive_type
                   indexCount:index_count
                    indexType:(MTLIndexType)index_type
                  indexBuffer:(__bridge id<MTLBuffer>)index_buffer
            indexBufferOffset:index_buffer_offset
                instanceCount:instance_count];
  }
}

MTLLayerHandle mtl_layer_create(MTLDeviceHandle device) {
  @autoreleasepool {
    if (device == NULL) {
      return NULL;
    }
    CAMetalLayer* layer = [CAMetalLayer layer];
    layer.device = (__bridge id<MTLDevice>)device;
    return (__bridge_retained MTLLayerHandle)layer;
  }
}

MTLLayerHandle mtl_layer_from_native(void* native_layer) {
  if (native_layer == NULL) {
    return NULL;
  }
  CAMetalLayer* layer = (__bridge CAMetalLayer*)native_layer;
  if (![layer isKindOfClass:[CAMetalLayer class]]) {
    return NULL;
  }
  return (__bridge_retained MTLLayerHandle)layer;
}

void* mtl_layer_get_native(MTLLayerHandle layer) {
  return layer;
}

void mtl_layer_set_device(MTLLayerHandle layer, MTLDeviceHandle device) {
  if (layer != NULL) {
    ((__bridge CAMetalLayer*)layer).device = (__bridge id<MTLDevice>)device;
  }
}

void mtl_layer_set_pixel_format(MTLLayerHandle layer, uint32_t pixel_format) {
  if (layer != NULL) {
    ((__bridge CAMetalLayer*)layer).pixelFormat = (MTLPixelFormat)pixel_format;
  }
}

uint32_t mtl_layer_get_pixel_format(MTLLayerHandle layer) {
  if (layer == NULL) {
    return 0;
  }
  return (uint32_t)((__bridge CAMetalLayer*)layer).pixelFormat;
}

void mtl_layer_set_drawable_size(MTLLayerHandle layer, double width, double height) {
  if (layer != NULL) {
    ((__bridge CAMetalLayer*)layer).drawableSize = CGSizeMake(width, height);
  }
}

void mtl_layer_set_framebuffer_only(MTLLayerHandle layer, bool framebuffer_only) {
  if (layer != NULL) {
    ((__bridge CAMetalLayer*)layer).framebufferOnly = framebuffer_only;
  }
}

void mtl_layer_set_display_sync_enabled(MTLLayerHandle layer, bool enabled) {
  if (layer != NULL) {
    ((__bridge CAMetalLayer*)layer).displaySyncEnabled = enabled;
  }
}

MTLDrawableHandle mtl_layer_next_drawable(MTLLayerHandle layer) {
  @autoreleasepool {
    if (layer == NULL) {
      return NULL;
    }
    id<CAMetalDrawable> drawable = [(__bridge CAMetalLayer*)layer nextDrawable];
    return (__bridge_retained MTLDrawableHandle)drawable;
  }
}

void mtl_release_layer(MTLLayerHandle layer) {
  if (layer != NULL) {
    CFRelease(layer);
  }
}

MTLLayerHandle mtl_retain_layer(MTLLayerHandle layer) {
  if (layer != NULL) {
    CFRetain(layer);
  }
  return layer;
}

MTLTextureHandle mtl_drawable_copy_texture(MTLDrawableHandle drawable) {
  if (drawable == NULL) {
    return NULL;
  }
  id<MTLTexture> texture = ((__bridge id<CAMetalDrawable>)drawable).texture;
  return (__bridge_retained MTLTextureHandle)texture;
}

void mtl_release_drawable(MTLDrawableHandle drawable) {
  if (drawable != NULL) {
    CFRelease(drawable);
  }
}

MTLDrawableHandle mtl_retain_drawable(MTLDrawableHandle drawable) {
  if (drawable != NULL) {
    CFRetain(drawable);
  }
  return drawable;
}
