// NeoScrypt(128, 2, 1) with Salsa20/20 and ChaCha20/20
// By Wolf (Wolf0 aka Wolf9466)

// Stupid AMD compiler ignores the unroll pragma in these two

// Tahiti 3/2, 
// Hawaii 4/4 + notneededswap
// Pitcairn 3/4 + notneededswap
#if defined(__Tahiti__)
#define SALSA_SMALL_UNROLL 4
#define CHACHA_SMALL_UNROLL 2
//#define SWAP 1
//#define SHITMAIN 1
//#define WIDE_STRIPE 1
#elif defined(__Pitcairn__)

#define SALSA_SMALL_UNROLL 3
#define CHACHA_SMALL_UNROLL 2
//#define SWAP 1
//#define SHITMAIN 1
//#define WIDE_STRIPE 1

#else
#define SALSA_SMALL_UNROLL 4
#define CHACHA_SMALL_UNROLL 4
//#define SWAP 1
//#define SHITMAIN 1
//#define WIDE_STRIPE 1
#endif

// If SMALL_BLAKE2S is defined, BLAKE2S_UNROLL is interpreted
// as the unroll factor; must divide cleanly into ten.
// Usually a bad idea.
//#define SMALL_BLAKE2S
//#define BLAKE2S_UNROLL 5

#define BLOCK_SIZE           64U
#define FASTKDF_BUFFER_SIZE 256U
#ifndef PASSWORD_LEN
#define PASSWORD_LEN         80U
#endif

#if !defined(cl_khr_byte_addressable_store)
#error "Device does not support unaligned stores"
#endif

// Swaps 128 bytes at a time without using temp vars
void SwapBytes128(void *restrict A, void *restrict B, uint len)
{
	#pragma unroll 2
	for(int i = 0; i < (len >> 7); ++i)
	{
		((ulong16 *)A)[i] ^= ((ulong16 *)B)[i];
		((ulong16 *)B)[i] ^= ((ulong16 *)A)[i];
		((ulong16 *)A)[i] ^= ((ulong16 *)B)[i];
	}
}

void CopyBytes128(void *restrict dst, const void *restrict src, uint len)
{
	#pragma unroll 2
    for(int i = 0; i < len; ++i)
		((ulong16 *)dst)[i] = ((ulong16 *)src)[i];
}

void CopyBytes(void *restrict dst, const void *restrict src, uint len)
{
    for(int i = 0; i < len; ++i)
		((uchar *)dst)[i] = ((uchar *)src)[i];
}

void XORBytesInPlace(void *restrict dst, const void *restrict src, uint len)
{
	for(int i = 0; i < len; ++i)
		((uchar *)dst)[i] ^= ((uchar *)src)[i];
}

void XORBytes(void *restrict dst, const void *restrict src1, const void *restrict src2, uint len)
{
	#pragma unroll 1
	for(int i = 0; i < len; ++i)
		((uchar *)dst)[i] = ((uchar *)src1)[i] ^ ((uchar *)src2)[i];
}

// Blake2S

#define BLAKE2S_BLOCK_SIZE    64U
#define BLAKE2S_OUT_SIZE      32U
#define BLAKE2S_KEY_SIZE      32U

static const __constant uint BLAKE2S_IV[8] =
{
    0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A,
    0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19
};

static const __constant uchar BLAKE2S_SIGMA[10][16] =
{
    {  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15 } ,
    { 14, 10,  4,  8,  9, 15, 13,  6,  1, 12,  0,  2, 11,  7,  5,  3 } ,
    { 11,  8, 12,  0,  5,  2, 15, 13, 10, 14,  3,  6,  7,  1,  9,  4 } ,
    {  7,  9,  3,  1, 13, 12, 11, 14,  2,  6,  5, 10,  4,  0, 15,  8 } ,
    {  9,  0,  5,  7,  2,  4, 10, 15, 14,  1, 11, 12,  6,  8,  3, 13 } ,
    {  2, 12,  6, 10,  0, 11,  8,  3,  4, 13,  7,  5, 15, 14,  1,  9 } ,
    { 12,  5,  1, 15, 14, 13,  4, 10,  0,  7,  6,  3,  9,  2,  8, 11 } ,
    { 13, 11,  7, 14, 12,  1,  3,  9,  5,  0, 15,  4,  8,  6,  2, 10 } ,
    {  6, 15, 14,  9, 11,  3,  0,  8, 12,  2, 13,  7,  1,  4, 10,  5 } ,
    { 10,  2,  8,  4,  7,  6,  1,  5, 15, 11,  9, 14,  3, 12, 13 , 0 } ,
};

#define BLAKE_G(idx0, idx1, a, b, c, d, key)	do { \
	a += b + key[BLAKE2S_SIGMA[idx0][idx1]]; \
	d = rotate(d ^ a, 16U); \
	c += d; \
	b = rotate(b ^ c, 20U); \
	a += b + key[BLAKE2S_SIGMA[idx0][idx1 + 1]]; \
	d = rotate(d ^ a, 24U); \
	c += d; \
	b = rotate(b ^ c, 25U); \
} while(0)

#define BLAKE_PARALLEL_G1(idx0, a, b, c, d, key)	do { \
	a += b + (uint4)(key[BLAKE2S_SIGMA[idx0][0]], key[BLAKE2S_SIGMA[idx0][2]], key[BLAKE2S_SIGMA[idx0][4]], key[BLAKE2S_SIGMA[idx0][6]]); \
	d = rotate(d ^ a, 16U); \
	c += d; \
	b = rotate(b ^ c, 20U); \
	a += b + (uint4)(key[BLAKE2S_SIGMA[idx0][1]], key[BLAKE2S_SIGMA[idx0][3]], key[BLAKE2S_SIGMA[idx0][5]], key[BLAKE2S_SIGMA[idx0][7]]); \
	d = rotate(d ^ a, 24U); \
	c += d; \
	b = rotate(b ^ c, 25U); \
} while(0)

#define BLAKE_PARALLEL_G2(idx0, a, b, c, d, key)	do { \
	a += b + (uint4)(key[BLAKE2S_SIGMA[idx0][8]], key[BLAKE2S_SIGMA[idx0][10]], key[BLAKE2S_SIGMA[idx0][12]], key[BLAKE2S_SIGMA[idx0][14]]); \
	d = rotate(d ^ a, 16U); \
	c += d; \
	b = rotate(b ^ c, 20U); \
	a += b + (uint4)(key[BLAKE2S_SIGMA[idx0][9]], key[BLAKE2S_SIGMA[idx0][11]], key[BLAKE2S_SIGMA[idx0][13]], key[BLAKE2S_SIGMA[idx0][15]]); \
	d = rotate(d ^ a, 24U); \
	c += d; \
	b = rotate(b ^ c, 25U); \
} while(0)

void Blake2S(uint *restrict inout, const uint *restrict inkey)
{
	uint16 V;
	uint8 tmpblock;

	// Load first block (IV into V.lo) and constants (IV into V.hi)
	V.lo = V.hi = vload8(0U, BLAKE2S_IV);

	// XOR with initial constant
	V.s0 ^= 0x01012020;

	// Copy input block for later
	tmpblock = V.lo;

	// XOR length of message so far (including this block)
	// There are two uints for this field, but high uint is zero
	V.sc ^= BLAKE2S_BLOCK_SIZE;

	// Compress state, using the key as the key
	#ifdef SMALL_BLAKE2S
	#pragma unroll BLAKE2S_UNROLL
	#else
	#pragma unroll
	#endif
	for(int x = 0; x < 10; ++x)
	{
		/*BLAKE_G(x, 0x00, V.s0, V.s4, V.s8, V.sc, inkey);
		BLAKE_G(x, 0x02, V.s1, V.s5, V.s9, V.sd, inkey);
		BLAKE_G(x, 0x04, V.s2, V.s6, V.sa, V.se, inkey);
		BLAKE_G(x, 0x06, V.s3, V.s7, V.sb, V.sf, inkey);
		BLAKE_G(x, 0x08, V.s0, V.s5, V.sa, V.sf, inkey);
		BLAKE_G(x, 0x0A, V.s1, V.s6, V.sb, V.sc, inkey);
		BLAKE_G(x, 0x0C, V.s2, V.s7, V.s8, V.sd, inkey);
		BLAKE_G(x, 0x0E, V.s3, V.s4, V.s9, V.se, inkey);*/
		
		BLAKE_PARALLEL_G1(x, V.s0123, V.s4567, V.s89ab, V.scdef, inkey);
		BLAKE_PARALLEL_G2(x, V.s0123, V.s5674, V.sab89, V.sfcde, inkey);
	}

	// XOR low part of state with the high part,
	// then with the original input block.
	V.lo ^= V.hi ^ tmpblock;

	// Load constants (IV into V.hi)
	V.hi = vload8(0U, BLAKE2S_IV);

	// Copy input block for later
	tmpblock = V.lo;

	// XOR length of message into block again
	V.sc ^= BLAKE2S_BLOCK_SIZE << 1;

	// Last block compression - XOR final constant into state
	V.se ^= 0xFFFFFFFFU;

	// Compress block, using the input as the key
	#ifdef SMALL_BLAKE2S
	#pragma unroll BLAKE2S_UNROLL
	#else
	#pragma unroll
	#endif
	for(int x = 0; x < 10; ++x)
	{
		/*BLAKE_G(x, 0x00, V.s0, V.s4, V.s8, V.sc, inout);
		BLAKE_G(x, 0x02, V.s1, V.s5, V.s9, V.sd, inout);
		BLAKE_G(x, 0x04, V.s2, V.s6, V.sa, V.se, inout);
		BLAKE_G(x, 0x06, V.s3, V.s7, V.sb, V.sf, inout);
		BLAKE_G(x, 0x08, V.s0, V.s5, V.sa, V.sf, inout);
		BLAKE_G(x, 0x0A, V.s1, V.s6, V.sb, V.sc, inout);
		BLAKE_G(x, 0x0C, V.s2, V.s7, V.s8, V.sd, inout);
		BLAKE_G(x, 0x0E, V.s3, V.s4, V.s9, V.se, inout);*/
		
		BLAKE_PARALLEL_G1(x, V.s0123, V.s4567, V.s89ab, V.scdef, inout);
		BLAKE_PARALLEL_G2(x, V.s0123, V.s5674, V.sab89, V.sfcde, inout);
	}

	// XOR low part of state with high part, then with input block
	V.lo ^= V.hi ^ tmpblock;

	// Store result in input/output buffer
	vstore8(V.lo, 0, inout);
}

/* FastKDF, a fast buffered key derivation function:
 * FASTKDF_BUFFER_SIZE must be a power of 2;
 * password_len, salt_len and output_len should not exceed FASTKDF_BUFFER_SIZE;
 * prf_output_size must be <= prf_key_size; */
void fastkdf(const uchar *restrict password, const uchar *restrict salt, const uint salt_len, uchar *restrict output, uint output_len)
{

	/*                    WARNING!
	 * This algorithm uses byte-wise addressing for memory blocks.
	 * Or in other words, trying to copy an unaligned memory region
	 * will significantly slow down the algorithm, when copying uses
	 * words or bigger entities. It even may corrupt the data, when
	 * the device does not support it properly.
	 * Therefore use byte copying, which will not the fastest but at
	 * least get reliable results. */

	// BLOCK_SIZE            64U
	// FASTKDF_BUFFER_SIZE  256U
	// BLAKE2S_BLOCK_SIZE    64U
	// BLAKE2S_KEY_SIZE      32U
	// BLAKE2S_OUT_SIZE      32U
	uchar bufidx = 0;
	uint8 Abuffer[9], Bbuffer[9] = { (uint8)(0) };
	uchar *A = (uchar *)Abuffer, *B = (uchar *)Bbuffer;

	// Initialize the password buffer
	#pragma unroll 1
	for(int i = 0; i < (FASTKDF_BUFFER_SIZE >> 3); ++i) ((ulong *)A)[i] = ((ulong *)password)[i % 10];

	((uint16 *)(A + FASTKDF_BUFFER_SIZE))[0] = ((uint16 *)password)[0];

	// Initialize the salt buffer
	if(salt_len == FASTKDF_BUFFER_SIZE)
	{
		((ulong16 *)B)[0] = ((ulong16 *)B)[2] = ((ulong16 *)salt)[0];
		((ulong16 *)B)[1] = ((ulong16 *)B)[3] = ((ulong16 *)salt)[1];
	}
	else
	{
		// salt_len is 80 bytes here
		#pragma unroll 1
		for(int i = 0; i < (FASTKDF_BUFFER_SIZE >> 3); ++i) ((ulong *)B)[i] = ((ulong *)salt)[i % 10];

		// Initialized the rest to zero earlier
		#pragma unroll 1
		for(int i = 0; i < 10; ++i) ((ulong *)(B + FASTKDF_BUFFER_SIZE))[i] = ((ulong *)salt)[i];
	}

    // The primary iteration
    #pragma unroll 1
    for(int i = 0; i < 32; ++i)
    {
		// Make the key buffer twice the size of the key so it fits a Blake2S block
		// This way, we don't need a temp buffer in the Blake2S function.
		uchar input[BLAKE2S_BLOCK_SIZE] __attribute__((aligned)), key[BLAKE2S_BLOCK_SIZE] __attribute__((aligned)) = { 0 };

		// Copy input and key to their buffers
		CopyBytes(input, A + bufidx, BLAKE2S_BLOCK_SIZE);
		CopyBytes(key, B + bufidx, BLAKE2S_KEY_SIZE);

        // PRF
        //Blake2S((uint *)input, (uint *)key);
		
		uint *inkey = (uint *)key, *inout = (uint *)input;
		
        // PRF
        uint16 V;
		uint8 tmpblock;

		// Load first block (IV into V.lo) and constants (IV into V.hi)
		V.lo = V.hi = vload8(0U, BLAKE2S_IV);

		// XOR with initial constant
		V.s0 ^= 0x01012020;

		// Copy input block for later
		tmpblock = V.lo;

		// XOR length of message so far (including this block)
		// There are two uints for this field, but high uint is zero
		V.sc ^= BLAKE2S_BLOCK_SIZE;

		// Compress state, using the key as the key
		#pragma unroll
		for(int x = 0; x < 10; ++x)
		{
			BLAKE_PARALLEL_G1(x, V.s0123, V.s4567, V.s89ab, V.scdef, inkey);
			BLAKE_PARALLEL_G2(x, V.s0123, V.s5674, V.sab89, V.sfcde, inkey);
		}

		// XOR low part of state with the high part,
		// then with the original input block.
		V.lo ^= V.hi ^ tmpblock;

		// Load constants (IV into V.hi)
		V.hi = vload8(0U, BLAKE2S_IV);

		// Copy input block for later
		tmpblock = V.lo;

		// XOR length of message into block again
		V.sc ^= BLAKE2S_BLOCK_SIZE << 1;

		// Last block compression - XOR final constant into state
		V.se ^= 0xFFFFFFFFU;

		// Compress block, using the input as the key
		#pragma unroll
		for(int x = 0; x < 10; ++x)
		{	
			BLAKE_PARALLEL_G1(x, V.s0123, V.s4567, V.s89ab, V.scdef, inout);
			BLAKE_PARALLEL_G2(x, V.s0123, V.s5674, V.sab89, V.sfcde, inout);
		}

		// XOR low part of state with high part, then with input block
		V.lo ^= V.hi ^ tmpblock;

		// Store result in input/output buffer
		vstore8(V.lo, 0, inout);

		
        // Calculate the next buffer pointer
		bufidx = 0;

		for(int x = 0; x < BLAKE2S_OUT_SIZE; ++x)
			bufidx += input[x];

		// bufidx a uchar now - always mod 255
		//bufidx &= (FASTKDF_BUFFER_SIZE - 1);

        // Modify the salt buffer
		XORBytesInPlace(B + bufidx, input, BLAKE2S_OUT_SIZE);

		if(bufidx < BLAKE2S_KEY_SIZE)
		{
			// Head modified, tail updated
			// this was made off the original code... wtf
			//CopyBytes(B + FASTKDF_BUFFER_SIZE + bufidx, B + bufidx, min(BLAKE2S_OUT_SIZE, BLAKE2S_KEY_SIZE - bufidx));
			CopyBytes(B + FASTKDF_BUFFER_SIZE + bufidx, B + bufidx, BLAKE2S_KEY_SIZE - bufidx);
		}
		else if((FASTKDF_BUFFER_SIZE - bufidx) < BLAKE2S_OUT_SIZE)
		{
			// Tail modified, head updated
			CopyBytes(B, B + FASTKDF_BUFFER_SIZE, BLAKE2S_OUT_SIZE - (FASTKDF_BUFFER_SIZE - bufidx));
		}
    }

    // Modify and copy into the output buffer

    // Damned compiler crashes
    // Fuck you, AMD

	//for(uint i = 0; i < output_len; ++i, ++bufidx)
	//	output[i] = B[bufidx] ^ A[i];

    uint left = FASTKDF_BUFFER_SIZE - bufidx;
	//uint left = (~bufidx) + 1

	if(left < output_len)
	{
		XORBytes(output, B + bufidx, A, left);
		XORBytes(output + left, B, A + left, output_len - left);
	}
	else
	{
		XORBytes(output, B + bufidx, A, output_len);
	}
}

/* FastKDF, a fast buffered key derivation function:
 * FASTKDF_BUFFER_SIZE must be a power of 2;
 * password_len, salt_len and output_len should not exceed FASTKDF_BUFFER_SIZE;
 * prf_output_size must be <= prf_key_size; */
void fastkdf1(const uchar password[80], uchar output[256])
{

	/*                    WARNING!
	 * This algorithm uses byte-wise addressing for memory blocks.
	 * Or in other words, trying to copy an unaligned memory region
	 * will significantly slow down the algorithm, when copying uses
	 * words or bigger entities. It even may corrupt the data, when
	 * the device does not support it properly.
	 * Therefore use byte copying, which will not the fastest but at
	 * least get reliable results. */

	// BLOCK_SIZE            64U
	// FASTKDF_BUFFER_SIZE  256U
	// BLAKE2S_BLOCK_SIZE    64U
	// BLAKE2S_KEY_SIZE      32U
	// BLAKE2S_OUT_SIZE      32U
	uchar bufidx = 0;
	uint8 Abuffer[9], Bbuffer[9] = { (uint8)(0) };
	uchar *A = (uchar *)Abuffer, *B = (uchar *)Bbuffer;
	
	// Initialize the password buffer
	#pragma unroll 1
	for(int i = 0; i < (FASTKDF_BUFFER_SIZE >> 3); ++i) ((ulong *)B)[i] = ((ulong *)A)[i] = ((ulong *)password)[i % 10];

	((uint16 *)(B + FASTKDF_BUFFER_SIZE))[0] = ((uint16 *)(A + FASTKDF_BUFFER_SIZE))[0] = ((uint16 *)password)[0];

    // The primary iteration
    #pragma unroll 1
    for(int i = 0; i < 32; ++i)
    {
		// Make the key buffer twice the size of the key so it fits a Blake2S block
		// This way, we don't need a temp buffer in the Blake2S function.
		uchar input[BLAKE2S_BLOCK_SIZE] __attribute__((aligned)), key[BLAKE2S_BLOCK_SIZE] __attribute__((aligned)) = { 0 };
		
		// Copy input and key to their buffers
		CopyBytes(input, A + bufidx, BLAKE2S_BLOCK_SIZE);
		CopyBytes(key, B + bufidx, BLAKE2S_KEY_SIZE);
		
		uint *inkey = (uint *)key, *inout = (uint *)input;
		
		#ifndef __Hawaii__
		
        // PRF
        uint4 V[4];
		uint8 tmpblock;
		
		tmpblock = vload8(0U, BLAKE2S_IV);
		
		V[0] = V[2] = tmpblock.lo;
		V[1] = V[3] = tmpblock.hi;
		
		V[0].s0 ^= 0x01012020U;
		tmpblock.lo = V[0];
		
		V[3].s0 ^= BLAKE2S_BLOCK_SIZE;

		// Compress state, using the key as the key
		#pragma unroll
		for(int x = 0; x < 10; ++x)
		{
			BLAKE_PARALLEL_G1(x, V[0], V[1], V[2], V[3], inkey);
			BLAKE_PARALLEL_G2(x, V[0], V[1].s1230, V[2].s2301, V[3].s3012, inkey);
		}
		
		V[0] ^= V[2] ^ tmpblock.lo;
		V[1] ^= V[3] ^ tmpblock.hi;
		
		V[2] = vload4(0U, BLAKE2S_IV);
		V[3] = vload4(1U, BLAKE2S_IV);
		
		tmpblock.lo = V[0];
		tmpblock.hi = V[1];
		
		V[3].s0 ^= BLAKE2S_BLOCK_SIZE << 1;
		V[3].s2 ^= 0xFFFFFFFFU;

		// Compress block, using the input as the key
		#pragma unroll
		for(int x = 0; x < 10; ++x)
		{	
			BLAKE_PARALLEL_G1(x, V[0], V[1], V[2], V[3], inout);
			BLAKE_PARALLEL_G2(x, V[0], V[1].s1230, V[2].s2301, V[3].s3012, inout);
		}
		
		V[0] ^= V[2] ^ tmpblock.lo;
		V[1] ^= V[3] ^ tmpblock.hi;
		
		vstore4(V[0], 0, inout);
		vstore4(V[1], 1, inout);
		
		#else
		
        // PRF
        uint16 V;
		uint8 tmpblock;

		// Load first block (IV into V.lo) and constants (IV into V.hi)
		V.lo = V.hi = vload8(0U, BLAKE2S_IV);

		// XOR with initial constant
		V.s0 ^= 0x01012020;

		// Copy input block for later
		tmpblock = V.lo;

		// XOR length of message so far (including this block)
		// There are two uints for this field, but high uint is zero
		V.sc ^= BLAKE2S_BLOCK_SIZE;

		// Compress state, using the key as the key
		#pragma unroll
		for(int x = 0; x < 10; ++x)
		{
			BLAKE_PARALLEL_G1(x, V.s0123, V.s4567, V.s89ab, V.scdef, inkey);
			BLAKE_PARALLEL_G2(x, V.s0123, V.s5674, V.sab89, V.sfcde, inkey);
		}

		// XOR low part of state with the high part,
		// then with the original input block.
		V.lo ^= V.hi ^ tmpblock;

		// Load constants (IV into V.hi)
		V.hi = vload8(0U, BLAKE2S_IV);

		// Copy input block for later
		tmpblock = V.lo;

		// XOR length of message into block again
		V.sc ^= BLAKE2S_BLOCK_SIZE << 1;

		// Last block compression - XOR final constant into state
		V.se ^= 0xFFFFFFFFU;

		// Compress block, using the input as the key
		#pragma unroll
		for(int x = 0; x < 10; ++x)
		{	
			BLAKE_PARALLEL_G1(x, V.s0123, V.s4567, V.s89ab, V.scdef, inout);
			BLAKE_PARALLEL_G2(x, V.s0123, V.s5674, V.sab89, V.sfcde, inout);
		}

		// XOR low part of state with high part, then with input block
		V.lo ^= V.hi ^ tmpblock;

		// Store result in input/output buffer
		vstore8(V.lo, 0, inout);
		
		#endif
		
        // Calculate the next buffer pointer
		bufidx = 0;

		for(int x = 0; x < BLAKE2S_OUT_SIZE; ++x)
			bufidx += input[x];

		// bufidx a uchar now - always mod 255
		//bufidx &= (FASTKDF_BUFFER_SIZE - 1);

        // Modify the salt buffer
		XORBytesInPlace(B + bufidx, input, BLAKE2S_OUT_SIZE);

		if(bufidx < BLAKE2S_KEY_SIZE)
		{
			// Head modified, tail updated
			// this was made off the original code... wtf
			//CopyBytes(B + FASTKDF_BUFFER_SIZE + bufidx, B + bufidx, min(BLAKE2S_OUT_SIZE, BLAKE2S_KEY_SIZE - bufidx));
			CopyBytes(B + FASTKDF_BUFFER_SIZE + bufidx, B + bufidx, BLAKE2S_KEY_SIZE - bufidx);
		}
		else if((FASTKDF_BUFFER_SIZE - bufidx) < BLAKE2S_OUT_SIZE)
		{
			// Tail modified, head updated
			CopyBytes(B, B + FASTKDF_BUFFER_SIZE, BLAKE2S_OUT_SIZE - (FASTKDF_BUFFER_SIZE - bufidx));
		}
    }

    // Modify and copy into the output buffer

    // Damned compiler crashes
    // Fuck you, AMD

	//for(uint i = 0; i < output_len; ++i, ++bufidx)
	//	output[i] = B[bufidx] ^ A[i];

    uint left = FASTKDF_BUFFER_SIZE - bufidx;
	//uint left = (~bufidx) + 1

	if(left < 256)
	{
		XORBytes(output, B + bufidx, A, left);
		XORBytes(output + left, B, A + left, 256 - left);
	}
	else
	{
		XORBytes(output, B + bufidx, A, 256);
	}
}

/* FastKDF, a fast buffered key derivation function:
 * FASTKDF_BUFFER_SIZE must be a power of 2;
 * password_len, salt_len and output_len should not exceed FASTKDF_BUFFER_SIZE;
 * prf_output_size must be <= prf_key_size; */
void fastkdf2(const uchar password[80], const uchar salt[256],  __global uint* restrict output, const uint target)
{

	/*                    WARNING!
	 * This algorithm uses byte-wise addressing for memory blocks.
	 * Or in other words, trying to copy an unaligned memory region
	 * will significantly slow down the algorithm, when copying uses
	 * words or bigger entities. It even may corrupt the data, when
	 * the device does not support it properly.
	 * Therefore use byte copying, which will not the fastest but at
	 * least get reliable results. */

	// BLOCK_SIZE            64U
	// FASTKDF_BUFFER_SIZE  256U
	// BLAKE2S_BLOCK_SIZE    64U
	// BLAKE2S_KEY_SIZE      32U
	// BLAKE2S_OUT_SIZE      32U
	// salt_len == 256, output_len == 32
	uchar bufidx = 0;
	uint8 Abuffer[9], Bbuffer[9] = { (uint8)(0) };
	uchar *A = (uchar *)Abuffer, *B = (uchar *)Bbuffer;
	//uchar A[256], B[256];
	
	// Initialize the password buffer
	#pragma unroll 1
	for(int i = 0; i < (FASTKDF_BUFFER_SIZE >> 3); ++i) ((ulong *)A)[i] = ((ulong *)password)[i % 10];

	((uint16 *)(A + FASTKDF_BUFFER_SIZE))[0] = ((uint16 *)password)[0];

	// Initialize the salt buffer
	((ulong16 *)B)[0] = ((ulong16 *)B)[2] = ((ulong16 *)salt)[0];
	((ulong16 *)B)[1] = ((ulong16 *)B)[3] = ((ulong16 *)salt)[1];

    // The primary iteration
	#pragma unroll 1
    for(int i = 0; i < 32; ++i)
    {
		// Make the key buffer twice the size of the key so it fits a Blake2S block
		// This way, we don't need a temp buffer in the Blake2S function.
		uchar input[BLAKE2S_BLOCK_SIZE] __attribute__((aligned)), key[BLAKE2S_BLOCK_SIZE] __attribute__((aligned)) = { 0 };
		
		// Copy input and key to their buffers
		CopyBytes(input, A + bufidx, BLAKE2S_BLOCK_SIZE);
		CopyBytes(key, B + bufidx, BLAKE2S_KEY_SIZE);
		
		uint *inkey = (uint *)key, *inout = (uint *)input;
		
		#ifndef __Hawaii__
		
        // PRF
        uint4 V[4];
		uint8 tmpblock;
		
		tmpblock = vload8(0U, BLAKE2S_IV);
		
		V[0] = V[2] = tmpblock.lo;
		V[1] = V[3] = tmpblock.hi;
		
		V[0].s0 ^= 0x01012020U;
		tmpblock.lo = V[0];
		
		V[3].s0 ^= BLAKE2S_BLOCK_SIZE;

		// Compress state, using the key as the key
		#pragma unroll
		for(int x = 0; x < 10; ++x)
		{
			BLAKE_PARALLEL_G1(x, V[0], V[1], V[2], V[3], inkey);
			BLAKE_PARALLEL_G2(x, V[0], V[1].s1230, V[2].s2301, V[3].s3012, inkey);
		}
		
		V[0] ^= V[2] ^ tmpblock.lo;
		V[1] ^= V[3] ^ tmpblock.hi;
		
		V[2] = vload4(0U, BLAKE2S_IV);
		V[3] = vload4(1U, BLAKE2S_IV);
		
		tmpblock.lo = V[0];
		tmpblock.hi = V[1];
		
		V[3].s0 ^= BLAKE2S_BLOCK_SIZE << 1;
		V[3].s2 ^= 0xFFFFFFFFU;

		// Compress block, using the input as the key
		#pragma unroll
		for(int x = 0; x < 10; ++x)
		{	
			BLAKE_PARALLEL_G1(x, V[0], V[1], V[2], V[3], inout);
			BLAKE_PARALLEL_G2(x, V[0], V[1].s1230, V[2].s2301, V[3].s3012, inout);
		}
		
		V[0] ^= V[2] ^ tmpblock.lo;
		V[1] ^= V[3] ^ tmpblock.hi;
		
		vstore4(V[0], 0, inout);
		vstore4(V[1], 1, inout);
		
		#else
		
        // PRF
        uint16 V;
		uint8 tmpblock;

		// Load first block (IV into V.lo) and constants (IV into V.hi)
		V.lo = V.hi = vload8(0U, BLAKE2S_IV);

		// XOR with initial constant
		V.s0 ^= 0x01012020;

		// Copy input block for later
		tmpblock = V.lo;

		// XOR length of message so far (including this block)
		// There are two uints for this field, but high uint is zero
		V.sc ^= BLAKE2S_BLOCK_SIZE;

		// Compress state, using the key as the key
		#pragma unroll
		for(int x = 0; x < 10; ++x)
		{
			BLAKE_PARALLEL_G1(x, V.s0123, V.s4567, V.s89ab, V.scdef, inkey);
			BLAKE_PARALLEL_G2(x, V.s0123, V.s5674, V.sab89, V.sfcde, inkey);
		}

		// XOR low part of state with the high part,
		// then with the original input block.
		V.lo ^= V.hi ^ tmpblock;

		// Load constants (IV into V.hi)
		V.hi = vload8(0U, BLAKE2S_IV);

		// Copy input block for later
		tmpblock = V.lo;

		// XOR length of message into block again
		V.sc ^= BLAKE2S_BLOCK_SIZE << 1;

		// Last block compression - XOR final constant into state
		V.se ^= 0xFFFFFFFFU;

		// Compress block, using the input as the key
		#pragma unroll
		for(int x = 0; x < 10; ++x)
		{	
			BLAKE_PARALLEL_G1(x, V.s0123, V.s4567, V.s89ab, V.scdef, inout);
			BLAKE_PARALLEL_G2(x, V.s0123, V.s5674, V.sab89, V.sfcde, inout);
		}

		// XOR low part of state with high part, then with input block
		V.lo ^= V.hi ^ tmpblock;

		// Store result in input/output buffer
		vstore8(V.lo, 0, inout);
		#endif
		
        // Calculate the next buffer pointer
		bufidx = 0;

		for(int x = 0; x < BLAKE2S_OUT_SIZE; ++x)
			bufidx += input[x];

		// bufidx a uchar now - always mod 255
		//bufidx &= (FASTKDF_BUFFER_SIZE - 1);

        // Modify the salt buffer
		XORBytesInPlace(B + bufidx, input, BLAKE2S_OUT_SIZE);

		if(bufidx < BLAKE2S_KEY_SIZE)
		{
			// Head modified, tail updated
			// this was made off the original code... wtf
			//CopyBytes(B + FASTKDF_BUFFER_SIZE + bufidx, B + bufidx, min(BLAKE2S_OUT_SIZE, BLAKE2S_KEY_SIZE - bufidx));
			CopyBytes(B + FASTKDF_BUFFER_SIZE + bufidx, B + bufidx, BLAKE2S_KEY_SIZE - bufidx);
		}
		else if((FASTKDF_BUFFER_SIZE - bufidx) < BLAKE2S_OUT_SIZE)
		{
			// Tail modified, head updated
			CopyBytes(B, B + FASTKDF_BUFFER_SIZE, BLAKE2S_OUT_SIZE - (FASTKDF_BUFFER_SIZE - bufidx));
		}		
    }

    // Modify and copy into the output buffer

    // Damned compiler crashes
    // Fuck you, AMD
	
	uchar outbuf[32];
	
	for(uint i = 0; i < 32; ++i, ++bufidx)
		outbuf[i] = B[bufidx] ^ A[i];

    /*uint left = FASTKDF_BUFFER_SIZE - bufidx;
	//uint left = (~bufidx) + 1
	uchar outbuf[32];

	if(left < 32)
	{
		XORBytes(outbuf, B + bufidx, A, left);
		XORBytes(outbuf + left, B, A + left, 32 - left);
	}
	else
	{
		XORBytes(outbuf, B + bufidx, A, 32);
	}*/
	
	if(((uint *)outbuf)[7] <= target) output[atomic_add(output + 0xFF, 1)] = get_global_id(0);

}

/*
 s0 s1 s2 s3
 s4 s5 s6 s7
 s8 s9 sa sb
 sc sd se sf
shittify:
s0=s4
s1=s9
s2=se
s3=s3
s4=s8
s5=sd
s6=s2
s7=s7
s8=sc
s9=s1
sa=s6
sb=sb
sc=s0
sd=s5
se=sa
sf=sf
unshittify:
s0=sc
s1=s9
s2=s6
s3=s3
s4=s0
s5=sd
s6=sa
s7=s7
s8=s4
s9=s1
sa=se
sb=sb
sc=s8
sd=s5
se=s2
sf=sf

*/

#define SALSA_CORE(state)       do { \
	state[0] ^= rotate(state[3] + state[2], 7U); \
	state[1] ^= rotate(state[0] + state[3], 9U); \
	state[2] ^= rotate(state[1] + state[0], 13U); \
	state[3] ^= rotate(state[2] + state[1], 18U); \
	state[2] ^= rotate(state[3].wxyz + state[0].zwxy, 7U); \
	state[1] ^= rotate(state[2].wxyz + state[3].zwxy, 9U); \
	state[0] ^= rotate(state[1].wxyz + state[2].zwxy, 13U); \
	state[3] ^= rotate(state[0].wxyz + state[1].zwxy, 18U); \
} while(0)

#define SALSA_CORE_SCALAR(state)	do { \
	state.s4 ^= rotate(state.s0 + state.sc, 7U); state.s8 ^= rotate(state.s4 + state.s0, 9U); state.sc ^= rotate(state.s8 + state.s4, 13U); state.s0 ^= rotate(state.sc + state.s8, 18U); \
	state.s9 ^= rotate(state.s5 + state.s1, 7U); state.sd ^= rotate(state.s9 + state.s5, 9U); state.s1 ^= rotate(state.sd + state.s9, 13U); state.s5 ^= rotate(state.s1 + state.sd, 18U); \
	state.se ^= rotate(state.sa + state.s6, 7U); state.s2 ^= rotate(state.se + state.sa, 9U); state.s6 ^= rotate(state.s2 + state.se, 13U); state.sa ^= rotate(state.s6 + state.s2, 18U); \
	state.s3 ^= rotate(state.sf + state.sb, 7U); state.s7 ^= rotate(state.s3 + state.sf, 9U); state.sb ^= rotate(state.s7 + state.s3, 13U); state.sf ^= rotate(state.sb + state.s7, 18U); \
	state.s1 ^= rotate(state.s0 + state.s3, 7U); state.s2 ^= rotate(state.s1 + state.s0, 9U); state.s3 ^= rotate(state.s2 + state.s1, 13U); state.s0 ^= rotate(state.s3 + state.s2, 18U); \
	state.s6 ^= rotate(state.s5 + state.s4, 7U); state.s7 ^= rotate(state.s6 + state.s5, 9U); state.s4 ^= rotate(state.s7 + state.s6, 13U); state.s5 ^= rotate(state.s4 + state.s7, 18U); \
	state.sb ^= rotate(state.sa + state.s9, 7U); state.s8 ^= rotate(state.sb + state.sa, 9U); state.s9 ^= rotate(state.s8 + state.sb, 13U); state.sa ^= rotate(state.s9 + state.s8, 18U); \
	state.sc ^= rotate(state.sf + state.se, 7U); state.sd ^= rotate(state.sc + state.sf, 9U); state.se ^= rotate(state.sd + state.sc, 13U); state.sf ^= rotate(state.se + state.sd, 18U); \
} while(0)

uint16 salsa_small_parallel_rnd(uint16 X)
{
#ifndef SHITMAIN
	uint4 st[4] = {	(uint4)(X.s4, X.s9, X.se, X.s3),
				 	(uint4)(X.s8, X.sd, X.s2, X.s7),
				 	(uint4)(X.sc, X.s1, X.s6, X.sb),
					(uint4)(X.s0, X.s5, X.sa, X.sf)  };   
#else
	uint4 st[4];
	((uint16 *)st)[0] = X;
#endif
	
	#if SALSA_SMALL_UNROLL == 1

	for(int i = 0; i < 10; ++i)
	{
		SALSA_CORE(st);
	}

	#elif SALSA_SMALL_UNROLL == 2

	for(int i = 0; i < 5; ++i)
	{
		SALSA_CORE(st);
		SALSA_CORE(st);
	}

	#elif SALSA_SMALL_UNROLL == 3

	for(int i = 0; i < 4; ++i)
	{
		SALSA_CORE(st);
		if(i == 3) break;
		SALSA_CORE(st);
		SALSA_CORE(st);
	}

	#elif SALSA_SMALL_UNROLL == 4

	for(int i = 0; i < 3; ++i)
	{
		SALSA_CORE(st);
		SALSA_CORE(st);
		if(i == 2) break;
		SALSA_CORE(st);
		SALSA_CORE(st);
	}

	#elif SALSA_SMALL_UNROLL == 5

	for(int i = 0; i < 2; ++i)
	{
		SALSA_CORE(st);
		SALSA_CORE(st);
		SALSA_CORE(st);
		SALSA_CORE(st);
		SALSA_CORE(st);
	}

	#else
		SALSA_CORE(st);
		SALSA_CORE(st);
		SALSA_CORE(st);
		SALSA_CORE(st);
		SALSA_CORE(st);
		SALSA_CORE(st);
		SALSA_CORE(st);
		SALSA_CORE(st);
		SALSA_CORE(st);
		SALSA_CORE(st);

	#endif

#ifndef SHITMAIN
	return(X + (uint16)(
		st[3].x, st[2].y, st[1].z, st[0].w,
		st[0].x, st[3].y, st[2].z, st[1].w,
		st[1].x, st[0].y, st[3].z, st[2].w,
		st[2].x, st[1].y, st[0].z, st[3].w));
#else
	return(X + ((uint16 *)st)[0]);
#endif
}

uint16 salsa_small_scalar_rnd(uint16 X)
{
	uint16 st = X;
	
	#if SALSA_SMALL_UNROLL == 1
	
	for(int i = 0; i < 10; ++i)
	{
		SALSA_CORE_SCALAR(st);
	}
	
	#elif SALSA_SMALL_UNROLL == 2
	
	for(int i = 0; i < 5; ++i)
	{
		SALSA_CORE_SCALAR(st);
		SALSA_CORE_SCALAR(st);
	}
	
	#elif SALSA_SMALL_UNROLL == 3
	
	for(int i = 0; i < 4; ++i)
	{
		SALSA_CORE_SCALAR(st);
		if(i == 3) break;
		SALSA_CORE_SCALAR(st);
		SALSA_CORE_SCALAR(st);
	}
	
	#elif SALSA_SMALL_UNROLL == 4
	
	for(int i = 0; i < 3; ++i)
	{
		SALSA_CORE_SCALAR(st);
		SALSA_CORE_SCALAR(st);
		if(i == 2) break;
		SALSA_CORE_SCALAR(st);
		SALSA_CORE_SCALAR(st);
	}
	
	#else
	
	for(int i = 0; i < 2; ++i)
	{
		SALSA_CORE_SCALAR(st);
		SALSA_CORE_SCALAR(st);
		SALSA_CORE_SCALAR(st);
		SALSA_CORE_SCALAR(st);
		SALSA_CORE_SCALAR(st);
	}
	
	#endif
	
	return(X + st);
}


#define CHACHA_CORE_PARALLEL(state)	do { \
	state[0] += state[1]; state[3] = rotate(state[3] ^ state[0], 16U); \
	state[2] += state[3]; state[1] = rotate(state[1] ^ state[2], 12U); \
	state[0] += state[1]; state[3] = rotate(state[3] ^ state[0], 8U); \
	state[2] += state[3]; state[1] = rotate(state[1] ^ state[2], 7U); \
	\
	state[0] += state[1].yzwx; state[3].wxyz = rotate(state[3].wxyz ^ state[0], 16); \
	state[2].zwxy += state[3].wxyz; state[1].yzwx = rotate(state[1].yzwx ^ state[2].zwxy, 12U); \
	state[0] += state[1].yzwx; state[3].wxyz = rotate(state[3].wxyz ^ state[0], 8U); \
	state[2].zwxy += state[3].wxyz; state[1].yzwx = rotate(state[1].yzwx ^ state[2].zwxy, 7U); \
} while(0)

#define CHACHA_CORE(state)	do { \
	state.s0 += state.s4; state.sc = as_uint(as_ushort2(state.sc ^ state.s0).s10); state.s8 += state.sc; state.s4 = rotate(state.s4 ^ state.s8, 12U); state.s0 += state.s4; state.sc = rotate(state.sc ^ state.s0, 8U); state.s8 += state.sc; state.s4 = rotate(state.s4 ^ state.s8, 7U); \
	state.s1 += state.s5; state.sd = as_uint(as_ushort2(state.sd ^ state.s1).s10); state.s9 += state.sd; state.s5 = rotate(state.s5 ^ state.s9, 12U); state.s1 += state.s5; state.sd = rotate(state.sd ^ state.s1, 8U); state.s9 += state.sd; state.s5 = rotate(state.s5 ^ state.s9, 7U); \
	state.s2 += state.s6; state.se = as_uint(as_ushort2(state.se ^ state.s2).s10); state.sa += state.se; state.s6 = rotate(state.s6 ^ state.sa, 12U); state.s2 += state.s6; state.se = rotate(state.se ^ state.s2, 8U); state.sa += state.se; state.s6 = rotate(state.s6 ^ state.sa, 7U); \
	state.s3 += state.s7; state.sf = as_uint(as_ushort2(state.sf ^ state.s3).s10); state.sb += state.sf; state.s7 = rotate(state.s7 ^ state.sb, 12U); state.s3 += state.s7; state.sf = rotate(state.sf ^ state.s3, 8U); state.sb += state.sf; state.s7 = rotate(state.s7 ^ state.sb, 7U); \
	state.s0 += state.s5; state.sf = as_uint(as_ushort2(state.sf ^ state.s0).s10); state.sa += state.sf; state.s5 = rotate(state.s5 ^ state.sa, 12U); state.s0 += state.s5; state.sf = rotate(state.sf ^ state.s0, 8U); state.sa += state.sf; state.s5 = rotate(state.s5 ^ state.sa, 7U); \
	state.s1 += state.s6; state.sc = as_uint(as_ushort2(state.sc ^ state.s1).s10); state.sb += state.sc; state.s6 = rotate(state.s6 ^ state.sb, 12U); state.s1 += state.s6; state.sc = rotate(state.sc ^ state.s1, 8U); state.sb += state.sc; state.s6 = rotate(state.s6 ^ state.sb, 7U); \
	state.s2 += state.s7; state.sd = as_uint(as_ushort2(state.sd ^ state.s2).s10); state.s8 += state.sd; state.s7 = rotate(state.s7 ^ state.s8, 12U); state.s2 += state.s7; state.sd = rotate(state.sd ^ state.s2, 8U); state.s8 += state.sd; state.s7 = rotate(state.s7 ^ state.s8, 7U); \
	state.s3 += state.s4; state.se = as_uint(as_ushort2(state.se ^ state.s3).s10); state.s9 += state.se; state.s4 = rotate(state.s4 ^ state.s9, 12U); state.s3 += state.s4; state.se = rotate(state.se ^ state.s3, 8U); state.s9 += state.se; state.s4 = rotate(state.s4 ^ state.s9, 7U); \
} while(0)

uint16 chacha_small_parallel_rnd(uint16 X)
{
	uint4 st[4];

	((uint16 *)st)[0] = X;

	#if CHACHA_SMALL_UNROLL == 1

	for(int i = 0; i < 10; ++i)
	{
		CHACHA_CORE_PARALLEL(st);
	}

	#elif CHACHA_SMALL_UNROLL == 2

	for(int i = 0; i < 5; ++i)
	{
		CHACHA_CORE_PARALLEL(st);
		CHACHA_CORE_PARALLEL(st);
	}

	#elif CHACHA_SMALL_UNROLL == 3

	for(int i = 0; i < 4; ++i)
	{
		CHACHA_CORE_PARALLEL(st);
		if(i == 3) break;
		CHACHA_CORE_PARALLEL(st);
		CHACHA_CORE_PARALLEL(st);
	}

	#elif CHACHA_SMALL_UNROLL == 4

	for(int i = 0; i < 3; ++i)
	{
		CHACHA_CORE_PARALLEL(st);
		CHACHA_CORE_PARALLEL(st);
		if(i == 2) break;
		CHACHA_CORE_PARALLEL(st);
		CHACHA_CORE_PARALLEL(st);
	}

	#elif CHACHA_SMALL_UNROLL == 5

	for(int i = 0; i < 2; ++i)
	{
		CHACHA_CORE_PARALLEL(st);
		CHACHA_CORE_PARALLEL(st);
		CHACHA_CORE_PARALLEL(st);
		CHACHA_CORE_PARALLEL(st);
		CHACHA_CORE_PARALLEL(st);
	}
	#else
	
	CHACHA_CORE_PARALLEL(st);
	CHACHA_CORE_PARALLEL(st);
	CHACHA_CORE_PARALLEL(st);
	CHACHA_CORE_PARALLEL(st);
	CHACHA_CORE_PARALLEL(st);
	CHACHA_CORE_PARALLEL(st);
	CHACHA_CORE_PARALLEL(st);
	CHACHA_CORE_PARALLEL(st);
	CHACHA_CORE_PARALLEL(st);
	CHACHA_CORE_PARALLEL(st);

	#endif

	return(X + ((uint16 *)st)[0]);
}

uint16 chacha_small_scalar_rnd(uint16 X)
{   
	uint16 st = X;
	
	#if CHACHA_SMALL_UNROLL == 1
	
	for(int i = 0; i < 10; ++i)
	{
		CHACHA_CORE(st);
	}
	
	#elif CHACHA_SMALL_UNROLL == 2
	
	for(int i = 0; i < 5; ++i)
	{
		CHACHA_CORE(st);
		CHACHA_CORE(st);
	}
	
	#elif CHACHA_SMALL_UNROLL == 3
	
	for(int i = 0; i < 4; ++i)
	{
		CHACHA_CORE(st);
		if(i == 3) break;
		CHACHA_CORE(st);
		CHACHA_CORE(st);
	}
	
	#elif CHACHA_SMALL_UNROLL == 4
	
	for(int i = 0; i < 3; ++i)
	{
		CHACHA_CORE(st);
		CHACHA_CORE(st);
		if(i == 2) break;
		CHACHA_CORE(st);
		CHACHA_CORE(st);
	}
	
	#elif CHACHA_SMALL_UNROLL == 5
	
	for(int i = 0; i < 2; ++i)
	{
		CHACHA_CORE(st);
		CHACHA_CORE(st);
		CHACHA_CORE(st);
		CHACHA_CORE(st);
		CHACHA_CORE(st);
	}
	
	#else
	
	CHACHA_CORE(st);
	CHACHA_CORE(st);
	CHACHA_CORE(st);
	CHACHA_CORE(st);
	CHACHA_CORE(st);
	CHACHA_CORE(st);
	CHACHA_CORE(st);
	CHACHA_CORE(st);
	CHACHA_CORE(st);
	CHACHA_CORE(st);
	
	#endif
		
	return(X + st);
}

void neoscrypt_blkmix_salsa(uint16 XV[4])
{
    /* NeoScrypt flow:                   Scrypt flow:
         Xa ^= Xd;  M(Xa'); Ya = Xa";      Xa ^= Xb;  M(Xa'); Ya = Xa";
         Xb ^= Xa"; M(Xb'); Yb = Xb";      Xb ^= Xa"; M(Xb'); Yb = Xb";
         Xc ^= Xb"; M(Xc'); Yc = Xc";      Xa" = Ya;
         Xd ^= Xc"; M(Xd'); Yd = Xd";      Xb" = Yb;
         Xa" = Ya; Xb" = Yc;
         Xc" = Yb; Xd" = Yd; */
#if 0
	for(int i = 0; i < 4; ++i) XV[i] = (uint16)(
		XV[i].s4, XV[i].s9, XV[i].se, XV[i].s3, XV[i].s8, XV[i].sd, XV[i].s2, XV[i].s7, 
		XV[i].sc, XV[i].s1, XV[i].s6, XV[i].sb, XV[i].s0, XV[i].s5, XV[i].sa, XV[i].sf);   
#endif
	XV[0] ^= XV[3];

	XV[0] = salsa_small_parallel_rnd(XV[0]); XV[1] ^= XV[0];
	XV[1] = salsa_small_parallel_rnd(XV[1]); XV[2] ^= XV[1];
	XV[2] = salsa_small_parallel_rnd(XV[2]); XV[3] ^= XV[2];
	XV[3] = salsa_small_parallel_rnd(XV[3]);
	
	//XV[0] = salsa_small_scalar_rnd(XV[0]); XV[1] ^= XV[0];
	//XV[1] = salsa_small_scalar_rnd(XV[1]); XV[2] ^= XV[1];
	//XV[2] = salsa_small_scalar_rnd(XV[2]); XV[3] ^= XV[2];
	//XV[3] = salsa_small_scalar_rnd(XV[3]);
	
	XV[1] ^= XV[2];
	XV[2] ^= XV[1];
	XV[1] ^= XV[2];
#if 0
	XV[0] = (uint16)(XV[0].sc, XV[0].s9, XV[0].s6, XV[0].s3, XV[0].s0, XV[0].sd, XV[0].sa, XV[0].s7, XV[0].s4, XV[0].s1, XV[0].se, XV[0].sb, XV[0].s8, XV[0].s5, XV[0].s2, XV[0].sf);
	XV[1] = (uint16)(XV[1].sc, XV[1].s9, XV[1].s6, XV[1].s3, XV[1].s0, XV[1].sd, XV[1].sa, XV[1].s7, XV[1].s4, XV[1].s1, XV[1].se, XV[1].sb, XV[1].s8, XV[1].s5, XV[1].s2, XV[1].sf);
	XV[2] = (uint16)(XV[2].sc, XV[2].s9, XV[2].s6, XV[2].s3, XV[2].s0, XV[2].sd, XV[2].sa, XV[2].s7, XV[2].s4, XV[2].s1, XV[2].se, XV[2].sb, XV[2].s8, XV[2].s5, XV[2].s2, XV[2].sf);
	XV[3] = (uint16)(XV[3].sc, XV[3].s9, XV[3].s6, XV[3].s3, XV[3].s0, XV[3].sd, XV[3].sa, XV[3].s7, XV[3].s4, XV[3].s1, XV[3].se, XV[3].sb, XV[3].s8, XV[3].s5, XV[3].s2, XV[3].sf);
#endif
}

void neoscrypt_blkmix_chacha(uint16 XV[4])
{

    /* NeoScrypt flow:                   Scrypt flow:
         Xa ^= Xd;  M(Xa'); Ya = Xa";      Xa ^= Xb;  M(Xa'); Ya = Xa";
         Xb ^= Xa"; M(Xb'); Yb = Xb";      Xb ^= Xa"; M(Xb'); Yb = Xb";
         Xc ^= Xb"; M(Xc'); Yc = Xc";      Xa" = Ya;
         Xd ^= Xc"; M(Xd'); Yd = Xd";      Xb" = Yb;
         Xa" = Ya; Xb" = Yc;
         Xc" = Yb; Xd" = Yd; */

	XV[0] ^= XV[3];
	
	#if 1
	
	XV[0] = chacha_small_parallel_rnd(XV[0]); XV[1] ^= XV[0];
	XV[1] = chacha_small_parallel_rnd(XV[1]); XV[2] ^= XV[1];
	XV[2] = chacha_small_parallel_rnd(XV[2]); XV[3] ^= XV[2];
	XV[3] = chacha_small_parallel_rnd(XV[3]);
	
	#else
	
	XV[0] = chacha_small_scalar_rnd(XV[0]); XV[1] ^= XV[0];
	XV[1] = chacha_small_scalar_rnd(XV[1]); XV[2] ^= XV[1];
	XV[2] = chacha_small_scalar_rnd(XV[2]); XV[3] ^= XV[2];
	XV[3] = chacha_small_scalar_rnd(XV[3]);
	
	#endif
	
	XV[1] ^= XV[2];
	XV[2] ^= XV[1];
	XV[1] ^= XV[2];
}

#ifdef WIDE_STRIPE

void ScratchpadStore(__global void *V, void *X, uchar idx)
{
	((__global ulong16 *)V)[mul24(idx << 1, (int)get_global_size(0))] = ((ulong16 *)X)[0];
	((__global ulong16 *)V)[mul24((idx << 1), (int)get_global_size(0)) + 1] = ((ulong16 *)X)[1];
	//const uint idx2 = mul24(idx << 2, (int)get_global_size(0));
	//#pragma unroll
	//for(int i = 0; i < 4; ++i) ((__global uint16 *)V)[idx2 + i] = ((uint16 *)X)[i];
}

void ScratchpadMix(void *X, const __global void *V, uchar idx)
{
	((ulong16 *)X)[0] ^= ((__global ulong16 *)V)[mul24(idx << 1, (int)get_global_size(0))];
	((ulong16 *)X)[1] ^= ((__global ulong16 *)V)[mul24((idx << 1), (int)get_global_size(0)) + 1];
}

#else

void ScratchpadStore(__global void *V, void *X, uchar idx)
{
	((__global ulong16 *)V)[mul24(idx << 1, (int)get_global_size(0))] = ((ulong16 *)X)[0];
	((__global ulong16 *)V)[mul24((idx << 1) + 1, (int)get_global_size(0))] = ((ulong16 *)X)[1];
}

void ScratchpadMix(void *X, const __global void *V, uchar idx)
{
	((ulong16 *)X)[0] ^= ((__global ulong16 *)V)[mul24(idx << 1, (int)get_global_size(0))];
	((ulong16 *)X)[1] ^= ((__global ulong16 *)V)[mul24((idx << 1) + 1, (int)get_global_size(0))];
}

#endif



#define SALSA_PERM		(uint16)(4, 9, 14, 3, 8, 13, 2, 7, 12, 1, 6, 11, 0, 5, 10, 15)
#define SALSA_INV_PERM	(uint16)(12, 9, 6, 3, 0, 13, 10, 7, 4, 1, 14, 11, 8, 5, 2, 15)

void SMix_Salsa(uint16 X[4], __global uint16 *V)
{
	#pragma unroll 1
	for(int i = 0; i < 128; ++i)
	{
		ScratchpadStore(V, X, i);
		neoscrypt_blkmix_salsa(X);
	}

	#pragma unroll 1
	for(int i = 0; i < 128; ++i)
	{
		#ifdef SHITMAIN
		const uint idx = convert_uchar(((uint *)X)[60] & 0x7F);
		#else
		const uint idx = convert_uchar(((uint *)X)[48] & 0x7F);
		#endif
		ScratchpadMix(X, V, idx);
		neoscrypt_blkmix_salsa(X);
	}
}

void SMix_Chacha(uint16 X[4], __global uint16 *V)
{
	#pragma unroll 1
	for(int i = 0; i < 128; ++i)
	{
		ScratchpadStore(V, X, i);
		neoscrypt_blkmix_chacha(X);
	}

	#pragma unroll 1
	for(int i = 0; i < 128; ++i)
	{
		const uint idx = convert_uchar(((uint *)X)[48] & 0x7F);
		ScratchpadMix(X, V, idx);
		neoscrypt_blkmix_chacha(X);
	}
}

#define SALSA_PERM		(uint16)(4, 9, 14, 3, 8, 13, 2, 7, 12, 1, 6, 11, 0, 5, 10, 15)
#define SALSA_INV_PERM	(uint16)(12, 9, 6, 3, 0, 13, 10, 7, 4, 1, 14, 11, 8, 5, 2, 15)

__attribute__((reqd_work_group_size(WORKSIZE, 1, 1)))
__kernel void search(__global const uchar* restrict input, __global uint* restrict output, __global uchar *padcache, const uint target)
{
#define CONSTANT_N 128
#define CONSTANT_r 2
	// X = CONSTANT_r * 2 * BLOCK_SIZE(64); Z is a copy of X for ChaCha
	uint16 X[4], Z[4];
	#ifdef WIDE_STRIPE
	__global ulong16 *V = ((__global ulong16 *)padcache) + ((get_global_id(0) % get_global_size(0)) << 1);
	#else
	__global ulong16 *V = ((__global ulong16 *)(padcache) + (get_global_id(0) % get_global_size(0)));
	#endif
	//uchar outbuf[32];
	uchar data[PASSWORD_LEN];

	((ulong8 *)data)[0] = ((__global const ulong8 *)input)[0];
	((ulong *)data)[8] = ((__global const ulong *)input)[8];
	((uint *)data)[18] = ((__global const uint *)input)[18];
	((uint *)data)[19] = get_global_id(0);

    // X = KDF(password, salt)
	//fastkdf(data, data, PASSWORD_LEN, (uchar *)X, 256);
	fastkdf1(data, (uchar *)X);
	
	#ifndef SHITMAIN
    // Process ChaCha 1st, Salsa 2nd and XOR them - run that through PBKDF2
    CopyBytes128(Z, X, 2);
	#else
	
	#pragma unroll
    for(int i = 0; i < 4; ++i) ((uint16 *)Z)[i] = shuffle(((uint16 *)X)[i], SALSA_PERM);
    
    #endif
	
    // X = SMix(X); X & Z are swapped, repeat.
    for(int i = 0;; ++i)
    {
		#ifdef SWAP
		if (i) SMix_Salsa(X,V); else SMix_Chacha(X,V);
		if(i) break;
		SwapBytes128(X, Z, 256);
		#else
		if (i) SMix_Chacha(X,V); else SMix_Salsa(Z,V);
		if(i) break;
		#endif
	}
	
	#if defined(SWAP) && defined(SHITMAIN)
	#pragma unroll
    for(int i = 0; i < 4; ++i) ((uint16 *)Z)[i] ^= shuffle(((uint16 *)X)[i], SALSA_INV_PERM);
	fastkdf2(data, (uchar *)Z, output, target);
	#elif defined(SHITMAIN)
	#pragma unroll
    for(int i = 0; i < 4; ++i) ((uint16 *)X)[i] ^= shuffle(((uint16 *)Z)[i], SALSA_INV_PERM);
	fastkdf2(data, (uchar *)X, output, target);
	#else
	// blkxor(X, Z)
	((ulong16 *)X)[0] ^= ((ulong16 *)Z)[0];
	((ulong16 *)X)[1] ^= ((ulong16 *)Z)[1];

	// output = KDF(password, X)
	//fastkdf(data, (uchar *)X, FASTKDF_BUFFER_SIZE, outbuf, 32);
	fastkdf2(data, (uchar *)X, output, target);
	#endif
}


/*
__attribute__((reqd_work_group_size(WORKSIZE, 1, 1)))
__kernel void search(__global const uchar* restrict input, __global uint16 *XZOutput)
{
#define CONSTANT_N 128
#define CONSTANT_r 2
	// X = CONSTANT_r * 2 * BLOCK_SIZE(64); Z is a copy of X for ChaCha
	uint16 X[4];
	XZOutput += (4 * 2 * get_global_id(0));
	
	//uchar outbuf[32];
	uchar data[PASSWORD_LEN];

	((ulong8 *)data)[0] = ((__global const ulong8 *)input)[0];
	((ulong *)data)[8] = ((__global const ulong *)input)[8];
	((uint *)data)[18] = ((__global const uint *)input)[18];
	((uint *)data)[19] = get_global_id(0);

    // X = KDF(password, salt)
	//fastkdf(data, data, PASSWORD_LEN, (uchar *)X, 256);
	fastkdf1(data, (uchar *)X);
	
	for(int i = 0; i < 4; ++i) XZOutput[i] = X[i];
	for(int i = 0; i < 4; ++i) XZOutput[i + 4] = X[i];
	mem_fence(CLK_GLOBAL_MEM_FENCE);
}

__attribute__((reqd_work_group_size(WORKSIZE, 1, 1)))
__kernel void search1(__global uint16 *XZOutput, __global uchar *padcache)
{
#define CONSTANT_N 128
#define CONSTANT_r 2
	// X = CONSTANT_r * 2 * BLOCK_SIZE(64); Z is a copy of X for ChaCha
	uint16 X[4], Z[4];
	#ifdef WIDE_STRIPE
	__global ulong16 *V = ((__global ulong16 *)padcache) + ((get_global_id(0) % get_global_size(0)) << 1);
	#else
	__global ulong16 *V = ((__global ulong16 *)(padcache) + (get_global_id(0) % get_global_size(0)));
	#endif
	//uchar outbuf[32];
	
	XZOutput += (4 * 2 * get_global_id(0));
	
	for(int i = 0; i < 4; ++i) X[i] = XZOutput[i];
	
	SMix_Salsa(X,V);
	
	for(int i = 0; i < 4; ++i) XZOutput[i] = X[i];
	mem_fence(CLK_GLOBAL_MEM_FENCE);
}

__attribute__((reqd_work_group_size(WORKSIZE, 1, 1)))
__kernel void search2(__global uint16 *XZOutput, __global uchar *padcache)
{
#define CONSTANT_N 128
#define CONSTANT_r 2
	// X = CONSTANT_r * 2 * BLOCK_SIZE(64); Z is a copy of X for ChaCha
	uint16 X[4], Z[4];
	#ifdef WIDE_STRIPE
	__global ulong16 *V = ((__global ulong16 *)padcache) + ((get_global_id(0) % get_global_size(0)) << 1);
	#else
	__global ulong16 *V = ((__global ulong16 *)(padcache) + (get_global_id(0) % get_global_size(0)));
	#endif
	//uchar outbuf[32];
	
	XZOutput += (4 * 2 * get_global_id(0));
	
	for(int i = 0; i < 4; ++i) X[i] = XZOutput[i + 4];
	
	SMix_Chacha(X,V);
	
	for(int i = 0; i < 4; ++i) XZOutput[i + 4] = X[i];
	mem_fence(CLK_GLOBAL_MEM_FENCE);
}

__attribute__((reqd_work_group_size(WORKSIZE, 1, 1)))
__kernel void search3(__global const uchar* restrict input, __global uint16 *XZOutput, __global uint* restrict output, const uint target)
{
	uint16 X[4], Z[4];
	uchar data[PASSWORD_LEN];

	((ulong8 *)data)[0] = ((__global const ulong8 *)input)[0];
	((ulong *)data)[8] = ((__global const ulong *)input)[8];
	((uint *)data)[18] = ((__global const uint *)input)[18];
	((uint *)data)[19] = get_global_id(0);
	
	XZOutput += (4 * 2 * get_global_id(0));
	
	for(int i = 0; i < 4; ++i) X[i] = XZOutput[i];
	for(int i = 0; i < 4; ++i) Z[i] = XZOutput[i + 4];
	
	// blkxor(X, Z)
	((ulong16 *)X)[0] ^= ((ulong16 *)Z)[0];
	((ulong16 *)X)[1] ^= ((ulong16 *)Z)[1];

	// output = KDF(password, X)
	//fastkdf(data, (uchar *)X, FASTKDF_BUFFER_SIZE, outbuf, 32);
	fastkdf2(data, (uchar *)X, output, target);
}
*/