kernel void add_arrays(device const float* inA [[buffer(0)]],
                       device const float* inB [[buffer(1)]],
                       device float* result [[buffer(2)]],
                       uint index [[thread_position_in_grid]])
{
    // the for-loop is replaced with a collection of threads, each of which
    // calls this function.
    result[index] = inA[index] + inB[index];
}
