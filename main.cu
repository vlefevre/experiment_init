#include <iostream>
#include <string>
	
template <typename T>
std::string typeStr()
{
	if constexpr (std::is_same_v<T,float>)
		return "float";
	if constexpr (std::is_same_v<T,double>)
		return "double";
	if constexpr (std::is_same_v<T,int>)
		return "int";
}

template<typename T, int VEC>
struct VecType;

template<> struct VecType<float,4> { using type = float4; };
template<> struct VecType<int,4>   { using type = int4; };
template<> struct VecType<double,2>{ using type = double2; };

template <typename T>
__global__ void initArray(int N, T* v, T val)
{
	int tid = threadIdx.x + blockIdx.x*blockDim.x;
	int stride = gridDim.x * blockDim.x;
	for (int i=tid; i<N; i+=stride)
		v[i] = val;
}

template <typename T>
__global__ void initArrayUnroll4(int N, T* v, T val)
{
	int tid = threadIdx.x + blockIdx.x*blockDim.x;
	int stride = gridDim.x * blockDim.x;
#pragma unroll 4
	for (int i=tid; i<N; i+=stride)
		v[i] = val;
}

template <typename T>
__global__ void initArrayManualUnroll4(int N, T* v, T val)
{
	int tid = threadIdx.x + blockIdx.x*blockDim.x;
	int stride = blockDim.x * gridDim.x;
	int i = tid;
	int full_stride = 4*stride;
	int limit = (N/full_stride)*full_stride;
	for (; i<limit; i+=full_stride)
	{
		v[i] = val;
		v[i+stride] = val;
		v[i+2*stride] = val;
		v[i+3*stride] = val;
	}
	//last elements
	for (; i <N; i+=stride)
		v[i] = val;
}

template <typename T>
__global__ void initArrayVec4(int N, T* v, T val)
{
	using VecT = typename VecType<T,4>::type;
	int tid = blockIdx.x * blockDim.x + threadIdx.x;
	int stride = blockDim.x * gridDim.x;
	// reinterpret pointer as vector type
	VecT* v_v = reinterpret_cast<VecT*>(v);

	VecT val4;
	#pragma unroll
	for (int i=0; i<4; i++) {
		reinterpret_cast<T*>(&val4)[i] = val;
	}

	// number of full vectors
	size_t N_vec = N / 4;
	for (int i=tid; i<N_vec; i+=stride)
		v_v[i] = val4;

	//last elements
	for (int i = N_vec*4 + tid; i<N; i+=stride)
		v[i] = val;

}
#define XSTR(x) STR(x)
#define STR(x) #x

#ifndef KERNEL_NAME
#define KERNEL_NAME initArray
#endif

#ifndef DATATYPE
#define DATATYPE float
#endif

#ifndef NITERS
#define NITERS 1000
#endif

#ifndef NWARMUPS
#define NWARMUPS 20
#endif

int main(int argc, char **argv)
{
	using dtype = DATATYPE;

	int N = 1<<20; //array size
	dtype value = static_cast<dtype>(2.03f);

	int nthreads = 128;
	int nblocks = 128;

	if (argc > 1)
		N = atoi(argv[1]);
	if (argc > 2)
		nthreads = atoi(argv[2]);
	if (argc > 3)
		nblocks = atoi(argv[3]);

	size_t size = sizeof(dtype)*N;

	float current_time = 0.0f, total_time = 0.0f;

	std::cout << "ARRAY SIZE   " << N << "\n";
	std::cout << "DATATYPE     " << typeStr<dtype>() << "\n";
	std::cout << "MEMORY SIZE  " << size/1024./1024. << " MB\n";
	std::cout << "KERNEL       " << XSTR(KERNEL_NAME) << "\n";
	std::cout << "#THREADS     " << nthreads << "\n";
	std::cout << "#BLOCKS      " << nblocks << "\n";
	if constexpr (XSTR(KERNEL_NAME) == "initArray")
		std::cout << "#ELTS/THR    " << (double)N/double(nthreads*nblocks) << "\n";
	else
		std::cout << "#ELTS/THR    " << (double)N/double(nthreads)*nblocks*4 << "\n";
	dtype *data;
	cudaMalloc(&data, size);

	for (int i=0; i<NWARMUPS; i++)
		KERNEL_NAME<<<nblocks, nthreads>>>(N, data, value);

	cudaEvent_t start,end;

	cudaEventCreate(&start);
	cudaEventCreate(&end);
	
	std::cout << "ITERATIONS   " << NITERS << "\n";
	for (int i=0; i<NITERS; i++)
	{
		cudaEventRecord(start);
		KERNEL_NAME<<<nblocks, nthreads>>>(N, data, value);
		cudaEventRecord(end);
		cudaEventSynchronize(end);
		cudaEventElapsedTime(&current_time, start, end);
		total_time += current_time;
	}
	std::cout << "AVG. TIME    " << total_time*1000./(float)NITERS << " µs\n";

	cudaFree(data);
	cudaEventDestroy(start);
	cudaEventDestroy(end);
}
