#pragma once

#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif

typedef void* MTLDeviceHandle;
typedef void* MTLCommandQueueHandle;
typedef void* MTLCommandBufferHandle;
typedef void* MTLLibraryHandle;
typedef void* MTLFunctionHandle;
typedef void* MTLComputePipelineStateHandle;
typedef void* MTLBufferHandle;
typedef void* MTLComputeCommandEncoderHandle;
typedef struct MTLSizeHandle MTLSizeHandle;
typedef struct MTLDeviceList MTLDeviceList;

/*#define MTLResourceCPUCacheModeShift 0*/
/*#define MTLResourceCPUCacheModeMask (0xfUL << MTLResourceCPUCacheModeShift)*/
/**/
/*#define MTLResourceStorageModeShift 4*/
/*#define MTLResourceStorageModeMask (0xfUL << MTLResourceStorageModeShift)*/
/**/
/*#define MTLResourceHazardTrackingModeShift 8*/
/*#define MTLResourceHazardTrackingModeMask (0x3UL << MTLResourceHazardTrackingModeShift)*/
/**/
/*#define MTLCPUCacheModeDefaultCache 0*/
/*#define MTLCPUCacheModeWriteCombined 1*/

/*typedef unsigned int MTLResourceOptionsHandle;*/
/*enum {*/
/*  MTLResourceCPUCacheModeDefaultCache = MTLCPUCacheModeDefaultCache <<
 * MTLResourceCPUCacheModeShift,*/
/*  MTLResourceCPUCacheModeWriteCombined = MTLCPUCacheModeWriteCombined*/
/*                                         << MTLResourceCPUCacheModeShift,*/
/**/
/*  // TODO:  MTLStorageModeShared*/
/*  MTLResourceStorageModeShared = 0 << MTLResourceStorageModeShift,*/
/*  // TODO: MTLStorageModeManaged*/
/*  MTLResourceStorageModeManaged = 1 << MTLResourceStorageModeShift,*/
/*  // TODO: MTLStorageModePrivate*/
/*  MTLResourceStorageModePrivate = 2 << MTLResourceStorageModeShift,*/
/*  // TODO: MTLStorageModeMemoryless*/
/*  MTLResourceStorageModeMemoryless = 3 << MTLResourceStorageModeShift,*/
/**/
/*  // TODO: MTLHazardTrackingModeDefault*/
/*  MTLResourceHazardTrackingModeDefault = 0 << MTLResourceHazardTrackingModeShift,*/
/*  // TODO: MTLHazardTrackingModeUntracked*/
/*  MTLResourceHazardTrackingModeUntracked = 1 << MTLResourceHazardTrackingModeShift,*/
/*  // TODO: MTLHazardTrackingModeTracked*/
/*  MTLResourceHazardTrackingModeTracked = 2 << MTLResourceHazardTrackingModeShift,*/

// Deprecated spellings
/*MTLResourceOptionCPUCacheModeDefault
   API_DEPRECATED_WITH_REPLACEMENT("MTLResourceCPUCacheModeDefaultCache",
   macos(10.11, 13.0), ios(8.0, 16.0)) =
   MTLResourceCPUCacheModeDefaultCache,*/
/*MTLResourceOptionCPUCacheModeWriteCombined
   API_DEPRECATED_WITH_REPLACEMENT("MTLResourceCPUCacheModeWriteCombined",
   macos(10.11, 13.0), ios(8.0, 16.0)) =
   MTLResourceCPUCacheModeWriteCombined,*/
/*};*/

typedef uint32_t MTLResourceOptionsHandle;
#define METAL_RESOURCE_STORAGE_MODE_SHARED 0
#define METAL_RESOURCE_STORAGE_MODE_MANAGED (1 << 4)
#define METAL_RESOURCE_STORAGE_MODE_PRIVATE (2 << 4)

MTLDeviceHandle mtl_create_system_default_device(void);
void mtl_release_device(MTLDeviceHandle device);

MTLDeviceHandle mtl_get_device_at_index(size_t index);
size_t mtl_get_device_list_size(void);

const char* mtl_get_device_name(MTLDeviceHandle device);

MTLCommandQueueHandle mtl_new_command_queue(MTLDeviceHandle device);
void mtl_release_command_queue(MTLCommandQueueHandle queue);

MTLLibraryHandle mtl_new_library_with_url(MTLDeviceHandle device, const char* url);
MTLLibraryHandle mtl_new_library_with_data(MTLDeviceHandle device, const void* data);
MTLLibraryHandle mtl_new_library_with_source(MTLDeviceHandle device, const char* source);
void mtl_release_library(MTLLibraryHandle library);

MTLFunctionHandle mtl_new_function_with_name(MTLLibraryHandle library, const char* name);

void mtl_release_function(MTLFunctionHandle function);

MTLComputePipelineStateHandle mtl_new_compute_pipeline_state_with_function(MTLDeviceHandle device,
    MTLFunctionHandle function);

void mtl_release_compute_pipeline_state(MTLComputePipelineStateHandle pipelineState);

MTLBufferHandle mtl_new_buffer_with_length(MTLDeviceHandle device,
    unsigned int length,
    MTLResourceOptionsHandle options);

/// Returns the raw CPU‐side pointer for a shared MTLBuffer.
void* mtl_buffer_get_contents(MTLBufferHandle buf);

/// Returns the buffer’s length in bytes.
size_t mtl_buffer_get_length(MTLBufferHandle buf);
void mtl_release_buffer(MTLBufferHandle buf);

MTLCommandBufferHandle mtl_new_command_buffer(MTLCommandQueueHandle queue);
void mtl_release_command_buffer(MTLCommandBufferHandle commandBuffer);

MTLComputeCommandEncoderHandle mtl_new_compute_command_encoder(
    MTLCommandBufferHandle commandBuffer);

void mtl_release_compute_command_encoder(MTLComputeCommandEncoderHandle encoder);

void mtl_end_encoding(MTLComputeCommandEncoderHandle encoder);

void mtl_enc_set_compute_pipeline_state(MTLComputeCommandEncoderHandle encoder,
    MTLComputePipelineStateHandle pipelineState);

void mtl_enc_set_buffer(MTLComputeCommandEncoderHandle encoder,
    MTLBufferHandle buffer,
    unsigned int offset,
    unsigned int index);

void mtl_enc_set_bytes(MTLComputeCommandEncoderHandle encoder,
    unsigned int index,
    size_t length,
    const void* bytes);

void mtl_enc_dispatch_threads(MTLComputeCommandEncoderHandle encoder,
    unsigned int threadgroupsPerGridWidth,
    unsigned int threadgroupsPerGridHeight,
    unsigned int threadgroupsPerGridDepth,
    unsigned int threadsPerThreadgroupWidth,
    unsigned int threadsPerThreadgroupHeight,
    unsigned int threadsPerThreadgroupDepth);

MTLSizeHandle mtl_size_make(unsigned int width, unsigned int height, unsigned int depth);

void mtl_command_buffer_commit(MTLCommandBufferHandle commandBuffer);
void mtl_command_buffer_wait_until_completed(MTLCommandBufferHandle commandBuffer);

unsigned int mtl_get_maxTotalThreadsPerThreadgroup(MTLComputePipelineStateHandle pipeline);

#ifdef __cplusplus
}
#endif
