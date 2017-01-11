// cubehash256
// djm34 2015 based on ccminer cubehash512

#define CUBEHASH_ROUNDS 16 /* this is r for CubeHashr/b */
#define CUBEHASH_BLOCKBYTES 32 /* this is b for CubeHashr/b */


#define LROT(x, bits) rotate( x,(uint) bits)


#define ROTATEUPWARDS7(a)  LROT(a,7)
#define ROTATEUPWARDS11(a) LROT(a,11)

#define SWAP(a,b) { uint u = a; a = b; b = u; }

inline void rrounds(uint x[2][2][2][2][2])
{
	int r;
	int j;
	int k;
	int l;
	int m;

//#pragma unroll 2
	for (r = 0; r < CUBEHASH_ROUNDS; ++r) {

		/* "add x_0jklm into x_1jklmn modulo 2^32" */
//#pragma unroll 2
		for (j = 0; j < 2; ++j)
//#pragma unroll 2
			for (k = 0; k < 2; ++k)
//#pragma unroll 2
				for (l = 0; l < 2; ++l)
//#pragma unroll 2
					for (m = 0; m < 2; ++m)
						x[1][j][k][l][m] += x[0][j][k][l][m];

		/* "rotate x_0jklm upwards by 7 bits" */
//#pragma unroll 2
		for (j = 0; j < 2; ++j)
//#pragma unroll 2
			for (k = 0; k < 2; ++k)
//#pragma unroll 2
				for (l = 0; l < 2; ++l)
//#pragma unroll 2
					for (m = 0; m < 2; ++m)
						x[0][j][k][l][m] = ROTATEUPWARDS7(x[0][j][k][l][m]);

		/* "swap x_00klm with x_01klm" */
//#pragma unroll 2
		for (k = 0; k < 2; ++k)
//#pragma unroll 2
			for (l = 0; l < 2; ++l)
//#pragma unroll 2
				for (m = 0; m < 2; ++m)
					SWAP(x[0][0][k][l][m], x[0][1][k][l][m])

					/* "xor x_1jklm into x_0jklm" */
//#pragma unroll 2
					for (j = 0; j < 2; ++j)
//#pragma unroll 2
						for (k = 0; k < 2; ++k)
//#pragma unroll 2
							for (l = 0; l < 2; ++l)
//#pragma unroll 2
								for (m = 0; m < 2; ++m)
									x[0][j][k][l][m] ^= x[1][j][k][l][m];

		/* "swap x_1jk0m with x_1jk1m" */
//#pragma unroll 2
		for (j = 0; j < 2; ++j)
//#pragma unroll 2
			for (k = 0; k < 2; ++k)
//#pragma unroll 2
				for (m = 0; m < 2; ++m)
					SWAP(x[1][j][k][0][m], x[1][j][k][1][m])

					/* "add x_0jklm into x_1jklm modulo 2^32" */
//#pragma unroll 2
					for (j = 0; j < 2; ++j)
//#pragma unroll 2
						for (k = 0; k < 2; ++k)
//#pragma unroll 2
							for (l = 0; l < 2; ++l)
//#pragma unroll 2
								for (m = 0; m < 2; ++m)
									x[1][j][k][l][m] += x[0][j][k][l][m];

		/* "rotate x_0jklm upwards by 11 bits" */
//#pragma unroll 2
		for (j = 0; j < 2; ++j)
//#pragma unroll 2
			for (k = 0; k < 2; ++k)
//#pragma unroll 2
				for (l = 0; l < 2; ++l)
//#pragma unroll 2
					for (m = 0; m < 2; ++m)
						x[0][j][k][l][m] = ROTATEUPWARDS11(x[0][j][k][l][m]);

		/* "swap x_0j0lm with x_0j1lm" */
//#pragma unroll 2
		for (j = 0; j < 2; ++j)
//#pragma unroll 2
			for (l = 0; l < 2; ++l)
//#pragma unroll 2
				for (m = 0; m < 2; ++m)
					SWAP(x[0][j][0][l][m], x[0][j][1][l][m])

					/* "xor x_1jklm into x_0jklm" */
//#pragma unroll 2
					for (j = 0; j < 2; ++j)
//#pragma unroll 2
						for (k = 0; k < 2; ++k)
//#pragma unroll 2
							for (l = 0; l < 2; ++l)
//#pragma unroll 2
								for (m = 0; m < 2; ++m)
									x[0][j][k][l][m] ^= x[1][j][k][l][m];

		/* "swap x_1jkl0 with x_1jkl1" */
//#pragma unroll 2
		for (j = 0; j < 2; ++j)
//#pragma unroll 2
			for (k = 0; k < 2; ++k)
//#pragma unroll 2
				for (l = 0; l < 2; ++l)
					SWAP(x[1][j][k][l][0], x[1][j][k][l][1])

	}
}


