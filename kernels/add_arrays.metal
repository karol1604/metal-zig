kernel void add_arrays(device const uint* inA [[buffer(0)]],
                       device const uint* inB [[buffer(1)]],
					   constant uint& offset [[buffer(2)]],
                       device uint* result [[buffer(3)]],
                       uint index [[thread_position_in_grid]])
{
    result[index] = inA[index] + inB[index] + offset;
}
