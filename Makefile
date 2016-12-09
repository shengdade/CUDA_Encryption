default:
	nvcc -arch=sm_52 -o RSA RSA.cu
clean:
	rm -f RSA
	rm -f decrypted_cpu.txt
	rm -f decrypted_gpu.txt
	rm -f encrypted_cpu.txt
	rm -f encrypted_gpu.txt
	rm -f input.txt
