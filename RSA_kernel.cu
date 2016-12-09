__device__ long long int mod(int base, int exponent, int den) {

	long long int ret;
	ret = 1;
	for (int i = 0; i < exponent; i++) {
		ret *= base;
		ret = ret % den;
	}
	return ret;

}

__device__ long long int mod_optimized(int base, int exponent, int den) {

	unsigned int a = (base % den) * (base % den);
	unsigned long long int ret = 1;
	float size = (float) exponent / 2;
	if (exponent == 0) {
		return base % den;
	} else {
		while (1) {
			if (size > 0.5) {
				ret = (ret * a) % den;
				size = size - 1.0;
			} else if (size == 0.5) {
				ret = (ret * (base % den)) % den;
				break;
			} else {
				break;
			}
		}
		return ret;
	}

}

__global__ void rsa(int * num, int *key, int *den, int * result) {
	int i = blockDim.x * blockIdx.x + threadIdx.x;
	int temp;
	temp = mod(num[i], *key, *den);
	//temp = mod_optimized(num[i], *key, *den);
	atomicExch(&result[i], temp);
}
