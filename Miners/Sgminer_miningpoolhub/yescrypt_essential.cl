/*
* "yescrypt" kernel implementation.
*
* ==========================(LICENSE BEGIN)============================
*
* Copyright (c) 2015  djm34
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

#define ROL32(x, n)  rotate(x, (uint) n)
#define SWAP32(a)    (as_uint(as_uchar4(a).wzyx))
//#define ROL32(x, n)   (((x) << (n)) | ((x) >> (32 - (n))))
#define HASH_MEMORY 4096


#define SALSA(a,b,c,d) do { \
    t =a+d; b^=ROL32(t,  7U);    \
    t =b+a; c^=ROL32(t,  9U);    \
    t =c+b; d^=ROL32(t, 13U);    \
    t =d+c; a^=ROL32(t, 18U);     \
} while(0)


#define SALSA_CORE(state) do { \
\
SALSA(state.s0,state.s4,state.s8,state.sc); \
SALSA(state.s5,state.s9,state.sd,state.s1); \
SALSA(state.sa,state.se,state.s2,state.s6); \
SALSA(state.sf,state.s3,state.s7,state.sb); \
SALSA(state.s0,state.s1,state.s2,state.s3); \
SALSA(state.s5,state.s6,state.s7,state.s4); \
SALSA(state.sa,state.sb,state.s8,state.s9); \
SALSA(state.sf,state.sc,state.sd,state.se); \
	} while(0)

#define uSALSA_CORE(state) do { \
\
SALSA(state.s0,state.s4,state.s8,state.sc); \
SALSA(state.s1,state.s5,state.s9,state.sd); \
SALSA(state.s2,state.s6,state.sa,state.se); \
SALSA(state.s3,state.s7,state.sb,state.sf); \
SALSA(state.s0,state.sd,state.sa,state.s7); \
SALSA(state.s1,state.se,state.sb,state.s4); \
SALSA(state.s2,state.sf,state.s8,state.s5); \
SALSA(state.s3,state.sc,state.s9,state.s6); \
} while(0)


#define unshuffle(state) (as_uint16(state).s0da741eb852fc963)

#define   shuffle(state) (as_uint16(state).s05af49e38d27c16b)

static __constant uint16 pad1 = 
{
	0x36363636, 0x36363636, 0x36363636, 0x36363636,
	0x36363636, 0x36363636, 0x36363636, 0x36363636,
	0x36363636, 0x36363636, 0x36363636, 0x36363636,
	0x36363636, 0x36363636, 0x36363636, 0x36363636
};

static __constant uint16 pad2 = 
{
	0x5c5c5c5c, 0x5c5c5c5c, 0x5c5c5c5c, 0x5c5c5c5c,
	0x5c5c5c5c, 0x5c5c5c5c, 0x5c5c5c5c, 0x5c5c5c5c,
	0x5c5c5c5c, 0x5c5c5c5c, 0x5c5c5c5c, 0x5c5c5c5c,
	0x5c5c5c5c, 0x5c5c5c5c, 0x5c5c5c5c, 0x5c5c5c5c
};

static __constant uint16 pad5 =
{
	0x00000001, 0x80000000, 0x00000000, 0x00000000,
	0x00000000, 0x00000000, 0x00000000, 0x00000000,
	0x00000000, 0x00000000, 0x00000000, 0x00000000,
	0x00000000, 0x00000000, 0x00000000, 0x00002220
};

static __constant uint16 pad3 =
{
	0x00000000, 0x00000000, 0x00000000, 0x00000000,
	0x00000000, 0x80000000, 0x00000000, 0x00000000,
	0x00000000, 0x00000000, 0x00000000, 0x00000000,
	0x00000000, 0x00000000, 0x00000000, 0x000004a0
};

static __constant uint16 padsha80 =
{
	0x00000000, 0x00000000, 0x00000000, 0x00000000,
	0x80000000, 0x00000000, 0x00000000, 0x00000000,
	0x00000000, 0x00000000, 0x00000000, 0x00000000,
	0x00000000, 0x00000000, 0x00000000, 0x00000280
};

static __constant uint8 pad4 =
{
	0x80000000, 0x00000000, 0x00000000, 0x00000000,
	0x00000000, 0x00000000, 0x00000000, 0x00000300
};



static __constant  uint8 H256 = {
	0x6A09E667, 0xBB67AE85, 0x3C6EF372,
	0xA54FF53A, 0x510E527F, 0x9B05688C,
	0x1F83D9AB, 0x5BE0CD19
};

inline uint8 swapvec(uint8 buf)
{
	uint8 vec;
	vec.s0 = SWAP32(buf.s0);
	vec.s1 = SWAP32(buf.s1);
	vec.s2 = SWAP32(buf.s2);
	vec.s3 = SWAP32(buf.s3);
	vec.s4 = SWAP32(buf.s4);
	vec.s5 = SWAP32(buf.s5);
	vec.s6 = SWAP32(buf.s6);
	vec.s7 = SWAP32(buf.s7);
	return vec;
}



inline uint16 swapvec16(uint16 buf)
{
	uint16 vec;
	vec.s0 = SWAP32(buf.s0);
	vec.s1 = SWAP32(buf.s1);
	vec.s2 = SWAP32(buf.s2);
	vec.s3 = SWAP32(buf.s3);
	vec.s4 = SWAP32(buf.s4);
	vec.s5 = SWAP32(buf.s5);
	vec.s6 = SWAP32(buf.s6);
	vec.s7 = SWAP32(buf.s7);
	vec.s8 = SWAP32(buf.s8);
	vec.s9 = SWAP32(buf.s9);
	vec.sa = SWAP32(buf.sa);
	vec.sb = SWAP32(buf.sb);
	vec.sc = SWAP32(buf.sc);
	vec.sd = SWAP32(buf.sd);
	vec.se = SWAP32(buf.se);
	vec.sf = SWAP32(buf.sf);
	return vec;
}

 ulong8 salsa20_8(uint16 Bx)
{
uint t;
	uint16 st = Bx;
	uSALSA_CORE(st);
	uSALSA_CORE(st);
	uSALSA_CORE(st);
	uSALSA_CORE(st);
	return(as_ulong8(st + Bx));
}

 ulong8 salsa20_8n(uint16 Bx)
 {
	 uint t;
	 uint16 st = Bx;
	 SALSA_CORE(st);
	 SALSA_CORE(st);
	 SALSA_CORE(st);
	 SALSA_CORE(st);
	 return(as_ulong8(st + Bx));
 }


 ulong16 blockmix_salsa8_small2(ulong16 Bin)
{
	ulong8 X = Bin.hi;
	X ^= Bin.lo;
	X = salsa20_8(as_uint16(X));
	Bin.lo = X;
	X ^= Bin.hi;
	X = salsa20_8(as_uint16(X));
	Bin.hi = X;
	return(Bin);
}
/*
 uint16 salsa20_8_2(uint16 Bx)
 {
	 uint t;
	 uint16 st = Bx;
	 uSALSA_CORE(st);
	 uSALSA_CORE(st);
	 uSALSA_CORE(st);
	 uSALSA_CORE(st);
	 return(st + Bx);
 }

 ulong16 blockmix_salsa8_small2(ulong16 Bin)
 {
	 uint16 X = as_uint16(Bin.hi);
	 X ^= as_uint16(Bin.lo);
	 X = salsa20_8_2(as_uint16(X));
	 Bin.lo = as_ulong8(X);
	 X ^= as_uint16(Bin.hi);
	 X = salsa20_8_2(as_uint16(X));
	 Bin.hi = as_ulong8(X);
	 return(Bin);
 }
*/


inline ulong2 madd4long2(uint4 a, uint4 b)
{
	uint4 result;
	result.x = a.x*a.y + b.x;
	result.y = b.y + mad_hi(a.x, a.y, b.x);
	result.z = a.z*a.w + b.z;
	result.w = b.w + mad_hi(a.z, a.w, b.z);
	return as_ulong2(result);
}

inline ulong2 madd4long3(uint4 a, ulong2 b)
{
	ulong2 result;
	result.x = (ulong)a.x*(ulong)a.y + b.x;
	result.y = (ulong)a.z*(ulong)a.w + b.y;
	return result;
}


inline ulong8 block_pwxform_long_old(ulong8 Bout, __global ulong16 *prevstate)
{

		ulong2 vec = Bout.lo.lo;

		for (int i = 0; i < 6; i++)
		{
			ulong2 p0, p1;
			uint2 x = as_uint2((vec.x >> 4) & 0x000000FF000000FF);
			p0 = ((__global ulong2*)(prevstate ))[x.x];
			vec = madd4long3(as_uint4(vec), p0);
			p1 = ((__global  ulong2*)(prevstate + 32))[x.y];

			vec ^= p1;
		}
		Bout.lo.lo = vec;
        vec = Bout.lo.hi;
		for (int i = 0; i < 6; i++)
		{

			ulong2 p0, p1;
			uint2 x = as_uint2((vec.x >> 4) & 0x000000FF000000FF);
			p0 = ((__global  ulong2*)(prevstate))[x.x];
			vec = madd4long3(as_uint4(vec), p0);
			p1 = ((__global ulong2*)(prevstate + 32))[x.y];

			vec ^= p1;
		}
		Bout.lo.hi = vec;

		vec = Bout.hi.lo;
		for (int i = 0; i < 6; i++)
		{
			ulong2 p0, p1;
			uint2 x = as_uint2((vec.x >> 4) & 0x000000FF000000FF);
			p0 = ((__global  ulong2*)(prevstate))[x.x];
			vec = madd4long3(as_uint4(vec), p0);
			p1 = ((__global  ulong2*)(prevstate + 32))[x.y];
			vec ^= p1;
		}
		Bout.hi.lo = vec;
		vec = Bout.hi.hi;
		for (int i = 0; i < 6; i++)
		{
			ulong2 p0, p1;
			uint2 x = as_uint2((vec.x >> 4) & 0x000000FF000000FF);
			p0 = ((__global  ulong2*)(prevstate))[x.x];
			vec = madd4long3(as_uint4(vec), p0);
			p1 = ((__global  ulong2*)(prevstate + 32))[x.y];

			vec ^= p1;
		}
		Bout.hi.hi = vec;

		return(Bout);
}

inline ulong8 block_pwxform_long(ulong8 Bout, __global ulong2 *prevstate)
{

	ulong2 vec = Bout.lo.lo;

	for (int i = 0; i < 6; i++)
	{
		ulong2 p0, p1;
		uint2 x = as_uint2((vec.x >> 4) & 0x000000FF000000FF);
		p0 = prevstate[x.x];
		vec = madd4long3(as_uint4(vec), p0);
		p1 = (prevstate + 32*8)[x.y];

		vec ^= p1;
	}
	Bout.lo.lo = vec;
	vec = Bout.lo.hi;
	for (int i = 0; i < 6; i++)
	{

		ulong2 p0, p1;
		uint2 x = as_uint2((vec.x >> 4) & 0x000000FF000000FF);
		p0 = prevstate[x.x];
		vec = madd4long3(as_uint4(vec), p0);
		p1 = (prevstate + 32 * 8)[x.y];

		vec ^= p1;
	}
	Bout.lo.hi = vec;

	vec = Bout.hi.lo;
	for (int i = 0; i < 6; i++)
	{
		ulong2 p0, p1;
		uint2 x = as_uint2((vec.x >> 4) & 0x000000FF000000FF);
		p0 = prevstate[x.x];
		vec = madd4long3(as_uint4(vec), p0);
		p1 = (prevstate + 32 * 8)[x.y];
		vec ^= p1;
	}
	Bout.hi.lo = vec;
	vec = Bout.hi.hi;
	for (int i = 0; i < 6; i++)
	{
		ulong2 p0, p1;
		uint2 x = as_uint2((vec.x >> 4) & 0x000000FF000000FF);
		p0 = prevstate[x.x];
		vec = madd4long3(as_uint4(vec), p0);
		p1 = (prevstate + 32 * 8)[x.y];

		vec ^= p1;
	}
	Bout.hi.hi = vec;

	return(Bout);
}




inline void blockmix_pwxform(__global ulong8 *Bin, __global  ulong16 *prevstate)
{
	Bin[0] ^= Bin[15];
	Bin[0] = block_pwxform_long_old(Bin[0], prevstate);
#pragma unroll 1
	for (int i = 1; i < 16; i++)
	{
		Bin[i] ^= Bin[i - 1];
		Bin[i] = block_pwxform_long_old(Bin[i], prevstate);
	}
	Bin[15] = salsa20_8(as_uint16(Bin[15]));
}

#define SHR(x, n)    ((x) >> n)


#define S0(x) (ROL32(x, 25) ^ ROL32(x, 14) ^  SHR(x, 3))
#define S1(x) (ROL32(x, 15) ^ ROL32(x, 13) ^  SHR(x, 10))

#define S2(x) (ROL32(x, 30) ^ ROL32(x, 19) ^ ROL32(x, 10))
#define S3(x) (ROL32(x, 26) ^ ROL32(x, 21) ^ ROL32(x, 7))

#define P(a,b,c,d,e,f,g,h,x,K)                  \
{                                               \
    temp1 = h + S3(e) + F1(e,f,g) + (K + x);      \
    d += temp1; h = temp1 + S2(a) + F0(a,b,c);  \
}

#define PLAST(a,b,c,d,e,f,g,h,x,K)                  \
{                                               \
    d += h + S3(e) + F1(e,f,g) + (x + K);              \
}

#define F0(y, x, z) bitselect(z, y, z ^ x)
#define F1(x, y, z) bitselect(z, y, x)

#define R0 (W0 = S1(W14) + W9 + S0(W1) + W0)
#define R1 (W1 = S1(W15) + W10 + S0(W2) + W1)
#define R2 (W2 = S1(W0) + W11 + S0(W3) + W2)
#define R3 (W3 = S1(W1) + W12 + S0(W4) + W3)
#define R4 (W4 = S1(W2) + W13 + S0(W5) + W4)
#define R5 (W5 = S1(W3) + W14 + S0(W6) + W5)
#define R6 (W6 = S1(W4) + W15 + S0(W7) + W6)
#define R7 (W7 = S1(W5) + W0 + S0(W8) + W7)
#define R8 (W8 = S1(W6) + W1 + S0(W9) + W8)
#define R9 (W9 = S1(W7) + W2 + S0(W10) + W9)
#define R10 (W10 = S1(W8) + W3 + S0(W11) + W10)
#define R11 (W11 = S1(W9) + W4 + S0(W12) + W11)
#define R12 (W12 = S1(W10) + W5 + S0(W13) + W12)
#define R13 (W13 = S1(W11) + W6 + S0(W14) + W13)
#define R14 (W14 = S1(W12) + W7 + S0(W15) + W14)
#define R15 (W15 = S1(W13) + W8 + S0(W0) + W15)

#define RD14 (S1(W12) + W7 + S0(W15) + W14)
#define RD15 (S1(W13) + W8 + S0(W0) + W15)

/// generic sha transform
inline uint8 sha256_Transform(uint16 data, uint8 state)
{
uint temp1;
    uint8 res = state;
	uint W0 = data.s0;
	uint W1 = data.s1;
	uint W2 = data.s2;
	uint W3 = data.s3;
	uint W4 = data.s4;
	uint W5 = data.s5;
	uint W6 = data.s6;
	uint W7 = data.s7;
	uint W8 = data.s8;
	uint W9 = data.s9;
	uint W10 = data.sA;
	uint W11 = data.sB;
	uint W12 = data.sC;
	uint W13 = data.sD;
	uint W14 = data.sE;
	uint W15 = data.sF;

#define v0  res.s0
#define v1  res.s1
#define v2  res.s2
#define v3  res.s3
#define v4  res.s4
#define v5  res.s5
#define v6  res.s6
#define v7  res.s7

	P(v0, v1, v2, v3, v4, v5, v6, v7, W0, 0x428A2F98);
	P(v7, v0, v1, v2, v3, v4, v5, v6, W1, 0x71374491);
	P(v6, v7, v0, v1, v2, v3, v4, v5, W2, 0xB5C0FBCF);
	P(v5, v6, v7, v0, v1, v2, v3, v4, W3, 0xE9B5DBA5);
	P(v4, v5, v6, v7, v0, v1, v2, v3, W4, 0x3956C25B);
	P(v3, v4, v5, v6, v7, v0, v1, v2, W5, 0x59F111F1);
	P(v2, v3, v4, v5, v6, v7, v0, v1, W6, 0x923F82A4);
	P(v1, v2, v3, v4, v5, v6, v7, v0, W7, 0xAB1C5ED5);
	P(v0, v1, v2, v3, v4, v5, v6, v7, W8, 0xD807AA98);
	P(v7, v0, v1, v2, v3, v4, v5, v6, W9, 0x12835B01);
	P(v6, v7, v0, v1, v2, v3, v4, v5, W10, 0x243185BE);
	P(v5, v6, v7, v0, v1, v2, v3, v4, W11, 0x550C7DC3);
	P(v4, v5, v6, v7, v0, v1, v2, v3, W12, 0x72BE5D74);
	P(v3, v4, v5, v6, v7, v0, v1, v2, W13, 0x80DEB1FE);
	P(v2, v3, v4, v5, v6, v7, v0, v1, W14, 0x9BDC06A7);
	P(v1, v2, v3, v4, v5, v6, v7, v0, W15, 0xC19BF174);

	P(v0, v1, v2, v3, v4, v5, v6, v7, R0, 0xE49B69C1);
	P(v7, v0, v1, v2, v3, v4, v5, v6, R1, 0xEFBE4786);
	P(v6, v7, v0, v1, v2, v3, v4, v5, R2, 0x0FC19DC6);
	P(v5, v6, v7, v0, v1, v2, v3, v4, R3, 0x240CA1CC);
	P(v4, v5, v6, v7, v0, v1, v2, v3, R4, 0x2DE92C6F);
	P(v3, v4, v5, v6, v7, v0, v1, v2, R5, 0x4A7484AA);
	P(v2, v3, v4, v5, v6, v7, v0, v1, R6, 0x5CB0A9DC);
	P(v1, v2, v3, v4, v5, v6, v7, v0, R7, 0x76F988DA);
	P(v0, v1, v2, v3, v4, v5, v6, v7, R8, 0x983E5152);
	P(v7, v0, v1, v2, v3, v4, v5, v6, R9, 0xA831C66D);
	P(v6, v7, v0, v1, v2, v3, v4, v5, R10, 0xB00327C8);
	P(v5, v6, v7, v0, v1, v2, v3, v4, R11, 0xBF597FC7);
	P(v4, v5, v6, v7, v0, v1, v2, v3, R12, 0xC6E00BF3);
	P(v3, v4, v5, v6, v7, v0, v1, v2, R13, 0xD5A79147);
	P(v2, v3, v4, v5, v6, v7, v0, v1, R14, 0x06CA6351);
	P(v1, v2, v3, v4, v5, v6, v7, v0, R15, 0x14292967);

	P(v0, v1, v2, v3, v4, v5, v6, v7, R0, 0x27B70A85);
	P(v7, v0, v1, v2, v3, v4, v5, v6, R1, 0x2E1B2138);
	P(v6, v7, v0, v1, v2, v3, v4, v5, R2, 0x4D2C6DFC);
	P(v5, v6, v7, v0, v1, v2, v3, v4, R3, 0x53380D13);
	P(v4, v5, v6, v7, v0, v1, v2, v3, R4, 0x650A7354);
	P(v3, v4, v5, v6, v7, v0, v1, v2, R5, 0x766A0ABB);
	P(v2, v3, v4, v5, v6, v7, v0, v1, R6, 0x81C2C92E);
	P(v1, v2, v3, v4, v5, v6, v7, v0, R7, 0x92722C85);
	P(v0, v1, v2, v3, v4, v5, v6, v7, R8, 0xA2BFE8A1);
	P(v7, v0, v1, v2, v3, v4, v5, v6, R9, 0xA81A664B);
	P(v6, v7, v0, v1, v2, v3, v4, v5, R10, 0xC24B8B70);
	P(v5, v6, v7, v0, v1, v2, v3, v4, R11, 0xC76C51A3);
	P(v4, v5, v6, v7, v0, v1, v2, v3, R12, 0xD192E819);
	P(v3, v4, v5, v6, v7, v0, v1, v2, R13, 0xD6990624);
	P(v2, v3, v4, v5, v6, v7, v0, v1, R14, 0xF40E3585);
	P(v1, v2, v3, v4, v5, v6, v7, v0, R15, 0x106AA070);

	P(v0, v1, v2, v3, v4, v5, v6, v7, R0, 0x19A4C116);
	P(v7, v0, v1, v2, v3, v4, v5, v6, R1, 0x1E376C08);
	P(v6, v7, v0, v1, v2, v3, v4, v5, R2, 0x2748774C);
	P(v5, v6, v7, v0, v1, v2, v3, v4, R3, 0x34B0BCB5);
	P(v4, v5, v6, v7, v0, v1, v2, v3, R4, 0x391C0CB3);
	P(v3, v4, v5, v6, v7, v0, v1, v2, R5, 0x4ED8AA4A);
	P(v2, v3, v4, v5, v6, v7, v0, v1, R6, 0x5B9CCA4F);
	P(v1, v2, v3, v4, v5, v6, v7, v0, R7, 0x682E6FF3);
	P(v0, v1, v2, v3, v4, v5, v6, v7, R8, 0x748F82EE);
	P(v7, v0, v1, v2, v3, v4, v5, v6, R9, 0x78A5636F);
	P(v6, v7, v0, v1, v2, v3, v4, v5, R10, 0x84C87814);
	P(v5, v6, v7, v0, v1, v2, v3, v4, R11, 0x8CC70208);
	P(v4, v5, v6, v7, v0, v1, v2, v3, R12, 0x90BEFFFA);
	P(v3, v4, v5, v6, v7, v0, v1, v2, R13, 0xA4506CEB);
	P(v2, v3, v4, v5, v6, v7, v0, v1, RD14, 0xBEF9A3F7);
	P(v1, v2, v3, v4, v5, v6, v7, v0, RD15, 0xC67178F2);
#undef v0
#undef v1
#undef v2
#undef v3
#undef v4
#undef v5
#undef v6
#undef v7
	return (res+state);
}


static inline uint8 sha256_round1(uint16 data)
{
	uint temp1;
    uint8 res;
	uint W0 = data.s0;
	uint W1 = data.s1;
	uint W2 = data.s2;
	uint W3 = data.s3;
	uint W4 = data.s4;
	uint W5 = data.s5;
	uint W6 = data.s6;
	uint W7 = data.s7;
	uint W8 = data.s8;
	uint W9 = data.s9;
	uint W10 = data.sA;
	uint W11 = data.sB;
	uint W12 = data.sC;
	uint W13 = data.sD;
	uint W14 = data.sE;
	uint W15 = data.sF;

	uint v0 = 0x6A09E667;
	uint v1 = 0xBB67AE85;
	uint v2 = 0x3C6EF372;
	uint v3 = 0xA54FF53A;
	uint v4 = 0x510E527F;
	uint v5 = 0x9B05688C;
	uint v6 = 0x1F83D9AB;
	uint v7 = 0x5BE0CD19;

	P(v0, v1, v2, v3, v4, v5, v6, v7, W0, 0x428A2F98);
	P(v7, v0, v1, v2, v3, v4, v5, v6, W1, 0x71374491);
	P(v6, v7, v0, v1, v2, v3, v4, v5, W2, 0xB5C0FBCF);
	P(v5, v6, v7, v0, v1, v2, v3, v4, W3, 0xE9B5DBA5);
	P(v4, v5, v6, v7, v0, v1, v2, v3, W4, 0x3956C25B);
	P(v3, v4, v5, v6, v7, v0, v1, v2, W5, 0x59F111F1);
	P(v2, v3, v4, v5, v6, v7, v0, v1, W6, 0x923F82A4);
	P(v1, v2, v3, v4, v5, v6, v7, v0, W7, 0xAB1C5ED5);
	P(v0, v1, v2, v3, v4, v5, v6, v7, W8, 0xD807AA98);
	P(v7, v0, v1, v2, v3, v4, v5, v6, W9, 0x12835B01);
	P(v6, v7, v0, v1, v2, v3, v4, v5, W10, 0x243185BE);
	P(v5, v6, v7, v0, v1, v2, v3, v4, W11, 0x550C7DC3);
	P(v4, v5, v6, v7, v0, v1, v2, v3, W12, 0x72BE5D74);
	P(v3, v4, v5, v6, v7, v0, v1, v2, W13, 0x80DEB1FE);
	P(v2, v3, v4, v5, v6, v7, v0, v1, W14, 0x9BDC06A7);
	P(v1, v2, v3, v4, v5, v6, v7, v0, W15, 0xC19BF174);

	P(v0, v1, v2, v3, v4, v5, v6, v7, R0, 0xE49B69C1);
	P(v7, v0, v1, v2, v3, v4, v5, v6, R1, 0xEFBE4786);
	P(v6, v7, v0, v1, v2, v3, v4, v5, R2, 0x0FC19DC6);
	P(v5, v6, v7, v0, v1, v2, v3, v4, R3, 0x240CA1CC);
	P(v4, v5, v6, v7, v0, v1, v2, v3, R4, 0x2DE92C6F);
	P(v3, v4, v5, v6, v7, v0, v1, v2, R5, 0x4A7484AA);
	P(v2, v3, v4, v5, v6, v7, v0, v1, R6, 0x5CB0A9DC);
	P(v1, v2, v3, v4, v5, v6, v7, v0, R7, 0x76F988DA);
	P(v0, v1, v2, v3, v4, v5, v6, v7, R8, 0x983E5152);
	P(v7, v0, v1, v2, v3, v4, v5, v6, R9, 0xA831C66D);
	P(v6, v7, v0, v1, v2, v3, v4, v5, R10, 0xB00327C8);
	P(v5, v6, v7, v0, v1, v2, v3, v4, R11, 0xBF597FC7);
	P(v4, v5, v6, v7, v0, v1, v2, v3, R12, 0xC6E00BF3);
	P(v3, v4, v5, v6, v7, v0, v1, v2, R13, 0xD5A79147);
	P(v2, v3, v4, v5, v6, v7, v0, v1, R14, 0x06CA6351);
	P(v1, v2, v3, v4, v5, v6, v7, v0, R15, 0x14292967);

	P(v0, v1, v2, v3, v4, v5, v6, v7, R0, 0x27B70A85);
	P(v7, v0, v1, v2, v3, v4, v5, v6, R1, 0x2E1B2138);
	P(v6, v7, v0, v1, v2, v3, v4, v5, R2, 0x4D2C6DFC);
	P(v5, v6, v7, v0, v1, v2, v3, v4, R3, 0x53380D13);
	P(v4, v5, v6, v7, v0, v1, v2, v3, R4, 0x650A7354);
	P(v3, v4, v5, v6, v7, v0, v1, v2, R5, 0x766A0ABB);
	P(v2, v3, v4, v5, v6, v7, v0, v1, R6, 0x81C2C92E);
	P(v1, v2, v3, v4, v5, v6, v7, v0, R7, 0x92722C85);
	P(v0, v1, v2, v3, v4, v5, v6, v7, R8, 0xA2BFE8A1);
	P(v7, v0, v1, v2, v3, v4, v5, v6, R9, 0xA81A664B);
	P(v6, v7, v0, v1, v2, v3, v4, v5, R10, 0xC24B8B70);
	P(v5, v6, v7, v0, v1, v2, v3, v4, R11, 0xC76C51A3);
	P(v4, v5, v6, v7, v0, v1, v2, v3, R12, 0xD192E819);
	P(v3, v4, v5, v6, v7, v0, v1, v2, R13, 0xD6990624);
	P(v2, v3, v4, v5, v6, v7, v0, v1, R14, 0xF40E3585);
	P(v1, v2, v3, v4, v5, v6, v7, v0, R15, 0x106AA070);

	P(v0, v1, v2, v3, v4, v5, v6, v7, R0, 0x19A4C116);
	P(v7, v0, v1, v2, v3, v4, v5, v6, R1, 0x1E376C08);
	P(v6, v7, v0, v1, v2, v3, v4, v5, R2, 0x2748774C);
	P(v5, v6, v7, v0, v1, v2, v3, v4, R3, 0x34B0BCB5);
	P(v4, v5, v6, v7, v0, v1, v2, v3, R4, 0x391C0CB3);
	P(v3, v4, v5, v6, v7, v0, v1, v2, R5, 0x4ED8AA4A);
	P(v2, v3, v4, v5, v6, v7, v0, v1, R6, 0x5B9CCA4F);
	P(v1, v2, v3, v4, v5, v6, v7, v0, R7, 0x682E6FF3);
	P(v0, v1, v2, v3, v4, v5, v6, v7, R8, 0x748F82EE);
	P(v7, v0, v1, v2, v3, v4, v5, v6, R9, 0x78A5636F);
	P(v6, v7, v0, v1, v2, v3, v4, v5, R10, 0x84C87814);
	P(v5, v6, v7, v0, v1, v2, v3, v4, R11, 0x8CC70208);
	P(v4, v5, v6, v7, v0, v1, v2, v3, R12, 0x90BEFFFA);
	P(v3, v4, v5, v6, v7, v0, v1, v2, R13, 0xA4506CEB);
	P(v2, v3, v4, v5, v6, v7, v0, v1, RD14, 0xBEF9A3F7);
	P(v1, v2, v3, v4, v5, v6, v7, v0, RD15, 0xC67178F2);

	res.s0 = v0 + 0x6A09E667;
	res.s1 = v1 + 0xBB67AE85;
	res.s2 = v2 + 0x3C6EF372;
	res.s3 = v3 + 0xA54FF53A;
	res.s4 = v4 + 0x510E527F;
	res.s5 = v5 + 0x9B05688C;
	res.s6 = v6 + 0x1F83D9AB;
	res.s7 = v7 + 0x5BE0CD19;
	return (res);
}


static inline uint8 sha256_round2(uint16 data,uint8 buf)
{
	uint temp1;
	uint8 res;
	uint W0 = data.s0;
	uint W1 = data.s1;
	uint W2 = data.s2;
	uint W3 = data.s3;
	uint W4 = data.s4;
	uint W5 = data.s5;
	uint W6 = data.s6;
	uint W7 = data.s7;
	uint W8 = data.s8;
	uint W9 = data.s9;
	uint W10 = data.sA;
	uint W11 = data.sB;
	uint W12 = data.sC;
	uint W13 = data.sD;
	uint W14 = data.sE;
	uint W15 = data.sF;

	uint v0 = buf.s0;
	uint v1 = buf.s1;
	uint v2 = buf.s2;
	uint v3 = buf.s3;
	uint v4 = buf.s4;
	uint v5 = buf.s5;
	uint v6 = buf.s6;
	uint v7 = buf.s7;

	P(v0, v1, v2, v3, v4, v5, v6, v7, W0, 0x428A2F98);
	P(v7, v0, v1, v2, v3, v4, v5, v6, W1, 0x71374491);
	P(v6, v7, v0, v1, v2, v3, v4, v5, W2, 0xB5C0FBCF);
	P(v5, v6, v7, v0, v1, v2, v3, v4, W3, 0xE9B5DBA5);
	P(v4, v5, v6, v7, v0, v1, v2, v3, W4, 0x3956C25B);
	P(v3, v4, v5, v6, v7, v0, v1, v2, W5, 0x59F111F1);
	P(v2, v3, v4, v5, v6, v7, v0, v1, W6, 0x923F82A4);
	P(v1, v2, v3, v4, v5, v6, v7, v0, W7, 0xAB1C5ED5);
	P(v0, v1, v2, v3, v4, v5, v6, v7, W8, 0xD807AA98);
	P(v7, v0, v1, v2, v3, v4, v5, v6, W9, 0x12835B01);
	P(v6, v7, v0, v1, v2, v3, v4, v5, W10, 0x243185BE);
	P(v5, v6, v7, v0, v1, v2, v3, v4, W11, 0x550C7DC3);
	P(v4, v5, v6, v7, v0, v1, v2, v3, W12, 0x72BE5D74);
	P(v3, v4, v5, v6, v7, v0, v1, v2, W13, 0x80DEB1FE);
	P(v2, v3, v4, v5, v6, v7, v0, v1, W14, 0x9BDC06A7);
	P(v1, v2, v3, v4, v5, v6, v7, v0, W15, 0xC19BF174);

	P(v0, v1, v2, v3, v4, v5, v6, v7, R0, 0xE49B69C1);
	P(v7, v0, v1, v2, v3, v4, v5, v6, R1, 0xEFBE4786);
	P(v6, v7, v0, v1, v2, v3, v4, v5, R2, 0x0FC19DC6);
	P(v5, v6, v7, v0, v1, v2, v3, v4, R3, 0x240CA1CC);
	P(v4, v5, v6, v7, v0, v1, v2, v3, R4, 0x2DE92C6F);
	P(v3, v4, v5, v6, v7, v0, v1, v2, R5, 0x4A7484AA);
	P(v2, v3, v4, v5, v6, v7, v0, v1, R6, 0x5CB0A9DC);
	P(v1, v2, v3, v4, v5, v6, v7, v0, R7, 0x76F988DA);
	P(v0, v1, v2, v3, v4, v5, v6, v7, R8, 0x983E5152);
	P(v7, v0, v1, v2, v3, v4, v5, v6, R9, 0xA831C66D);
	P(v6, v7, v0, v1, v2, v3, v4, v5, R10, 0xB00327C8);
	P(v5, v6, v7, v0, v1, v2, v3, v4, R11, 0xBF597FC7);
	P(v4, v5, v6, v7, v0, v1, v2, v3, R12, 0xC6E00BF3);
	P(v3, v4, v5, v6, v7, v0, v1, v2, R13, 0xD5A79147);
	P(v2, v3, v4, v5, v6, v7, v0, v1, R14, 0x06CA6351);
	P(v1, v2, v3, v4, v5, v6, v7, v0, R15, 0x14292967);

	P(v0, v1, v2, v3, v4, v5, v6, v7, R0, 0x27B70A85);
	P(v7, v0, v1, v2, v3, v4, v5, v6, R1, 0x2E1B2138);
	P(v6, v7, v0, v1, v2, v3, v4, v5, R2, 0x4D2C6DFC);
	P(v5, v6, v7, v0, v1, v2, v3, v4, R3, 0x53380D13);
	P(v4, v5, v6, v7, v0, v1, v2, v3, R4, 0x650A7354);
	P(v3, v4, v5, v6, v7, v0, v1, v2, R5, 0x766A0ABB);
	P(v2, v3, v4, v5, v6, v7, v0, v1, R6, 0x81C2C92E);
	P(v1, v2, v3, v4, v5, v6, v7, v0, R7, 0x92722C85);
	P(v0, v1, v2, v3, v4, v5, v6, v7, R8, 0xA2BFE8A1);
	P(v7, v0, v1, v2, v3, v4, v5, v6, R9, 0xA81A664B);
	P(v6, v7, v0, v1, v2, v3, v4, v5, R10, 0xC24B8B70);
	P(v5, v6, v7, v0, v1, v2, v3, v4, R11, 0xC76C51A3);
	P(v4, v5, v6, v7, v0, v1, v2, v3, R12, 0xD192E819);
	P(v3, v4, v5, v6, v7, v0, v1, v2, R13, 0xD6990624);
	P(v2, v3, v4, v5, v6, v7, v0, v1, R14, 0xF40E3585);
	P(v1, v2, v3, v4, v5, v6, v7, v0, R15, 0x106AA070);

	P(v0, v1, v2, v3, v4, v5, v6, v7, R0, 0x19A4C116);
	P(v7, v0, v1, v2, v3, v4, v5, v6, R1, 0x1E376C08);
	P(v6, v7, v0, v1, v2, v3, v4, v5, R2, 0x2748774C);
	P(v5, v6, v7, v0, v1, v2, v3, v4, R3, 0x34B0BCB5);
	P(v4, v5, v6, v7, v0, v1, v2, v3, R4, 0x391C0CB3);
	P(v3, v4, v5, v6, v7, v0, v1, v2, R5, 0x4ED8AA4A);
	P(v2, v3, v4, v5, v6, v7, v0, v1, R6, 0x5B9CCA4F);
	P(v1, v2, v3, v4, v5, v6, v7, v0, R7, 0x682E6FF3);
	P(v0, v1, v2, v3, v4, v5, v6, v7, R8, 0x748F82EE);
	P(v7, v0, v1, v2, v3, v4, v5, v6, R9, 0x78A5636F);
	P(v6, v7, v0, v1, v2, v3, v4, v5, R10, 0x84C87814);
	P(v5, v6, v7, v0, v1, v2, v3, v4, R11, 0x8CC70208);
	P(v4, v5, v6, v7, v0, v1, v2, v3, R12, 0x90BEFFFA);
	P(v3, v4, v5, v6, v7, v0, v1, v2, R13, 0xA4506CEB);
	P(v2, v3, v4, v5, v6, v7, v0, v1, RD14, 0xBEF9A3F7);
	P(v1, v2, v3, v4, v5, v6, v7, v0, RD15, 0xC67178F2);

	res.s0 = (v0 + buf.s0);
	res.s1 = (v1 + buf.s1);
	res.s2 = (v2 + buf.s2);
	res.s3 = (v3 + buf.s3);
	res.s4 = (v4 + buf.s4);
	res.s5 = (v5 + buf.s5);
	res.s6 = (v6 + buf.s6);
	res.s7 = (v7 + buf.s7);
	return (res);
}

static inline uint8 sha256_80(uint* data,uint nonce)
{

uint8 buf = sha256_round1( ((uint16*)data)[0]);
uint16 in = padsha80;
in.s0 = data[16];
in.s1 = data[17];
in.s2 = data[18];
in.s3 = nonce;

return(sha256_round2(in,buf));
}

