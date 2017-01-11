/*
* Lyra2 kernel implementation.
*
* ==========================(LICENSE BEGIN)============================
* Copyright (c) 2014 djm34
*
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



#define ROTL64(x,n) rotate(x,(ulong)n)
#define ROTR64(x,n) rotate(x,(ulong)(64-n))
#define SWAP32(x) as_ulong(as_uint2(x).s10)
#define SWAP24(x) as_ulong(as_uchar8(x).s34567012)
#define SWAP16(x) as_ulong(as_uchar8(x).s23456701)

#define G(a,b,c,d) \
  do { \
	a += b; d ^= a; d = SWAP32(d); \
	c += d; b ^= c; b = ROTR64(b,24); \
	a += b; d ^= a; d = ROTR64(d,16); \
	c += d; b ^= c; b = ROTR64(b, 63); \
\
  } while (0)

#define G_old(a,b,c,d) \
  do { \
	a += b; d ^= a; d = ROTR64(d, 32); \
	c += d; b ^= c; b = ROTR64(b, 24); \
	a += b; d ^= a; d = ROTR64(d, 16); \
	c += d; b ^= c; b = ROTR64(b, 63); \
\
  } while (0)


/*One Round of the Blake2b's compression function*/

#define round_lyra(s)  \
 do { \
	 G(s[0].x, s[1].x, s[2].x, s[3].x); \
     G(s[0].y, s[1].y, s[2].y, s[3].y); \
     G(s[0].z, s[1].z, s[2].z, s[3].z); \
     G(s[0].w, s[1].w, s[2].w, s[3].w); \
     G(s[0].x, s[1].y, s[2].z, s[3].w); \
     G(s[0].y, s[1].z, s[2].w, s[3].x); \
     G(s[0].z, s[1].w, s[2].x, s[3].y); \
     G(s[0].w, s[1].x, s[2].y, s[3].z); \
 } while(0)



void reduceDuplexf(ulong4* state ,__global ulong4* DMatrix)
{

	 ulong4 state1[3];
	 uint ps1 = 0;
	 uint ps2 = (memshift * 3 + memshift * 4);
//#pragma unroll 4
	 for (int i = 0; i < 4; i++)
	 {
		 uint s1 = ps1 + i*memshift;
		 uint s2 = ps2 - i*memshift;

		 for (int j = 0; j < 3; j++)  state1[j] = (DMatrix)[j + s1];

		 for (int j = 0; j < 3; j++)  state[j] ^= state1[j];
		 round_lyra(state);
		 for (int j = 0; j < 3; j++)  state1[j] ^= state[j];

		 for (int j = 0; j < 3; j++)  (DMatrix)[j + s2] = state1[j];
	 }

}



void reduceDuplexRowf(uint rowIn,uint rowInOut,uint rowOut,ulong4 * state, __global ulong4 * DMatrix)
{

ulong4 state1[3], state2[3];
uint ps1 = (memshift * 4 * rowIn);
uint ps2 = (memshift * 4 * rowInOut);
uint ps3 = (memshift * 4 * rowOut);


  for (int i = 0; i < 4; i++)
 {
  uint s1 = ps1 + i*memshift;
  uint s2 = ps2 + i*memshift;
  uint s3 = ps3 + i*memshift;


		 for (int j = 0; j < 3; j++)   state1[j] = (DMatrix)[j + s1];

         for (int j = 0; j < 3; j++)   state2[j] = (DMatrix)[j + s2];

         for (int j = 0; j < 3; j++)   state1[j] += state2[j];

         for (int j = 0; j < 3; j++)   state[j] ^= state1[j];


         round_lyra(state);

         ((ulong*)state2)[0] ^= ((ulong*)state)[11];
  for (int j = 0; j < 11; j++)
	  ((ulong*)state2)[j + 1] ^= ((ulong*)state)[j];

         if (rowInOut != rowOut) {
			 for (int j = 0; j < 3; j++)
				 (DMatrix)[j + s2] = state2[j];
			 for (int j = 0; j < 3; j++)
				 (DMatrix)[j + s3] ^= state[j];
  		 }
		 else {
			 for (int j = 0; j < 3; j++)
				 state2[j] ^= state[j];
			 for (int j = 0; j < 3; j++)
				 (DMatrix)[j + s2] = state2[j];
		 }

 }
  }




void reduceDuplexRowSetupf(uint rowIn, uint rowInOut, uint rowOut, ulong4 *state, __global ulong4* DMatrix) {

	 ulong4 state2[3], state1[3];
	 uint ps1 = (memshift * 4 * rowIn);
	 uint ps2 = (memshift * 4 * rowInOut);
	 uint ps3 = (memshift * 3 + memshift * 4 * rowOut);

	 for (int i = 0; i < 4; i++)
	 {
		 uint s1 = ps1 + i*memshift;
		 uint s2 = ps2 + i*memshift;
		 uint s3 = ps3 - i*memshift;

		 for (int j = 0; j < 3; j++)  state1[j] = (DMatrix)[j + s1];

		 for (int j = 0; j < 3; j++)  state2[j] = (DMatrix)[j + s2];
		 for (int j = 0; j < 3; j++) {
			 ulong4 tmp = state1[j] + state2[j];
			 state[j] ^= tmp;
		 		 }
		 round_lyra(state);

		 for (int j = 0; j < 3; j++) {
			 state1[j] ^= state[j];
			 (DMatrix)[j + s3] = state1[j];
		 		 }

		 ((ulong*)state2)[0] ^= ((ulong*)state)[11];
		 for (int j = 0; j < 11; j++)
			 ((ulong*)state2)[j + 1] ^= ((ulong*)state)[j];
		 for (int j = 0; j < 3; j++)
			 (DMatrix)[j + s2] = state2[j];
	 }
   }

