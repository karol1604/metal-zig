#import "metal_shim.h"
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

struct MTLSizeHandle {
  MTLSize size;
};
struct MTLDeviceList {
  MTLDeviceHandle** devices;
  size_t count;
};

#define BRIDGE_RETAIN(obj) (__bridge_retained void*)(obj)
#define BRIDGE_TRANSFER(ptr) (__bridge_transfer id)(ptr)

// TODO: fix this to do the right thing
MTLDeviceHandle mtl_create_system_default_device(
    void) {
  return (MTLDeviceHandle)CFBridgingRetain(MTLCreateSystemDefaultDevice());
}

void mtl_release_device(
    MTLDeviceHandle h) {
  if (h) {
    free(h);
  }
}

MTLDeviceHandle mtl_get_device_at_index(
    size_t index) {
  @autoreleasepool {
    NSArray<id<MTLDevice>>* devices = MTLCopyAllDevices();
    if (index >= devices.count) {
      NSLog(@"Index out of bounds: %zu", index);
      return NULL;
    }

    return (MTLDeviceHandle)CFBridgingRetain(devices[index]);
  }
}
size_t mtl_get_device_list_size(
    void) {
  @autoreleasepool {
    NSArray<id<MTLDevice>>* devices = MTLCopyAllDevices();
    return devices.count;
  }
}

const char* mtl_get_device_name(
    MTLDeviceHandle device) {
  if (!device) {
    NSLog(@"Invalid device handle");
    return NULL;
  }

  id<MTLDevice> dev = (__bridge id<MTLDevice>)device;
  const char* name = [[dev name] UTF8String];
  // FIXME: memory leak
  return strdup(name);
}

MTLCommandQueueHandle mtl_new_command_queue(
    MTLDeviceHandle device) {
  id<MTLDevice> dev = (__bridge id<MTLDevice>)device;
  id<MTLCommandQueue> q = [dev newCommandQueue];
  return (MTLCommandQueueHandle)CFBridgingRetain(q);
}

void mtl_release_command_queue(
    MTLCommandQueueHandle h) {
  if (h)
    CFRelease(h);
}

MTLLibraryHandle mtl_new_library_with_url(
    MTLDeviceHandle device,
    const char* url) {
  @autoreleasepool {
    NSURL* libraryURL = [NSURL URLWithString:[NSString stringWithUTF8String:url]];

    NSError* error = nil;

    id<MTLDevice> dev = (__bridge id<MTLDevice>)device;
    id<MTLLibrary> library = [dev newLibraryWithURL:libraryURL error:&error];
    if (!library) {
      NSLog(@"Failed to create library with URL %s: %@", url, error.localizedDescription);
      return NULL;
    }

    return (MTLLibraryHandle)CFBridgingRetain(library);
  }
}

// FIXME: does not work
MTLLibraryHandle mtl_new_library_with_data(
    MTLDeviceHandle device,
    const void* data) {
  @autoreleasepool {
    NSLog(@"Creating library with data: %p", data);
    NSError* error = nil;

    id<MTLDevice> dev = (__bridge id<MTLDevice>)device;
    id<MTLLibrary> library = [dev newLibraryWithData:(__bridge dispatch_data_t _Nonnull)data
                                               error:&error];

    if (!library) {
      NSLog(@"Failed to create library with data %@", error.localizedDescription);
      return NULL;
    }

    return (MTLLibraryHandle)CFBridgingRetain(library);
  }
}

MTLLibraryHandle mtl_new_library_with_source(
    MTLDeviceHandle device,
    const char* source) {
  id<MTLDevice> dev = (__bridge id<MTLDevice>)device;
  NSString* src = [NSString stringWithUTF8String:source];

  NSError* error = nil;
  id<MTLLibrary> library = [dev newLibraryWithSource:src options:nil error:&error];

  if (error) {
    NSLog(@"Failed to create library with source: %@", error.localizedDescription);
    return NULL;
  }

  if (library == nil) {
    NSLog(@"Library is NULL after creation with source");
    return NULL;
  }

  return (MTLLibraryHandle)CFBridgingRetain(library);
}

void mtl_release_library(
    MTLLibraryHandle h) {
  if (h)
    CFRelease(h);
}

MTLFunctionHandle mtl_new_function_with_name(
    MTLLibraryHandle library,
    const char* name) {
  @autoreleasepool {
    if (!library || !name)
      return NULL;
    NSString* functionName = [NSString stringWithUTF8String:name];

    id<MTLLibrary> lib = (__bridge id<MTLLibrary>)library;
    id<MTLFunction> function = [lib newFunctionWithName:functionName];

    if (!function) {
      NSLog(@"Failed to create function with name %s", name);
      return NULL;
    }

    return (MTLFunctionHandle)CFBridgingRetain(function);
  }
}

void mtl_release_function(
    MTLFunctionHandle function) {
  if (function)
    CFRelease(function);
}

MTLComputePipelineStateHandle mtl_new_compute_pipeline_state_with_function(
    MTLDeviceHandle device,
    MTLFunctionHandle function) {
  @autoreleasepool {
    if (!device || !function) {
      NSLog(@"Invalid device or function");
      return NULL;
    }

    NSError* error = nil;
    id<MTLDevice> dev = (__bridge id<MTLDevice>)device;

    id<MTLFunction> func = (__bridge id<MTLFunction>)function;
    id<MTLComputePipelineState> pipelineState = [dev newComputePipelineStateWithFunction:func
                                                                                   error:&error];
    if (error || !pipelineState) {
      NSLog(@"Failed to create compute pipeline state: %@", error.localizedDescription);
      return NULL;
    }

    return (MTLComputePipelineStateHandle)CFBridgingRetain(pipelineState);
  }
}

void mtl_release_compute_pipeline_state(
    MTLComputePipelineStateHandle pipelineState) {
  if (pipelineState != NULL)
    CFRelease(pipelineState);
  else
    NSLog(@"Invalid pipeline state handle");
}

MTLBufferHandle mtl_new_buffer_with_length(
    MTLDeviceHandle device,
    unsigned int length,
    MTLResourceOptionsHandle options) {
  @autoreleasepool {
    if (!device || length == 0) {
      NSLog(@"Invalid device or length");
      return NULL;
    }

    id<MTLDevice> dev = (__bridge id<MTLDevice>)device;
    id<MTLBuffer> buffer = [dev newBufferWithLength:length
                                            options:(MTLResourceOptionsHandle)options];
    if (!buffer) {
      NSLog(@"Failed to create buffer with length %u", length);
      return NULL;
    }

    return (MTLBufferHandle)CFBridgingRetain(buffer);
  }
}

MTLCommandBufferHandle mtl_new_command_buffer(
    MTLCommandQueueHandle queue) {
  @autoreleasepool {
    if (!queue) {
      NSLog(@"Invalid command queue");
      return NULL;
    }

    id<MTLCommandQueue> q = (__bridge id<MTLCommandQueue>)queue;
    id<MTLCommandBuffer> commandBuffer = [q commandBuffer];
    if (!commandBuffer) {
      return NULL;
    }

    return (MTLCommandBufferHandle)CFBridgingRetain(commandBuffer);
  }
}

void mtl_release_command_buffer(
    MTLCommandBufferHandle commandBuffer) {
  if (commandBuffer)
    CFRelease(commandBuffer);
}

MTLComputeCommandEncoderHandle mtl_new_compute_command_encoder(
    MTLCommandBufferHandle commandBuffer) {
  @autoreleasepool {
    if (!commandBuffer) {
      NSLog(@"Invalid command buffer");
      return NULL;
    }

    id<MTLCommandBuffer> cb = (__bridge id<MTLCommandBuffer>)commandBuffer;
    id<MTLComputeCommandEncoder> computeEncoder = [cb computeCommandEncoder];
    if (!computeEncoder) {
      NSLog(@"Failed to create compute command encoder");
      return NULL;
    }

    return (MTLComputeCommandEncoderHandle)CFBridgingRetain(computeEncoder);
  }
}
void mtl_release_compute_command_encoder(
    MTLComputeCommandEncoderHandle encoder) {
  if (encoder != NULL) {
    CFRelease(encoder);
  }
}

void mtl_end_encoding(
    MTLComputeCommandEncoderHandle encoder) {
  if (encoder == NULL) {
    NSLog(@"Invalid compute command encoder");
    return;
  }
  id<MTLComputeCommandEncoder> enc = (__bridge id<MTLComputeCommandEncoder>)encoder;
  [enc endEncoding];
}

void mtl_enc_set_compute_pipeline_state(
    MTLComputeCommandEncoderHandle encoder,
    MTLComputePipelineStateHandle pipelineState) {
  @autoreleasepool {
    if (encoder == NULL || pipelineState == NULL) {
      NSLog(@"Invalid encoder or pipeline state");
      return;
    }

    id<MTLComputePipelineState> pipeline = (__bridge id<MTLComputePipelineState>)pipelineState;
    id<MTLComputeCommandEncoder> enc = (__bridge id<MTLComputeCommandEncoder>)encoder;
    [enc setComputePipelineState:pipeline];
  }
}

void mtl_enc_set_buffer(
    MTLComputeCommandEncoderHandle encoder,
    MTLBufferHandle buffer,
    unsigned int offset,
    unsigned int index) {
  @autoreleasepool {
    // NOTE: is `== NULL` correct here?
    if (encoder == NULL || buffer == NULL) {
      NSLog(@"Invalid encoder or buffer");
      return;
    }

    id<MTLBuffer> buf = (__bridge id<MTLBuffer>)buffer;
    id<MTLComputeCommandEncoder> enc = (__bridge id<MTLComputeCommandEncoder>)encoder;
    [enc setBuffer:buf offset:offset atIndex:index];
  }
}

void mtl_enc_set_bytes(
    MTLComputeCommandEncoderHandle encoder,
    unsigned int index,
    size_t length,
    const void* bytes) {
  @autoreleasepool {
    if (encoder == NULL || !bytes || length == 0) {
      NSLog(@"Invalid encoder, bytes, or length");
      return;
    }

    id<MTLComputeCommandEncoder> enc = (__bridge id<MTLComputeCommandEncoder>)encoder;
    [enc setBytes:bytes length:length atIndex:index];
  }
}

void* mtl_buffer_get_contents(
    MTLBufferHandle bufHandle) {
  id<MTLBuffer> buf = (__bridge id<MTLBuffer>)bufHandle;
  return bufHandle ? [buf contents] : NULL;
}

size_t mtl_buffer_get_length(
    MTLBufferHandle bufHandle) {
  id<MTLBuffer> buf = (__bridge id<MTLBuffer>)bufHandle;
  return bufHandle ? [buf length] : 0;
}

void mtl_release_buffer(
    MTLBufferHandle bufHandle) {
  if (bufHandle) {
    CFRelease(bufHandle);
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

void mtl_enc_dispatch_threads(
    MTLComputeCommandEncoderHandle encoder,
    unsigned int threadgroupsPerGridWidth,
    unsigned int threadgroupsPerGridHeight,
    unsigned int threadgroupsPerGridDepth,
    unsigned int threadsPerThreadgroupWidth,
    unsigned int threadsPerThreadgroupHeight,
    unsigned int threadsPerThreadgroupDepth) {
  @autoreleasepool {
    if (encoder == NULL) {
      NSLog(@"Invalid compute command encoder");
      return;
    }

    MTLSize tgPerGrid =
        MTLSizeMake(threadgroupsPerGridWidth, threadgroupsPerGridHeight, threadgroupsPerGridDepth);
    MTLSize tg = MTLSizeMake(
        threadsPerThreadgroupWidth, threadsPerThreadgroupHeight, threadsPerThreadgroupDepth);

    id<MTLComputeCommandEncoder> enc = (__bridge id<MTLComputeCommandEncoder>)encoder;
    [enc dispatchThreads:tgPerGrid threadsPerThreadgroup:tg];
  }
}

void mtl_command_buffer_commit(
    MTLCommandBufferHandle commandBuffer) {
  @autoreleasepool {
    if (!commandBuffer) {
      NSLog(@"Invalid command buffer");
      return;
    }

    id<MTLCommandBuffer> cb = (__bridge id<MTLCommandBuffer>)commandBuffer;
    [cb commit];
  }
}

void mtl_command_buffer_wait_until_completed(
    MTLCommandBufferHandle commandBuffer) {
  @autoreleasepool {
    if (!commandBuffer) {
      NSLog(@"Invalid command buffer");
      return;
    }

    id<MTLCommandBuffer> cb = (__bridge id<MTLCommandBuffer>)commandBuffer;
    [cb waitUntilCompleted];
  }
}

unsigned int mtl_get_maxTotalThreadsPerThreadgroup(
    MTLComputePipelineStateHandle pipeline) {
  if (pipeline == NULL) {
    NSLog(@"Invalid pipeline state");
    return 0;
  }
  id<MTLComputePipelineState> p = (__bridge id<MTLComputePipelineState>)pipeline;
  return [p maxTotalThreadsPerThreadgroup];
}
