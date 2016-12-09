#include <stdio.h>
#include <time.h>
#include "RSA_kernel.cu"
#define BUZZ_SIZE 10002

int p, q, n, t, flag, e[100], d[100], temp[BUZZ_SIZE], j, m[BUZZ_SIZE],
		en[BUZZ_SIZE], mm[BUZZ_SIZE], res[BUZZ_SIZE], i;
char msg[BUZZ_SIZE];
int prime(long int);
void generate_input(int);
void ce();
long int cd(long int);
void encrypt();
void decrypt();
void encrypt_gpu();
void decrypt_gpu();
int numChars;
int threadsPerBlock = 1024;
int blocksPerGrid;
time_t tt;
double time_encrypt_cpu, time_decrypt_cpu;
float time_encrypt_gpu = 0.0;
float time_decrypt_gpu = 0.0;

int main() {

	p = 157;
	q = 373;

	srand((unsigned) time(&tt));/* Intializes random number generator */
	generate_input(10000);

	FILE *f = fopen("input.txt", "r");
	if (f == NULL) {
		perror("Error opening file");
		return (1);
	}
	if (fgets(msg, BUZZ_SIZE, f) != NULL) {
		//printf("String read: %s\n", msg);
		printf("Reading input file...done(");
	}
	fclose(f);

	numChars = strlen(msg) - 1;
	msg[numChars] = '\0';
	printf("numChars: %d)\n\n", numChars);
	blocksPerGrid = (numChars + threadsPerBlock - 1) / threadsPerBlock;

	/*
	 printf("\nENTER MESSAGE\n");
	 fflush(stdin);
	 scanf("%s", msg);
	 numChars = strlen(msg);
	 blocksPerGrid =(numChars + threadsPerBlock - 1) / threadsPerBlock;
	 */

	for (i = 0; msg[i] != '\0'; i++) {
		m[i] = msg[i];
		mm[i] = msg[i] - 96;
	}
	n = p * q;
	t = (p - 1) * (q - 1);
	ce();
	/*
	 printf("\nPOSSIBLE VALUES OF e AND d ARE\n");
	 for (i = 0; i < j - 1; i++)
	 printf("\n%ld\t%ld", e[i], d[i]);
	 */

	encrypt();
	decrypt();
	encrypt_gpu();
	decrypt_gpu();
	printf("GPU encryption speed up: %f\n",
			time_encrypt_cpu / time_encrypt_gpu);
	printf("GPU decryption speed up: %f\n\n",
			time_decrypt_cpu / time_decrypt_gpu);

	return 0;
}

void generate_input(int size) {
	printf("\nGenerating input file... ");
	FILE *fp = fopen("input.txt", "wb");
	if (fp != NULL) {
		for (int k = 0; k < size; k++) {
			int r = rand() % 26;
			fprintf(fp, "%c", r + 97);
		}
		fprintf(fp, "\n");
		fclose(fp);
		printf("done\n");
	}
}

int prime(long int pr) {
	int i;
	j = sqrt(pr);
	for (i = 2; i <= j; i++) {
		if (pr % i == 0)
			return 0;
	}
	return 1;
}

void ce() {
	int k;
	k = 0;
	for (i = 2; i < t; i++) {
		if (t % i == 0)
			continue;
		flag = prime(i);
		if (flag == 1 && i != p && i != q) {
			e[k] = i;
			flag = cd(e[k]);
			if (flag > 0) {
				d[k] = flag;
				k++;
			}
			if (k == 99)
				break;
		}
	}
}

long int cd(long int x) {
	long int k = 1;
	while (1) {
		k = k + t;
		if (k % x == 0)
			return (k / x);
	}
}

void encrypt() {
	double start_encrypt, end_encrypt;
	start_encrypt = clock();
	printf("CPU starts encrypting...\n");
	int pt, ct, key = e[0], k, len;
	printf("\ne=%d\n",key);
	i = 0;
	len = numChars;
	while (i != len) {
		pt = m[i];
		pt = pt - 96;
		k = 1;
		for (j = 0; j < key; j++) {
			k = k * pt;
			k = k % n;
		}
		temp[i] = k;
		ct = k + 96;
		en[i] = ct;
		i++;
	}
	end_encrypt = clock();
	time_encrypt_cpu = (double) (end_encrypt - start_encrypt) / CLOCKS_PER_SEC;
	printf("Encryption time taken by CPU: %f s\n", time_encrypt_cpu);
	/*
	 en[i] = -1;
	 printf("\nCPU ENCRYPTED MESSAGE IS\n");
	 for (i = 0; en[i] != -1; i++)
	 printf("%d ", en[i]);
	 */

	printf("Saving CPU encrypted file... ");
	en[i] = -1;
	FILE *fp = fopen("encrypted_cpu.txt", "wb");
	if (fp != NULL) {
		for (int k = 0; en[k] != -1; k++) {
			fprintf(fp, "%d", en[k]);
		}
		fclose(fp);
		printf("done\n\n");
	}
}

void encrypt_gpu() {
	cudaEvent_t start_encrypt, stop_encrypt;
	int key = e[0];
	//printf("\nkey=%d, n=%d\n",key,n);
	cudaSetDevice(1);
	int *dev_num, *dev_key, *dev_den;
	int *dev_res;
	cudaMalloc((void **) &dev_num, numChars * sizeof(int));
	cudaMalloc((void **) &dev_key, sizeof(int));
	cudaMalloc((void **) &dev_den, sizeof(int));
	cudaMalloc((void **) &dev_res, numChars * sizeof(int));
	cudaMemcpy(dev_num, mm, numChars * sizeof(int), cudaMemcpyHostToDevice);
	cudaMemcpy(dev_key, &key, sizeof(int), cudaMemcpyHostToDevice);
	cudaMemcpy(dev_den, &n, sizeof(int), cudaMemcpyHostToDevice);
	cudaMemcpy(dev_res, res, numChars * sizeof(int), cudaMemcpyHostToDevice);

	cudaEventCreate(&start_encrypt);
	cudaEventCreate(&stop_encrypt);
	cudaEventRecord(start_encrypt);
	printf("GPU starts encrypting...\n");
	rsa<<<blocksPerGrid, threadsPerBlock>>>(dev_num,dev_key,dev_den,dev_res);
	cudaEventRecord(stop_encrypt);
	cudaEventSynchronize(stop_encrypt);
	cudaThreadSynchronize();
	cudaEventElapsedTime(&time_encrypt_gpu, start_encrypt, stop_encrypt);

	cudaMemcpy(res, dev_res, numChars * sizeof(int), cudaMemcpyDeviceToHost);
	cudaFree(dev_num);
	cudaFree(dev_key);
	cudaFree(dev_den);
	cudaFree(dev_res);

	time_encrypt_gpu /= 1000;
	printf("Encryption time taken by GPU: %f s\n", time_encrypt_gpu);

	/*
	 printf("\nGPU ENCRYPTED MESSAGE IS\n");
	 for (i = 0; i < numChars; i++)
	 printf("%d ", res[i]+96);
	 printf("\n");
	 */

	printf("Saving GPU encrypted file... ");
	FILE *fp = fopen("encrypted_gpu.txt", "wb");
	if (fp != NULL) {
		for (i = 0; i < numChars; i++) {
			fprintf(fp, "%d", res[i] + 96);
		}
		fclose(fp);
		printf("done\n\n");
	}
}

void decrypt_gpu() {
	cudaEvent_t start_decrypt, stop_decrypt;
	int key = d[0];
	//printf("\nkey=%d, n=%d\n",key,n);
	cudaSetDevice(1);
	int *dev_num, *dev_key, *dev_den;
	int *dev_res;
	cudaMalloc((void **) &dev_num, numChars * sizeof(int));
	cudaMalloc((void **) &dev_key, sizeof(int));
	cudaMalloc((void **) &dev_den, sizeof(int));
	cudaMalloc((void **) &dev_res, numChars * sizeof(int));
	cudaMemcpy(dev_num, res, numChars * sizeof(int), cudaMemcpyHostToDevice);
	cudaMemcpy(dev_key, &key, sizeof(int), cudaMemcpyHostToDevice);
	cudaMemcpy(dev_den, &n, sizeof(int), cudaMemcpyHostToDevice);
	cudaMemcpy(dev_res, res, numChars * sizeof(int), cudaMemcpyHostToDevice);

	cudaEventCreate(&start_decrypt);
	cudaEventCreate(&stop_decrypt);
	cudaEventRecord(start_decrypt);
	printf("GPU starts decrypting...\n");
	rsa<<<blocksPerGrid, threadsPerBlock>>>(dev_num,dev_key,dev_den,dev_res);
	cudaEventRecord(stop_decrypt);
	cudaEventSynchronize(stop_decrypt);
	cudaThreadSynchronize();
	cudaEventElapsedTime(&time_decrypt_gpu, start_decrypt, stop_decrypt);

	cudaMemcpy(res, dev_res, numChars * sizeof(int), cudaMemcpyDeviceToHost);
	cudaFree(dev_num);
	cudaFree(dev_key);
	cudaFree(dev_den);
	cudaFree(dev_res);

	time_decrypt_gpu /= 1000;
	printf("Decryption time taken by GPU: %f s\n", time_decrypt_gpu);

	/*
	 printf("\nGPU DECRYPTED MESSAGE IS\n");
	 for (i = 0; i < numChars; i++)
	 printf("%d ", res[i]+96);
	 printf("\n");
	 */

	printf("Saving GPU decrypted file... ");
	FILE *fp = fopen("decrypted_gpu.txt", "wb");
	if (fp != NULL) {
		for (i = 0; i < numChars; i++) {
			fprintf(fp, "%c", res[i] + 96);
		}
		fprintf(fp, "\n");
		fclose(fp);
		printf("done\n\n");
	}
}

void decrypt() {
	double start_decrypt, end_decrypt;
	start_decrypt = clock();
	printf("CPU starts decrypting...\n");
	long int pt, ct, key = d[0], k;
	printf("\nd=%d\n",key);
	i = 0;
	while (en[i] != -1) {
		ct = temp[i];
		k = 1;
		for (j = 0; j < key; j++) {
			k = k * ct;
			k = k % n;
		}
		pt = k + 96;
		m[i] = pt;
		i++;
	}
	end_decrypt = clock();
	time_decrypt_cpu = (double) (end_decrypt - start_decrypt) / CLOCKS_PER_SEC;
	printf("Decryption time taken by CPU: %f s\n", time_decrypt_cpu);

	/*
	 m[i] = -1;
	 printf("\nCPU DECRYPTED MESSAGE IS\n");
	 for (i = 0; m[i] != -1; i++)
	 printf("%d ", m[i]);
	 printf("\n");
	 */

	printf("Saving CPU decrypted file... ");
	m[i] = -1;
	FILE *fp = fopen("decrypted_cpu.txt", "wb");
	if (fp != NULL) {
		for (int k = 0; m[k] != -1; k++) {
			fprintf(fp, "%c", m[k]);
		}
		fprintf(fp, "\n");
		fclose(fp);
		printf("done\n\n");
	}
}
