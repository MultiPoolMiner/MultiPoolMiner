/*
 * Lyra2RE kernel implementation.
 *
 * ==========================(LICENSE BEGIN)============================
 * Copyright (c) 2014 djm34
 * Copyright (c) 2014 James Lovejoy
 * 
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 * ===========================(LICENSE END)=============================
 *
 * @author   djm34
 */
// typedef unsigned int uint;
#pragma OPENCL EXTENSION cl_amd_printf : enable

#ifndef LYRA2REV2_CL
#define LYRA2REV2_CL

#if __ENDIAN_LITTLE__
#define SPH_LITTLE_ENDIAN 1
#else
#define SPH_BIG_ENDIAN 1
#endif

#define SPH_UPTR sph_u64

typedef unsigned int sph_u32;
typedef int sph_s32;
#ifndef __OPENCL_VERSION__
typedef unsigned long sph_u64;
typedef long  sph_s64;
#else
typedef unsigned long sph_u64;
typedef long sph_s64;
#endif


#define SPH_64 1
#define SPH_64_TRUE 1

#define SPH_C32(x)    ((sph_u32)(x ## U))
#define SPH_T32(x)    ((x) & SPH_C32(0xFFFFFFFF))

#define SPH_C64(x)    ((sph_u64)(x ## UL))
#define SPH_T64(x)    ((x) & SPH_C64(0xFFFFFFFFFFFFFFFF))

//#define SPH_ROTL32(x, n)   (((x) << (n)) | ((x) >> (32 - (n))))
//#define SPH_ROTR32(x, n)   (((x) >> (n)) | ((x) << (32 - (n))))
//#define SPH_ROTL64(x, n)   (((x) << (n)) | ((x) >> (64 - (n))))
//#define SPH_ROTR64(x, n)   (((x) >> (n)) | ((x) << (64 - (n))))

#define SPH_ROTL32(x,n) rotate(x,(uint)n)     //faster with driver 14.6
#define SPH_ROTR32(x,n) rotate(x,(uint)(32-n))
#define SPH_ROTL64(x,n) rotate(x,(ulong)n)
#define SPH_ROTR64(x,n) rotate(x,(ulong)(64-n))
static inline sph_u64 ror64(sph_u64 vw, unsigned a) {
	uint2 result;
	uint2 v = as_uint2(vw);
	unsigned n = (unsigned)(64 - a);
	if (n == 32) { return as_ulong((uint2)(v.y, v.x)); }
	if (n < 32) {
		result.y = ((v.y << (n)) | (v.x >> (32 - n)));
		result.x = ((v.x << (n)) | (v.y >> (32 - n)));
	}
	else {
		result.y = ((v.x << (n - 32)) | (v.y >> (64 - n)));
		result.x = ((v.y << (n - 32)) | (v.x >> (64 - n)));
	}
	return as_ulong(result);
}

//#define SPH_ROTR64(l,n) ror64(l,n)
#define memshift 3
#include "blake256.cl"
#include "lyra2v2.cl"
#include "keccak1600.cl"
#include "skein256.cl"
#include "cubehash.cl"
#include "bmw256.cl"

#define SWAP4(x) as_uint(as_uchar4(x).wzyx)
#define SWAP8(x) as_ulong(as_uchar8(x).s76543210)
//#define SWAP8(x) as_ulong(as_uchar8(x).s32107654)
#if SPH_BIG_ENDIAN
  #define DEC64E(x) (x)
  #define DEC64BE(x) (*(const __global sph_u64 *) (x));
  #define DEC64LE(x) SWAP8(*(const __global sph_u64 *) (x));
  #define DEC32LE(x) (*(const __global sph_u32 *) (x));
#else
  #define DEC64E(x) SWAP8(x)
  #define DEC64BE(x) SWAP8(*(const __global sph_u64 *) (x));
  #define DEC64LE(x) (*(const __global sph_u64 *) (x));
#define DEC32LE(x) SWAP4(*(const __global sph_u32 *) (x));
#endif

typedef union {
  unsigned char h1[32];
  uint h4[8];
  ulong h8[4];
} hash_t;

__attribute__((reqd_work_group_size(WORKSIZE, 1, 1)))
__kernel void search(
	 __global uchar* hashes,
	// precalc hash from fisrt part of message
	const uint h0,
	const uint h1,
	const uint h2,
	const uint h3,
	const uint h4,
	const uint h5,
	const uint h6,
	const uint h7,
	// last 12 bytes of original message
	const uint in16,
	const uint in17,
	const uint in18
)
{
 uint gid = get_global_id(0);
 __global hash_t *hash = (__global hash_t *)(hashes + (4 * sizeof(ulong)* (get_global_id(0) % MAX_GLOBAL_THREADS)));


//  __global hash_t *hash = &(hashes[gid-get_global_offset(0)]);

    unsigned int h[8];
	unsigned int m[16];
	unsigned int v[16];


h[0]=h0;
h[1]=h1;
h[2]=h2;
h[3]=h3;
h[4]=h4;
h[5]=h5;
h[6]=h6;
h[7]=h7;
// compress 2nd round
 m[0] = in16;
 m[1] = in17;
 m[2] = in18;
 m[3] = SWAP4(gid);

	for (int i = 4; i < 16; i++) {m[i] = c_Padding[i];}

	for (int i = 0; i < 8; i++) {v[i] = h[i];}

	v[8] =  c_u256[0];
	v[9] =  c_u256[1];
	v[10] = c_u256[2];
	v[11] = c_u256[3];
	v[12] = c_u256[4] ^ 640;
	v[13] = c_u256[5] ^ 640;
	v[14] = c_u256[6];
	v[15] = c_u256[7];

	for (int r = 0; r < 14; r++) {	
		GS(0, 4, 0x8, 0xC, 0x0);
		GS(1, 5, 0x9, 0xD, 0x2);
		GS(2, 6, 0xA, 0xE, 0x4);
		GS(3, 7, 0xB, 0xF, 0x6);
		GS(0, 5, 0xA, 0xF, 0x8);
		GS(1, 6, 0xB, 0xC, 0xA);
		GS(2, 7, 0x8, 0xD, 0xC);
		GS(3, 4, 0x9, 0xE, 0xE);
	}

	for (int i = 0; i < 16; i++) {
		 int j = i & 7;
		h[j] ^= v[i];}

for (int i=0;i<8;i++) {hash->h4[i]=SWAP4(h[i]);}

barrier(CLK_LOCAL_MEM_FENCE);

}

// keccak256


__attribute__((reqd_work_group_size(WORKSIZE, 1, 1)))
__kernel void search1(__global uchar* hashes)
{
  uint gid = get_global_id(0);
 // __global hash_t *hash = &(hashes[gid-get_global_offset(0)]);

  __global hash_t *hash = (__global hash_t *)(hashes + (4 * sizeof(ulong)* (get_global_id(0) % MAX_GLOBAL_THREADS)));

 		sph_u64 keccak_gpu_state[25];

		for (int i = 0; i<25; i++) {
			if (i<4) { keccak_gpu_state[i] = hash->h8[i]; }
			else    { keccak_gpu_state[i] = 0; }
		}
		keccak_gpu_state[4] = 0x0000000000000001;
		keccak_gpu_state[16] = 0x8000000000000000;

		keccak_block(keccak_gpu_state);
		for (int i = 0; i<4; i++) { hash->h8[i] = keccak_gpu_state[i]; }
barrier(CLK_LOCAL_MEM_FENCE);



}

// cubehash256

__attribute__((reqd_work_group_size(WORKSIZE, 1, 1)))
__kernel void search2(__global uchar* hashes)
{
	uint gid = get_global_id(0);
	__global hash_t *hash = (__global hash_t *)(hashes + (4 * sizeof(ulong)* (get_global_id(0) % MAX_GLOBAL_THREADS)));


	sph_u32 x0 = 0xEA2BD4B4; sph_u32 x1 = 0xCCD6F29F; sph_u32 x2 = 0x63117E71;
	sph_u32 x3 = 0x35481EAE; sph_u32 x4 = 0x22512D5B; sph_u32 x5 = 0xE5D94E63;
	sph_u32 x6 = 0x7E624131; sph_u32 x7 = 0xF4CC12BE; sph_u32 x8 = 0xC2D0B696;
	sph_u32 x9 = 0x42AF2070; sph_u32 xa = 0xD0720C35; sph_u32 xb = 0x3361DA8C;
	sph_u32 xc = 0x28CCECA4; sph_u32 xd = 0x8EF8AD83; sph_u32 xe = 0x4680AC00;
	sph_u32 xf = 0x40E5FBAB;

	sph_u32 xg = 0xD89041C3; sph_u32 xh = 0x6107FBD5;
	sph_u32 xi = 0x6C859D41; sph_u32 xj = 0xF0B26679; sph_u32 xk = 0x09392549;
	sph_u32 xl = 0x5FA25603; sph_u32 xm = 0x65C892FD; sph_u32 xn = 0x93CB6285;
	sph_u32 xo = 0x2AF2B5AE; sph_u32 xp = 0x9E4B4E60; sph_u32 xq = 0x774ABFDD;
	sph_u32 xr = 0x85254725; sph_u32 xs = 0x15815AEB; sph_u32 xt = 0x4AB6AAD6;
	sph_u32 xu = 0x9CDAF8AF; sph_u32 xv = 0xD6032C0A;

	x0 ^= (hash->h4[0]);
	x1 ^= (hash->h4[1]);
	x2 ^= (hash->h4[2]);
	x3 ^= (hash->h4[3]);
	x4 ^= (hash->h4[4]);
	x5 ^= (hash->h4[5]);
	x6 ^= (hash->h4[6]);
	x7 ^= (hash->h4[7]);


	SIXTEEN_ROUNDS;
	x0 ^= 0x80;
	SIXTEEN_ROUNDS;
	xv ^= 0x01;
	for (int i = 0; i < 10; ++i) SIXTEEN_ROUNDS;

	hash->h4[0] = x0;
	hash->h4[1] = x1;
	hash->h4[2] = x2;
	hash->h4[3] = x3;
	hash->h4[4] = x4;
	hash->h4[5] = x5;
	hash->h4[6] = x6;
	hash->h4[7] = x7;


	barrier(CLK_GLOBAL_MEM_FENCE);

}


/// lyra2 algo 


__attribute__((reqd_work_group_size(WORKSIZE, 1, 1)))
__kernel void search3(__global uchar* hashes,__global uchar* matrix )
{
 uint gid = get_global_id(0);
 // __global hash_t *hash = &(hashes[gid-get_global_offset(0)]);
  __global hash_t *hash = (__global hash_t *)(hashes + (4 * sizeof(ulong)* (get_global_id(0) % MAX_GLOBAL_THREADS)));
  __global ulong4 *DMatrix = (__global ulong4 *)(matrix + (4 * memshift * 4 * 4 * 8 * (get_global_id(0) % MAX_GLOBAL_THREADS)));

//  uint offset = (4 * memshift * 4 * 4 * sizeof(ulong)* (get_global_id(0) % MAX_GLOBAL_THREADS))/32;
  ulong4 state[4];
  
  state[0].x = hash->h8[0]; //password
  state[0].y = hash->h8[1]; //password
  state[0].z = hash->h8[2]; //password
  state[0].w = hash->h8[3]; //password
  state[1] = state[0];
  state[2] = (ulong4)(0x6a09e667f3bcc908UL, 0xbb67ae8584caa73bUL, 0x3c6ef372fe94f82bUL, 0xa54ff53a5f1d36f1UL);
  state[3] = (ulong4)(0x510e527fade682d1UL, 0x9b05688c2b3e6c1fUL, 0x1f83d9abfb41bd6bUL, 0x5be0cd19137e2179UL);
  for (int i = 0; i<12; i++) { round_lyra(state); } 

  state[0] ^= (ulong4)(0x20,0x20,0x20,0x01);
  state[1] ^= (ulong4)(0x04,0x04,0x80,0x0100000000000000);

  for (int i = 0; i<12; i++) { round_lyra(state); } 


  uint ps1 = (memshift * 3);
//#pragma unroll 4
  for (int i = 0; i < 4; i++)
  {
	  uint s1 = ps1 - memshift * i;
	  for (int j = 0; j < 3; j++)
		  (DMatrix)[j+s1] = state[j];

	  round_lyra(state);
  }
 
  reduceDuplexf(state,DMatrix);
 
  reduceDuplexRowSetupf(1, 0, 2,state, DMatrix);
  reduceDuplexRowSetupf(2, 1, 3, state,DMatrix);


  uint rowa;
  uint prev = 3;
  for (uint i = 0; i<4; i++) {
	  rowa = state[0].x & 3;
	  reduceDuplexRowf(prev, rowa, i, state, DMatrix);
	  prev = i;
  }



  uint shift = (memshift * 4 * rowa);

  for (int j = 0; j < 3; j++)
	  state[j] ^= (DMatrix)[j+shift];

  for (int i = 0; i < 12; i++)
	  round_lyra(state);
//////////////////////////////////////


  for (int i = 0; i<4; i++) {hash->h8[i] = ((ulong*)state)[i];} 
barrier(CLK_LOCAL_MEM_FENCE);

 

}

//skein256

__attribute__((reqd_work_group_size(WORKSIZE, 1, 1)))
__kernel void search4(__global uchar* hashes)
{
 uint gid = get_global_id(0);
 // __global hash_t *hash = &(hashes[gid-get_global_offset(0)]);
  __global hash_t *hash = (__global hash_t *)(hashes + (4 * sizeof(ulong)* (get_global_id(0) % MAX_GLOBAL_THREADS)));


		sph_u64 h[9];
		sph_u64 t[3];
        sph_u64 dt0,dt1,dt2,dt3;
		sph_u64 p0, p1, p2, p3, p4, p5, p6, p7;
        h[8] = skein_ks_parity;

		for (int i = 0; i<8; i++) {
			h[i] = SKEIN_IV512_256[i];
			h[8] ^= h[i];}
		    
			t[0]=t12[0];
			t[1]=t12[1];
			t[2]=t12[2];

        dt0=hash->h8[0];
        dt1=hash->h8[1];
        dt2=hash->h8[2];
        dt3=hash->h8[3];

		p0 = h[0] + dt0;
		p1 = h[1] + dt1;
		p2 = h[2] + dt2;
		p3 = h[3] + dt3;
		p4 = h[4];
		p5 = h[5] + t[0];
		p6 = h[6] + t[1];
		p7 = h[7];

        #pragma unroll 
		for (int i = 1; i<19; i+=2) {Round_8_512(p0,p1,p2,p3,p4,p5,p6,p7,i);}
        p0 ^= dt0;
        p1 ^= dt1;
        p2 ^= dt2;
        p3 ^= dt3;

		h[0] = p0;
		h[1] = p1;
		h[2] = p2;
		h[3] = p3;
		h[4] = p4;
		h[5] = p5;
		h[6] = p6;
		h[7] = p7;
		h[8] = skein_ks_parity;
        
		for (int i = 0; i<8; i++) { h[8] ^= h[i]; }
		
		t[0] = t12[3];
		t[1] = t12[4];
		t[2] = t12[5];
		p5 += t[0];  //p5 already equal h[5] 
		p6 += t[1];
       
        #pragma unroll
		for (int i = 1; i<19; i+=2) { Round_8_512(p0, p1, p2, p3, p4, p5, p6, p7, i); }

		hash->h8[0]      = p0;
		hash->h8[1]      = p1;
		hash->h8[2]      = p2;
		hash->h8[3]      = p3;
	barrier(CLK_LOCAL_MEM_FENCE);

}

//cubehash

__attribute__((reqd_work_group_size(WORKSIZE, 1, 1)))
__kernel void search5(__global uchar* hashes)
{
	uint gid = get_global_id(0);
	__global hash_t *hash = (__global hash_t *)(hashes + (4 * sizeof(ulong)* (get_global_id(0) % MAX_GLOBAL_THREADS)));

	    sph_u32 x0 = 0xEA2BD4B4; sph_u32 x1 = 0xCCD6F29F; sph_u32 x2 = 0x63117E71;
	    sph_u32 x3 = 0x35481EAE; sph_u32 x4 = 0x22512D5B; sph_u32 x5 = 0xE5D94E63;
		sph_u32 x6 = 0x7E624131; sph_u32 x7 = 0xF4CC12BE; sph_u32 x8 = 0xC2D0B696;
		sph_u32 x9 = 0x42AF2070; sph_u32 xa = 0xD0720C35; sph_u32 xb = 0x3361DA8C;
		sph_u32 xc = 0x28CCECA4; sph_u32 xd = 0x8EF8AD83; sph_u32 xe = 0x4680AC00;
		sph_u32 xf = 0x40E5FBAB;

		sph_u32 xg = 0xD89041C3; sph_u32 xh = 0x6107FBD5;
		sph_u32 xi = 0x6C859D41; sph_u32 xj = 0xF0B26679; sph_u32 xk = 0x09392549;
		sph_u32 xl = 0x5FA25603; sph_u32 xm = 0x65C892FD; sph_u32 xn = 0x93CB6285;
		sph_u32 xo = 0x2AF2B5AE; sph_u32 xp = 0x9E4B4E60; sph_u32 xq = 0x774ABFDD;
		sph_u32 xr = 0x85254725; sph_u32 xs = 0x15815AEB; sph_u32 xt = 0x4AB6AAD6;
		sph_u32 xu = 0x9CDAF8AF; sph_u32 xv = 0xD6032C0A;
		
	x0 ^= (hash->h4[0]);
	x1 ^= (hash->h4[1]);
	x2 ^= (hash->h4[2]);
	x3 ^= (hash->h4[3]);
	x4 ^= (hash->h4[4]);
	x5 ^= (hash->h4[5]);
	x6 ^= (hash->h4[6]);
	x7 ^= (hash->h4[7]);


		SIXTEEN_ROUNDS;
			x0 ^= 0x80;
		SIXTEEN_ROUNDS;
			xv ^= 0x01;
			for (int i = 0; i < 10; ++i) SIXTEEN_ROUNDS;

	hash->h4[0] = x0;
	hash->h4[1] = x1;
	hash->h4[2] = x2;
	hash->h4[3] = x3;
	hash->h4[4] = x4;
	hash->h4[5] = x5;
	hash->h4[6] = x6;
	hash->h4[7] = x7;


	barrier(CLK_GLOBAL_MEM_FENCE);

}



__attribute__((reqd_work_group_size(WORKSIZE, 1, 1)))
__kernel void search6(__global uchar* hashes, __global uint* output, const ulong target)
{
	uint gid = get_global_id(0);
	__global hash_t *hash = (__global hash_t *)(hashes + (4 * sizeof(ulong)* (get_global_id(0) % MAX_GLOBAL_THREADS)));

	uint dh[16] = {
		0x40414243, 0x44454647,
		0x48494A4B, 0x4C4D4E4F,
		0x50515253, 0x54555657,
		0x58595A5B, 0x5C5D5E5F,
		0x60616263, 0x64656667,
		0x68696A6B, 0x6C6D6E6F,
		0x70717273, 0x74757677,
		0x78797A7B, 0x7C7D7E7F
	};
	uint final_s[16] = {
		0xaaaaaaa0, 0xaaaaaaa1, 0xaaaaaaa2,
		0xaaaaaaa3, 0xaaaaaaa4, 0xaaaaaaa5,
		0xaaaaaaa6, 0xaaaaaaa7, 0xaaaaaaa8,
		0xaaaaaaa9, 0xaaaaaaaa, 0xaaaaaaab,
		0xaaaaaaac, 0xaaaaaaad, 0xaaaaaaae,
		0xaaaaaaaf
	};

	uint message[16];
	for (int i = 0; i<8; i++) message[i] = hash->h4[i];
	for (int i = 9; i<14; i++) message[i] = 0;
	message[8]= 0x80;
	message[14]=0x100;
	message[15]=0;

	Compression256(message, dh);
	Compression256(dh, final_s);
	barrier(CLK_LOCAL_MEM_FENCE);


	bool result = ( ((ulong*)final_s)[7] <= target);
	if (result) {
		output[atomic_inc(output + 0xFF)] = SWAP4(gid);
	}

}


#endif // LYRA2REV2_CL