//  Copyright John Maddock 2016.
//  Use, modification and distribution are subject to the
//  Boost Software License, Version 1.0. (See accompanying file
//  LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)


#include <iostream>
#include <iomanip>
#include <boost/math/special_functions.hpp>
#include "cuda_managed_ptr.hpp"

// For the CUDA runtime routines (prefixed with "cuda_")
#include <cuda_runtime.h>

typedef float float_type;

/**
 * CUDA Kernel Device code
 *
 */
__global__ void cuda_test(const float_type *in, float_type *out, int numElements)
{
    using std::cos;
    int i = blockDim.x * blockIdx.x + threadIdx.x;

    if (i < numElements)
    {
        out[i] = boost::math::cbrt(in[i]);
    }
}

/**
 * Host main routine
 */
int main(void)
{
    // Error code to check return values for CUDA calls
    cudaError_t err = cudaSuccess;

    // Print the vector length to be used, and compute its size
    int numElements = 50000;
    std::cout << "[Vector addition of " << numElements << " elements]" << std::endl;

    // Allocate the managed input vector A
    cuda_managed_ptr<float_type> h_A(numElements);

    // Allocate the managed output vector C
    cuda_managed_ptr<float_type> h_C(numElements);

    // Initialize the input vectors
    for (int i = 0; i < numElements; ++i)
    {
        h_A[i] = rand()/(float_type)RAND_MAX;
    }

    // Launch the Vector Add CUDA Kernel
    int threadsPerBlock = 256;
    int blocksPerGrid =(numElements + threadsPerBlock - 1) / threadsPerBlock;
    std::cout << "CUDA kernel launch with " << blocksPerGrid << " blocks of " << threadsPerBlock << " threads" << std::endl;
    
    cuda_test<<<blocksPerGrid, threadsPerBlock>>>(h_A.get(), h_C.get(), numElements);
    std::cout << "CUDA kernal done!" << std::endl;
    
    err = cudaGetLastError();

    if (err != cudaSuccess)
    {
        std::cerr << "Failed to launch vectorAdd kernel (error code " << cudaGetErrorString(err) << ")!" << std::endl;
        return EXIT_FAILURE;
    }

    // Verify that the result vector is correct
    std::vector<float_type> results;
    results.reserve(numElements);
    for(int i = 0; i < numElements; ++i)
       results.push_back(boost::math::cbrt(h_A[i]));
    // check the results
    for(int i = 0; i < numElements; ++i)
    {
        if (boost::math::epsilon_difference(h_C[i], results[i]) > 10)
        {
            std::cerr << "Result verification failed at element " << i << "!" << std::endl;
            return EXIT_FAILURE;
        }
    }

    std::cout << "Test PASSED" << std::endl;

    // Reset the device and exit
    // cudaDeviceReset causes the driver to clean up all state. While
    // not mandatory in normal operation, it is good practice.  It is also
    // needed to ensure correct operation when the application is being
    // profiled. Calling cudaDeviceReset causes all profile data to be
    // flushed before the application exits
    err = cudaDeviceReset();

    if (err != cudaSuccess)
    {
        std::cerr << "Failed to deinitialize the device! error=" << cudaGetErrorString(err) << std::endl;
        return EXIT_FAILURE;
    }

    std::cout << "Done\n";

    return 0;
}

