#import "metal_shim.h"
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

struct MTLDeviceHandle {
  id<MTLDevice> device;
};
struct MTLCommandQueueHandle {
  id<MTLCommandQueue> queue;
};
struct MTLBufferHandle {
  id<MTLBuffer> buffer;
};
struct MTLComputePipelineStateHandle {
  id<MTLComputePipelineState> pipeline;
};
struct MTLCommandBufferHandle {
  id<MTLCommandBuffer> cmd;
};
struct MTLComputeCommandEncoderHandle {
  id<MTLComputeCommandEncoder> enc;
};
struct MTLLibraryHandle {
  id<MTLLibrary> library;
};
struct MTLFunctionHandle {
  id<MTLFunction> function;
};
struct MTLSizeHandle {
  MTLSize size;
};

#define BRIDGE_RETAIN(obj) (__bridge_retained void*)(obj)
#define BRIDGE_TRANSFER(ptr) (__bridge_transfer id)(ptr)

// TODO: fix this to do the right thing
MTLDeviceHandle* mtl_create_system_default_device(void) {
  MTLDeviceHandle* handle = malloc(sizeof(*handle));
  handle->device = MTLCopyAllDevices().firstObject;
  if (!handle->device) {
    NSLog(@"Failed to create system default device");
    free(handle);
    return NULL;
  }
  return handle;
}

void mtl_release_device(MTLDeviceHandle* h) {
  if (h) {
    free(h);
  }
}

MTLCommandQueueHandle* mtl_new_command_queue(MTLDeviceHandle* device) {
  MTLCommandQueueHandle* handle = malloc(sizeof(*handle));
  handle->queue = [device->device newCommandQueue];
  return handle;
}

void mtl_release_command_queue(MTLCommandQueueHandle* h) {
  if (h) {
    free(h);
  }
}

MTLLibraryHandle* mtl_new_library_with_url(MTLDeviceHandle* device,
                                           const char* url) {
  @autoreleasepool {
    NSURL* libraryURL =
        [NSURL URLWithString:[NSString stringWithUTF8String:url]];

    NSError* error = nil;
    id<MTLLibrary> library = [device->device newLibraryWithURL:libraryURL
                                                         error:&error];
    if (!library) {
      NSLog(@"Failed to create library with URL %s: %@", url,
            error.localizedDescription);
      return NULL;
    }

    MTLLibraryHandle* h = malloc(sizeof(*h));
    h->library = library;

    if (error) {
      NSLog(@"Failed to create library with URL %s: %@", url,
            error.localizedDescription);
      free(h);
      return NULL;
    }

    return h;
  }
}

void mtl_release_library(MTLLibraryHandle* h) {
  if (h) {
    free(h);
  }
}

MTLFunctionHandle* mtl_new_function_with_name(MTLLibraryHandle* library,
                                              const char* name) {
  @autoreleasepool {
    if (!library || !name)
      return NULL;
    NSString* functionName = [NSString stringWithUTF8String:name];

    id<MTLFunction> function =
        [library->library newFunctionWithName:functionName];

    if (!function) {
      NSLog(@"Failed to create function with name %s", name);
      return NULL;
    }

    MTLFunctionHandle* handle = malloc(sizeof(*handle));
    handle->function = function;

    return handle;
  }
}

void mtl_release_function(MTLFunctionHandle* function) {
  if (function) {
    free(function);
  }
}

MTLComputePipelineStateHandle* mtl_new_compute_pipeline_state_with_function(
    MTLDeviceHandle* device,
    MTLFunctionHandle* function) {
  @autoreleasepool {
    if (!device || !function) {
      NSLog(@"Invalid device or function");
      return NULL;
    }

    NSError* error = nil;
    id<MTLComputePipelineState> pipelineState =
        [device->device newComputePipelineStateWithFunction:function->function
                                                      error:&error];
    if (error || !pipelineState) {
      NSLog(@"Failed to create compute pipeline state: %@",
            error.localizedDescription);
      return NULL;
    }

    MTLComputePipelineStateHandle* h = malloc(sizeof(*h));
    h->pipeline = pipelineState;

    return h;
  }
}

void mtl_release_compute_pipeline_state(
    MTLComputePipelineStateHandle* pipelineState) {
  if (pipelineState) {
    free(pipelineState);
  }
}

MTLBufferHandle* mtl_new_buffer_with_length(MTLDeviceHandle* device,
                                            unsigned int length,
                                            MTLResourceOptionsHandle options) {
  @autoreleasepool {
    if (!device || length == 0) {
      NSLog(@"Invalid device or length");
      return NULL;
    }

    id<MTLBuffer> buffer =
        [device->device newBufferWithLength:length
                                    options:(MTLResourceOptionsHandle)options];
    if (!buffer) {
      NSLog(@"Failed to create buffer with length %u", length);
      return NULL;
    }

    MTLBufferHandle* h = malloc(sizeof(*h));
    h->buffer = buffer;
    return h;
  }
}

MTLCommandBufferHandle* mtl_new_command_buffer(MTLCommandQueueHandle* queue) {
  @autoreleasepool {
    if (!queue) {
      NSLog(@"Invalid command queue");
      return NULL;
    }

    id<MTLCommandBuffer> commandBuffer = [queue->queue commandBuffer];
    if (!commandBuffer) {
      return NULL;
    }

    MTLCommandBufferHandle* h = malloc(sizeof(*h));
    h->cmd = commandBuffer;
    return h;
  }
}

void mtl_release_command_buffer(MTLCommandBufferHandle* commandBuffer) {
  if (commandBuffer) {
    free(commandBuffer);
  }
}

MTLComputeCommandEncoderHandle* mtl_new_compute_command_encoder(
    MTLCommandBufferHandle* commandBuffer) {
  @autoreleasepool {
    if (!commandBuffer) {
      NSLog(@"Invalid command buffer");
      return NULL;
    }

    id<MTLComputeCommandEncoder> computeEncoder =
        [commandBuffer->cmd computeCommandEncoder];
    if (!computeEncoder) {
      NSLog(@"Failed to create compute command encoder");
      return NULL;
    }

    MTLComputeCommandEncoderHandle* h = malloc(sizeof(*h));
    h->enc = computeEncoder;
    return h;
  }
}
void mtl_release_compute_command_encoder(
    MTLComputeCommandEncoderHandle* encoder) {
  if (encoder) {
    free(encoder);
  }
}

void mtl_end_encoding(MTLComputeCommandEncoderHandle* encoder) {
  if (!encoder->enc) {
    NSLog(@"Invalid compute command encoder");
    return;
  }
  [encoder->enc endEncoding];
}

void mtl_enc_set_compute_pipeline_state(
    MTLComputeCommandEncoderHandle* encoder,
    MTLComputePipelineStateHandle* pipelineState) {
  @autoreleasepool {
    if (!encoder->enc || !pipelineState->pipeline) {
      NSLog(@"Invalid encoder or pipeline state");
      return;
    }

    [encoder->enc setComputePipelineState:pipelineState->pipeline];
  }
}

void mtl_enc_set_buffer(MTLComputeCommandEncoderHandle* encoder,
                        MTLBufferHandle* buffer,
                        unsigned int offset,
                        unsigned int index) {
  @autoreleasepool {
    if (!encoder->enc || !buffer->buffer) {
      NSLog(@"Invalid encoder or buffer");
      return;
    }

    [encoder->enc setBuffer:buffer->buffer offset:offset atIndex:index];
  }
}

void mtl_enc_set_bytes(MTLComputeCommandEncoderHandle* encoder,
                       unsigned int index,
                       size_t length,
                       const void* bytes) {
  @autoreleasepool {
    if (!encoder->enc || !bytes || length == 0) {
      NSLog(@"Invalid encoder, bytes, or length");
      return;
    }

    [encoder->enc setBytes:bytes length:length atIndex:index];
  }
}

void* mtl_buffer_get_contents(MTLBufferHandle* bufHandle) {
  return bufHandle ? [bufHandle->buffer contents] : NULL;
}

size_t mtl_buffer_get_length(MTLBufferHandle* bufHandle) {
  return bufHandle ? [bufHandle->buffer length] : 0;
}

void mtl_release_buffer(MTLBufferHandle* bufHandle) {
  if (bufHandle) {
    free(bufHandle);
  }
}

// MTLSizeHandle mtl_size_make(unsigned int width, unsigned int height,
//                           unsigned int depth) {
//  @autoreleasepool {
//    // NOTE: not sure bout this, scary
//    MTLSize *size = (MTLSize *)malloc(sizeof(MTLSize));
//    *size = MTLSizeMake(width, height, depth);
//    return size;
//  }
//}

void mtl_enc_dispatch_threads(MTLComputeCommandEncoderHandle* encoder,
                              unsigned int threadgroupsPerGridWidth,
                              unsigned int threadgroupsPerGridHeight,
                              unsigned int threadgroupsPerGridDepth,
                              unsigned int threadsPerThreadgroupWidth,
                              unsigned int threadsPerThreadgroupHeight,
                              unsigned int threadsPerThreadgroupDepth) {
  @autoreleasepool {
    if (!encoder) {
      NSLog(@"Invalid compute command encoder");
      return;
    }

    MTLSize tgPerGrid =
        MTLSizeMake(threadgroupsPerGridWidth, threadgroupsPerGridHeight,
                    threadgroupsPerGridDepth);
    MTLSize tg =
        MTLSizeMake(threadsPerThreadgroupWidth, threadsPerThreadgroupHeight,
                    threadsPerThreadgroupDepth);

    [encoder->enc dispatchThreads:tgPerGrid threadsPerThreadgroup:tg];
  }
}

void mtl_command_buffer_commit(MTLCommandBufferHandle* commandBuffer) {
  @autoreleasepool {
    if (!commandBuffer) {
      NSLog(@"Invalid command buffer");
      return;
    }

    [commandBuffer->cmd commit];
  }
}

void mtl_command_buffer_wait_until_completed(
    MTLCommandBufferHandle* commandBuffer) {
  @autoreleasepool {
    if (!commandBuffer) {
      NSLog(@"Invalid command buffer");
      return;
    }

    [commandBuffer->cmd waitUntilCompleted];
  }
}

unsigned int mtl_get_maxTotalThreadsPerThreadgroup(
    MTLComputePipelineStateHandle* pipeline) {
  if (!pipeline->pipeline) {
    NSLog(@"Invalid pipeline state");
    return 0;
  }
  return pipeline->pipeline.maxTotalThreadsPerThreadgroup;
}
