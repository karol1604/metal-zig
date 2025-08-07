#import "metal_shim.h"
#include <CoreFoundation/CFBase.h>
#import <Foundation/Foundation.h>
#include <Foundation/NSObjCRuntime.h>
#import <Metal/Metal.h>

#define BRIDGE_RETAIN(obj) (__bridge_retained void *)(obj)
#define BRIDGE_TRANSFER(ptr) (__bridge_transfer id)(ptr)

// TODO: fix this to do the right thing
MTLDeviceHandle mtl_create_system_default_device(void) {
  id<MTLDevice> device = MTLCopyAllDevices().firstObject;
  if (!device) {
    return NULL;
  }
  return (__bridge_retained MTLDeviceHandle)device;
}

void mtl_release_device(MTLDeviceHandle device) {
  if (device) {
    CFRelease(device);
  }
}

MTLCommandQueueHandle mtl_new_command_queue(MTLDeviceHandle device) {
  @autoreleasepool {
    id<MTLDevice> metalDevice = (__bridge id<MTLDevice>)device;
    id<MTLCommandQueue> commandQueue = [metalDevice newCommandQueue];
    if (!commandQueue) {
      NSLog(@"Failed to create command queue");
      return NULL;
    }
    return BRIDGE_RETAIN(commandQueue);
  }
}

void mtl_release_command_queue(MTLCommandQueueHandle queue) {
  if (queue) {
    CFRelease(queue);
  }
}

MTLLibraryHandle mtl_new_library_with_url(MTLDeviceHandle device,
                                          const char *url) {

  @autoreleasepool {
    id<MTLDevice> metalDevice = (__bridge id<MTLDevice>)device;
    NSURL *libraryURL =
        [NSURL URLWithString:[NSString stringWithUTF8String:url]];

    NSError *error = nil;
    id<MTLLibrary> library = [metalDevice newLibraryWithURL:libraryURL
                                                      error:&error];

    if (error) {
      NSLog(@"Failed to create library with URL %s: %@", url,
            error.localizedDescription);
      return NULL;
    }

    return BRIDGE_RETAIN(library);
  }
}

void mtl_release_library(MTLLibraryHandle library) {
  if (library) {
    CFRelease(library);
  }
}

MTLFunctionHandle mtl_new_function_with_name(MTLLibraryHandle library,
                                             const char *name) {

  @autoreleasepool {
    id<MTLLibrary> metalLibrary = (__bridge id<MTLLibrary>)library;
    NSString *functionName = [NSString stringWithUTF8String:name];

    id<MTLFunction> function = [metalLibrary newFunctionWithName:functionName];
    if (!function) {
      NSLog(@"Failed to create function with name %s", name);
      return NULL;
    }

    return BRIDGE_RETAIN(function);
  }
}

void mtl_release_function(MTLFunctionHandle function) {
  if (function) {
    CFRelease(function);
  }
}

MTLComputePipelineStateHandle
mtl_new_compute_pipeline_state_with_function(MTLDeviceHandle device,
                                             MTLFunctionHandle function) {

  @autoreleasepool {
    id<MTLDevice> metalDevice = (__bridge id<MTLDevice>)device;
    id<MTLFunction> metalFunction = (__bridge id<MTLFunction>)function;
    NSError *error = nil;
    id<MTLComputePipelineState> pipelineState =
        [metalDevice newComputePipelineStateWithFunction:metalFunction
                                                   error:&error];
    if (error) {
      NSLog(@"Failed to create compute pipeline state: %@",
            error.localizedDescription);
      return NULL;
    }

    return BRIDGE_RETAIN(pipelineState);
  }
}

void mtl_release_compute_pipeline_state(
    MTLComputePipelineStateHandle pipelineState) {
  if (pipelineState) {
    CFRelease(pipelineState);
  }
}

MTLBufferHandle mtl_new_buffer_with_length(MTLDeviceHandle device,
                                           unsigned int length,
                                           MTLResourceOptionsHandle options) {

  @autoreleasepool {
    id<MTLDevice> metalDevice = (__bridge id<MTLDevice>)device;
    id<MTLBuffer> buffer =
        [metalDevice newBufferWithLength:length
                                 options:(MTLResourceOptionsHandle)options];
    if (!buffer) {
      NSLog(@"Failed to create buffer with length %u", length);
      return NULL;
    }

    return BRIDGE_RETAIN(buffer);
  }
}

void *mtl_buffer_get_contents(MTLBufferHandle bufHandle) {
  id<MTLBuffer> buf = (__bridge id<MTLBuffer>)bufHandle;
  return buf.contents;
}

size_t mtl_buffer_get_length(MTLBufferHandle bufHandle) {
  id<MTLBuffer> buf = (__bridge id<MTLBuffer>)bufHandle;
  return buf.length;
}

void mtl_release_buffer(MTLBufferHandle buffer) {
  if (buffer) {
    CFRelease(buffer);
  }
}

MTLCommandBufferHandle mtl_new_command_buffer(MTLCommandQueueHandle queue) {
  @autoreleasepool {
    id<MTLCommandQueue> commandQueue = (__bridge id<MTLCommandQueue>)queue;
    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    if (!commandBuffer) {
      return NULL;
    }
    return BRIDGE_RETAIN(commandBuffer);
  }
}

void mtl_release_command_buffer(MTLCommandBufferHandle commandBuffer) {
  if (commandBuffer) {
    CFRelease(commandBuffer);
  }
}

MTLComputeCommandEncoderHandle
mtl_new_compute_command_encoder(MTLCommandBufferHandle commandBuffer) {
  @autoreleasepool {
    NSLog(@"Creating new compute command encoder");
    id<MTLCommandBuffer> metalCommandBuffer =
        (__bridge id<MTLCommandBuffer>)commandBuffer;

    NSLog(@"fine 1");

    id<MTLComputeCommandEncoder> computeEncoder =
        [metalCommandBuffer computeCommandEncoder];
    NSLog(@"fine 2");

    return (__bridge_retained void *)computeEncoder;
    // return (void *)CFBridgingRetain(computeEncoder);
  }
}
void mtl_release_compute_command_encoder(
    MTLComputeCommandEncoderHandle encoder) {
  if (!encoder)
    return;
  CFRelease(encoder);
}

void mtl_test_set() {
  @autoreleasepool {
    // 1) Create device & queue
    id<MTLDevice> device = MTLCopyAllDevices().firstObject;
    id<MTLCommandQueue> queue = [device newCommandQueue];

    // 2) Load your metallib by explicit path
    NSError *error = nil;
    // Adjust this path as needed (relative or absolute)
    NSString *libPath = @"./test.metallib";
    NSURL *libURL = [NSURL fileURLWithPath:libPath];
    id<MTLLibrary> lib = [device newLibraryWithURL:libURL error:&error];
    if (!lib) {
      NSLog(@"✗ Failed to load metallib '%@': %@", libPath, error);
    }

    // 3) Grab your kernel
    id<MTLFunction> fn = [lib newFunctionWithName:@"add_arrays"];
    if (!fn) {
      NSLog(@"✗ 'add_array' not found in %@", libPath);
    }

    // 4) Create compute pipeline
    id<MTLComputePipelineState> pso =
        [device newComputePipelineStateWithFunction:fn error:&error];
    if (!pso) {
      NSLog(@"✗ Failed to create PSO: %@", error);
    }

    // 5) Prepare data
    const NSUInteger count = 1 << 20;
    size_t byteLen = count * sizeof(float);
    float *a = malloc(byteLen), *b = malloc(byteLen);
    for (NSUInteger i = 0; i < count; i++) {
      a[i] = (float)i;
      b[i] = (float)(count - i);
    }
    id<MTLBuffer> bufA =
        [device newBufferWithBytes:a
                            length:byteLen
                           options:MTLResourceStorageModeShared];
    id<MTLBuffer> bufB =
        [device newBufferWithBytes:b
                            length:byteLen
                           options:MTLResourceStorageModeShared];
    id<MTLBuffer> bufOut =
        [device newBufferWithLength:byteLen
                            options:MTLResourceStorageModeShared];

    // 6) Encode & dispatch
    id<MTLCommandBuffer> cmdBuf = [queue commandBuffer];
    id<MTLComputeCommandEncoder> enc = [cmdBuf computeCommandEncoder];
    [enc setComputePipelineState:pso];
    [enc setBuffer:bufA offset:0 atIndex:0];
    [enc setBuffer:bufB offset:0 atIndex:1];
    [enc setBuffer:bufOut offset:0 atIndex:2];
    MTLSize grid = MTLSizeMake(count, 1, 1);
    MTLSize tg =
        MTLSizeMake(MIN(pso.maxTotalThreadsPerThreadgroup, count), 1, 1);
    [enc dispatchThreads:grid threadsPerThreadgroup:tg];
    [enc endEncoding];

    // 7) Run & wait
    [cmdBuf commit];
    [cmdBuf waitUntilCompleted];

    // 8) Read back
    float *result = bufOut.contents;
    NSLog(@"✓ result[0]=%f, result[last]=%f", result[0], result[count - 1]);

    free(a);
    free(b);
  }
}

void mtl_end_encoding(MTLComputeCommandEncoderHandle encoder) {
  @autoreleasepool {
    id<MTLComputeCommandEncoder> computeEncoder =
        (__bridge id<MTLComputeCommandEncoder>)encoder;
    if (!computeEncoder) {
      NSLog(@"Invalid compute command encoder");
      return;
    }
    [computeEncoder endEncoding];
  }
}

void mtl_enc_set_compute_pipeline_state(
    MTLComputeCommandEncoderHandle encoder,
    MTLComputePipelineStateHandle pipelineState) {
  @autoreleasepool {
    id<MTLComputeCommandEncoder> computeEncoder =
        (__bridge id<MTLComputeCommandEncoder>)encoder;
    id<MTLComputePipelineState> metalPipelineState =
        (__bridge id<MTLComputePipelineState>)pipelineState;

    if (!computeEncoder || !metalPipelineState) {
      NSLog(@"Invalid encoder or pipeline state");
      return;
    }

    [computeEncoder setComputePipelineState:metalPipelineState];
  }
}

void mtl_enc_set_buffer(MTLComputeCommandEncoderHandle encoder,
                        MTLBufferHandle buffer, unsigned int offset,
                        unsigned int index) {
  @autoreleasepool {
    id<MTLComputeCommandEncoder> computeEncoder =
        (__bridge id<MTLComputeCommandEncoder>)encoder;
    id<MTLBuffer> metalBuffer = (__bridge id<MTLBuffer>)buffer;

    if (!computeEncoder || !metalBuffer) {
      NSLog(@"Invalid encoder or buffer");
      return;
    }

    [computeEncoder setBuffer:metalBuffer offset:offset atIndex:index];
  }
}

MTLSizeHandle mtl_size_make(unsigned int width, unsigned int height,
                            unsigned int depth) {
  @autoreleasepool {
    // NOTE: not sure bout this, scary
    MTLSize *size = (MTLSize *)malloc(sizeof(MTLSize));
    *size = MTLSizeMake(width, height, depth);
    return size;
  }
}

void mtl_enc_dispatch_threads(MTLComputeCommandEncoderHandle encoder,
                              unsigned int threadgroupsPerGridWidth,
                              unsigned int threadgroupsPerGridHeight,
                              unsigned int threadgroupsPerGridDepth,
                              unsigned int threadsPerThreadgroupWidth,
                              unsigned int threadsPerThreadgroupHeight,
                              unsigned int threadsPerThreadgroupDepth) {
  @autoreleasepool {
    id<MTLComputeCommandEncoder> computeEncoder =
        (__bridge id<MTLComputeCommandEncoder>)encoder;

    if (!computeEncoder) {
      NSLog(@"Invalid compute command encoder");
      return;
    }

    MTLSize tgPerGrid =
        MTLSizeMake(threadgroupsPerGridWidth, threadgroupsPerGridHeight,
                    threadgroupsPerGridDepth);
    MTLSize tg =
        MTLSizeMake(threadsPerThreadgroupWidth, threadsPerThreadgroupHeight,
                    threadsPerThreadgroupDepth);

    [computeEncoder dispatchThreads:tgPerGrid threadsPerThreadgroup:tg];
  }
}

void mtl_command_buffer_commit(MTLCommandBufferHandle commandBuffer) {
  @autoreleasepool {
    id<MTLCommandBuffer> metalCommandBuffer =
        (__bridge id<MTLCommandBuffer>)commandBuffer;

    if (!metalCommandBuffer) {
      NSLog(@"Invalid command buffer");
      return;
    }

    [metalCommandBuffer commit];
  }
}

void mtl_command_buffer_wait_until_completed(
    MTLCommandBufferHandle commandBuffer) {
  @autoreleasepool {
    id<MTLCommandBuffer> metalCommandBuffer =
        (__bridge id<MTLCommandBuffer>)commandBuffer;

    if (!metalCommandBuffer) {
      NSLog(@"Invalid command buffer");
      return;
    }

    [metalCommandBuffer waitUntilCompleted];
  }
}
