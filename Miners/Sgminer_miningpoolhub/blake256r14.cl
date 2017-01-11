// (c) 2013 originally written by smolen, modified by kr105

#define SPH_ROTR32(v,n) rotate((uint)(v),(uint)(32-(n)))

__attribute__((reqd_work_group_size(WORKSIZE, 1, 1)))
__kernel void search(
	volatile __global uint * restrict output,
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
	uint M0, M1, M2, M3, M4, M5, M6, M7;
	uint M8, M9, MA, MB, MC, MD, ME, MF;
	uint V0, V1, V2, V3, V4, V5, V6, V7;
	uint V8, V9, VA, VB, VC, VD, VE, VF;
	uint pre7;
	uint nonce = get_global_id(0);

	V0 = h0;
	V1 = h1;
	V2 = h2;
	V3 = h3;
	V4 = h4;
	V5 = h5;
	V6 = h6;
	pre7 = V7 = h7;
	M0 = in16;
	M1 = in17;
	M2 = in18;
	M3 = nonce;

	V8 = 0x243F6A88UL;
	V9 = 0x85A308D3UL;
	VA = 0x13198A2EUL;
	VB = 0x03707344UL;
	VC = 640 ^ 0xA4093822UL;
	VD = 640 ^ 0x299F31D0UL;
	VE = 0x082EFA98UL;
	VF = 0xEC4E6C89UL;

	M4 = 0x80000000;
	M5 = 0;
	M6 = 0;
	M7 = 0;
	M8 = 0;
	M9 = 0;
	MA = 0;
	MB = 0;
	MC = 0;
	MD = 1;
	ME = 0;
	MF = 640;

	V0 = (V0 + V4 + (M0 ^ 0x85A308D3UL)); VC = SPH_ROTR32(VC ^ V0, 16); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 12); V0 = (V0 + V4 + (M1 ^ 0x243F6A88UL)); VC = SPH_ROTR32(VC ^ V0, 8); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 7);; V1 = (V1 + V5 + (M2 ^ 0x03707344UL)); VD = SPH_ROTR32(VD ^ V1, 16); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 12); V1 = (V1 + V5 + (M3 ^ 0x13198A2EUL)); VD = SPH_ROTR32(VD ^ V1, 8); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 7);; V2 = (V2 + V6 + (M4 ^ 0x299F31D0UL)); VE = SPH_ROTR32(VE ^ V2, 16); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 12); V2 = (V2 + V6 + (M5 ^ 0xA4093822UL)); VE = SPH_ROTR32(VE ^ V2, 8); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 7);; V3 = (V3 + V7 + (M6 ^ 0xEC4E6C89UL)); VF = SPH_ROTR32(VF ^ V3, 16); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 12); V3 = (V3 + V7 + (M7 ^ 0x082EFA98UL)); VF = SPH_ROTR32(VF ^ V3, 8); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 7);; V0 = (V0 + V5 + (M8 ^ 0x38D01377UL)); VF = SPH_ROTR32(VF ^ V0, 16); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 12); V0 = (V0 + V5 + (M9 ^ 0x452821E6UL)); VF = SPH_ROTR32(VF ^ V0, 8); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 7);; V1 = (V1 + V6 + (MA ^ 0x34E90C6CUL)); VC = SPH_ROTR32(VC ^ V1, 16); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 12); V1 = (V1 + V6 + (MB ^ 0xBE5466CFUL)); VC = SPH_ROTR32(VC ^ V1, 8); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 7);; V2 = (V2 + V7 + (MC ^ 0xC97C50DDUL)); VD = SPH_ROTR32(VD ^ V2, 16); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 12); V2 = (V2 + V7 + (MD ^ 0xC0AC29B7UL)); VD = SPH_ROTR32(VD ^ V2, 8); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 7);; V3 = (V3 + V4 + (ME ^ 0xB5470917UL)); VE = SPH_ROTR32(VE ^ V3, 16); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 12); V3 = (V3 + V4 + (MF ^ 0x3F84D5B5UL)); VE = SPH_ROTR32(VE ^ V3, 8); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 7);
	V0 = (V0 + V4 + (ME ^ 0xBE5466CFUL)); VC = SPH_ROTR32(VC ^ V0, 16); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 12); V0 = (V0 + V4 + (MA ^ 0x3F84D5B5UL)); VC = SPH_ROTR32(VC ^ V0, 8); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 7);; V1 = (V1 + V5 + (M4 ^ 0x452821E6UL)); VD = SPH_ROTR32(VD ^ V1, 16); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 12); V1 = (V1 + V5 + (M8 ^ 0xA4093822UL)); VD = SPH_ROTR32(VD ^ V1, 8); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 7);; V2 = (V2 + V6 + (M9 ^ 0xB5470917UL)); VE = SPH_ROTR32(VE ^ V2, 16); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 12); V2 = (V2 + V6 + (MF ^ 0x38D01377UL)); VE = SPH_ROTR32(VE ^ V2, 8); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 7);; V3 = (V3 + V7 + (MD ^ 0x082EFA98UL)); VF = SPH_ROTR32(VF ^ V3, 16); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 12); V3 = (V3 + V7 + (M6 ^ 0xC97C50DDUL)); VF = SPH_ROTR32(VF ^ V3, 8); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 7);; V0 = (V0 + V5 + (M1 ^ 0xC0AC29B7UL)); VF = SPH_ROTR32(VF ^ V0, 16); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 12); V0 = (V0 + V5 + (MC ^ 0x85A308D3UL)); VF = SPH_ROTR32(VF ^ V0, 8); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 7);; V1 = (V1 + V6 + (M0 ^ 0x13198A2EUL)); VC = SPH_ROTR32(VC ^ V1, 16); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 12); V1 = (V1 + V6 + (M2 ^ 0x243F6A88UL)); VC = SPH_ROTR32(VC ^ V1, 8); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 7);; V2 = (V2 + V7 + (MB ^ 0xEC4E6C89UL)); VD = SPH_ROTR32(VD ^ V2, 16); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 12); V2 = (V2 + V7 + (M7 ^ 0x34E90C6CUL)); VD = SPH_ROTR32(VD ^ V2, 8); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 7);; V3 = (V3 + V4 + (M5 ^ 0x03707344UL)); VE = SPH_ROTR32(VE ^ V3, 16); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 12); V3 = (V3 + V4 + (M3 ^ 0x299F31D0UL)); VE = SPH_ROTR32(VE ^ V3, 8); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 7);
	V0 = (V0 + V4 + (MB ^ 0x452821E6UL)); VC = SPH_ROTR32(VC ^ V0, 16); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 12); V0 = (V0 + V4 + (M8 ^ 0x34E90C6CUL)); VC = SPH_ROTR32(VC ^ V0, 8); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 7);; V1 = (V1 + V5 + (MC ^ 0x243F6A88UL)); VD = SPH_ROTR32(VD ^ V1, 16); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 12); V1 = (V1 + V5 + (M0 ^ 0xC0AC29B7UL)); VD = SPH_ROTR32(VD ^ V1, 8); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 7);; V2 = (V2 + V6 + (M5 ^ 0x13198A2EUL)); VE = SPH_ROTR32(VE ^ V2, 16); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 12); V2 = (V2 + V6 + (M2 ^ 0x299F31D0UL)); VE = SPH_ROTR32(VE ^ V2, 8); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 7);; V3 = (V3 + V7 + (MF ^ 0xC97C50DDUL)); VF = SPH_ROTR32(VF ^ V3, 16); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 12); V3 = (V3 + V7 + (MD ^ 0xB5470917UL)); VF = SPH_ROTR32(VF ^ V3, 8); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 7);; V0 = (V0 + V5 + (MA ^ 0x3F84D5B5UL)); VF = SPH_ROTR32(VF ^ V0, 16); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 12); V0 = (V0 + V5 + (ME ^ 0xBE5466CFUL)); VF = SPH_ROTR32(VF ^ V0, 8); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 7);; V1 = (V1 + V6 + (M3 ^ 0x082EFA98UL)); VC = SPH_ROTR32(VC ^ V1, 16); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 12); V1 = (V1 + V6 + (M6 ^ 0x03707344UL)); VC = SPH_ROTR32(VC ^ V1, 8); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 7);; V2 = (V2 + V7 + (M7 ^ 0x85A308D3UL)); VD = SPH_ROTR32(VD ^ V2, 16); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 12); V2 = (V2 + V7 + (M1 ^ 0xEC4E6C89UL)); VD = SPH_ROTR32(VD ^ V2, 8); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 7);; V3 = (V3 + V4 + (M9 ^ 0xA4093822UL)); VE = SPH_ROTR32(VE ^ V3, 16); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 12); V3 = (V3 + V4 + (M4 ^ 0x38D01377UL)); VE = SPH_ROTR32(VE ^ V3, 8); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 7);
	V0 = (V0 + V4 + (M7 ^ 0x38D01377UL)); VC = SPH_ROTR32(VC ^ V0, 16); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 12); V0 = (V0 + V4 + (M9 ^ 0xEC4E6C89UL)); VC = SPH_ROTR32(VC ^ V0, 8); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 7);; V1 = (V1 + V5 + (M3 ^ 0x85A308D3UL)); VD = SPH_ROTR32(VD ^ V1, 16); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 12); V1 = (V1 + V5 + (M1 ^ 0x03707344UL)); VD = SPH_ROTR32(VD ^ V1, 8); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 7);; V2 = (V2 + V6 + (MD ^ 0xC0AC29B7UL)); VE = SPH_ROTR32(VE ^ V2, 16); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 12); V2 = (V2 + V6 + (MC ^ 0xC97C50DDUL)); VE = SPH_ROTR32(VE ^ V2, 8); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 7);; V3 = (V3 + V7 + (MB ^ 0x3F84D5B5UL)); VF = SPH_ROTR32(VF ^ V3, 16); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 12); V3 = (V3 + V7 + (ME ^ 0x34E90C6CUL)); VF = SPH_ROTR32(VF ^ V3, 8); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 7);; V0 = (V0 + V5 + (M2 ^ 0x082EFA98UL)); VF = SPH_ROTR32(VF ^ V0, 16); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 12); V0 = (V0 + V5 + (M6 ^ 0x13198A2EUL)); VF = SPH_ROTR32(VF ^ V0, 8); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 7);; V1 = (V1 + V6 + (M5 ^ 0xBE5466CFUL)); VC = SPH_ROTR32(VC ^ V1, 16); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 12); V1 = (V1 + V6 + (MA ^ 0x299F31D0UL)); VC = SPH_ROTR32(VC ^ V1, 8); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 7);; V2 = (V2 + V7 + (M4 ^ 0x243F6A88UL)); VD = SPH_ROTR32(VD ^ V2, 16); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 12); V2 = (V2 + V7 + (M0 ^ 0xA4093822UL)); VD = SPH_ROTR32(VD ^ V2, 8); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 7);; V3 = (V3 + V4 + (MF ^ 0x452821E6UL)); VE = SPH_ROTR32(VE ^ V3, 16); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 12); V3 = (V3 + V4 + (M8 ^ 0xB5470917UL)); VE = SPH_ROTR32(VE ^ V3, 8); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 7);
	V0 = (V0 + V4 + (M9 ^ 0x243F6A88UL)); VC = SPH_ROTR32(VC ^ V0, 16); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 12); V0 = (V0 + V4 + (M0 ^ 0x38D01377UL)); VC = SPH_ROTR32(VC ^ V0, 8); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 7);; V1 = (V1 + V5 + (M5 ^ 0xEC4E6C89UL)); VD = SPH_ROTR32(VD ^ V1, 16); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 12); V1 = (V1 + V5 + (M7 ^ 0x299F31D0UL)); VD = SPH_ROTR32(VD ^ V1, 8); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 7);; V2 = (V2 + V6 + (M2 ^ 0xA4093822UL)); VE = SPH_ROTR32(VE ^ V2, 16); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 12); V2 = (V2 + V6 + (M4 ^ 0x13198A2EUL)); VE = SPH_ROTR32(VE ^ V2, 8); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 7);; V3 = (V3 + V7 + (MA ^ 0xB5470917UL)); VF = SPH_ROTR32(VF ^ V3, 16); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 12); V3 = (V3 + V7 + (MF ^ 0xBE5466CFUL)); VF = SPH_ROTR32(VF ^ V3, 8); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 7);; V0 = (V0 + V5 + (ME ^ 0x85A308D3UL)); VF = SPH_ROTR32(VF ^ V0, 16); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 12); V0 = (V0 + V5 + (M1 ^ 0x3F84D5B5UL)); VF = SPH_ROTR32(VF ^ V0, 8); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 7);; V1 = (V1 + V6 + (MB ^ 0xC0AC29B7UL)); VC = SPH_ROTR32(VC ^ V1, 16); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 12); V1 = (V1 + V6 + (MC ^ 0x34E90C6CUL)); VC = SPH_ROTR32(VC ^ V1, 8); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 7);; V2 = (V2 + V7 + (M6 ^ 0x452821E6UL)); VD = SPH_ROTR32(VD ^ V2, 16); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 12); V2 = (V2 + V7 + (M8 ^ 0x082EFA98UL)); VD = SPH_ROTR32(VD ^ V2, 8); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 7);; V3 = (V3 + V4 + (M3 ^ 0xC97C50DDUL)); VE = SPH_ROTR32(VE ^ V3, 16); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 12); V3 = (V3 + V4 + (MD ^ 0x03707344UL)); VE = SPH_ROTR32(VE ^ V3, 8); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 7);
	V0 = (V0 + V4 + (M2 ^ 0xC0AC29B7UL)); VC = SPH_ROTR32(VC ^ V0, 16); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 12); V0 = (V0 + V4 + (MC ^ 0x13198A2EUL)); VC = SPH_ROTR32(VC ^ V0, 8); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 7);; V1 = (V1 + V5 + (M6 ^ 0xBE5466CFUL)); VD = SPH_ROTR32(VD ^ V1, 16); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 12); V1 = (V1 + V5 + (MA ^ 0x082EFA98UL)); VD = SPH_ROTR32(VD ^ V1, 8); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 7);; V2 = (V2 + V6 + (M0 ^ 0x34E90C6CUL)); VE = SPH_ROTR32(VE ^ V2, 16); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 12); V2 = (V2 + V6 + (MB ^ 0x243F6A88UL)); VE = SPH_ROTR32(VE ^ V2, 8); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 7);; V3 = (V3 + V7 + (M8 ^ 0x03707344UL)); VF = SPH_ROTR32(VF ^ V3, 16); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 12); V3 = (V3 + V7 + (M3 ^ 0x452821E6UL)); VF = SPH_ROTR32(VF ^ V3, 8); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 7);; V0 = (V0 + V5 + (M4 ^ 0xC97C50DDUL)); VF = SPH_ROTR32(VF ^ V0, 16); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 12); V0 = (V0 + V5 + (MD ^ 0xA4093822UL)); VF = SPH_ROTR32(VF ^ V0, 8); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 7);; V1 = (V1 + V6 + (M7 ^ 0x299F31D0UL)); VC = SPH_ROTR32(VC ^ V1, 16); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 12); V1 = (V1 + V6 + (M5 ^ 0xEC4E6C89UL)); VC = SPH_ROTR32(VC ^ V1, 8); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 7);; V2 = (V2 + V7 + (MF ^ 0x3F84D5B5UL)); VD = SPH_ROTR32(VD ^ V2, 16); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 12); V2 = (V2 + V7 + (ME ^ 0xB5470917UL)); VD = SPH_ROTR32(VD ^ V2, 8); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 7);; V3 = (V3 + V4 + (M1 ^ 0x38D01377UL)); VE = SPH_ROTR32(VE ^ V3, 16); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 12); V3 = (V3 + V4 + (M9 ^ 0x85A308D3UL)); VE = SPH_ROTR32(VE ^ V3, 8); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 7);
	V0 = (V0 + V4 + (MC ^ 0x299F31D0UL)); VC = SPH_ROTR32(VC ^ V0, 16); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 12); V0 = (V0 + V4 + (M5 ^ 0xC0AC29B7UL)); VC = SPH_ROTR32(VC ^ V0, 8); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 7);; V1 = (V1 + V5 + (M1 ^ 0xB5470917UL)); VD = SPH_ROTR32(VD ^ V1, 16); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 12); V1 = (V1 + V5 + (MF ^ 0x85A308D3UL)); VD = SPH_ROTR32(VD ^ V1, 8); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 7);; V2 = (V2 + V6 + (ME ^ 0xC97C50DDUL)); VE = SPH_ROTR32(VE ^ V2, 16); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 12); V2 = (V2 + V6 + (MD ^ 0x3F84D5B5UL)); VE = SPH_ROTR32(VE ^ V2, 8); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 7);; V3 = (V3 + V7 + (M4 ^ 0xBE5466CFUL)); VF = SPH_ROTR32(VF ^ V3, 16); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 12); V3 = (V3 + V7 + (MA ^ 0xA4093822UL)); VF = SPH_ROTR32(VF ^ V3, 8); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 7);; V0 = (V0 + V5 + (M0 ^ 0xEC4E6C89UL)); VF = SPH_ROTR32(VF ^ V0, 16); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 12); V0 = (V0 + V5 + (M7 ^ 0x243F6A88UL)); VF = SPH_ROTR32(VF ^ V0, 8); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 7);; V1 = (V1 + V6 + (M6 ^ 0x03707344UL)); VC = SPH_ROTR32(VC ^ V1, 16); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 12); V1 = (V1 + V6 + (M3 ^ 0x082EFA98UL)); VC = SPH_ROTR32(VC ^ V1, 8); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 7);; V2 = (V2 + V7 + (M9 ^ 0x13198A2EUL)); VD = SPH_ROTR32(VD ^ V2, 16); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 12); V2 = (V2 + V7 + (M2 ^ 0x38D01377UL)); VD = SPH_ROTR32(VD ^ V2, 8); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 7);; V3 = (V3 + V4 + (M8 ^ 0x34E90C6CUL)); VE = SPH_ROTR32(VE ^ V3, 16); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 12); V3 = (V3 + V4 + (MB ^ 0x452821E6UL)); VE = SPH_ROTR32(VE ^ V3, 8); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 7);
	V0 = (V0 + V4 + (MD ^ 0x34E90C6CUL)); VC = SPH_ROTR32(VC ^ V0, 16); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 12); V0 = (V0 + V4 + (MB ^ 0xC97C50DDUL)); VC = SPH_ROTR32(VC ^ V0, 8); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 7);; V1 = (V1 + V5 + (M7 ^ 0x3F84D5B5UL)); VD = SPH_ROTR32(VD ^ V1, 16); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 12); V1 = (V1 + V5 + (ME ^ 0xEC4E6C89UL)); VD = SPH_ROTR32(VD ^ V1, 8); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 7);; V2 = (V2 + V6 + (MC ^ 0x85A308D3UL)); VE = SPH_ROTR32(VE ^ V2, 16); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 12); V2 = (V2 + V6 + (M1 ^ 0xC0AC29B7UL)); VE = SPH_ROTR32(VE ^ V2, 8); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 7);; V3 = (V3 + V7 + (M3 ^ 0x38D01377UL)); VF = SPH_ROTR32(VF ^ V3, 16); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 12); V3 = (V3 + V7 + (M9 ^ 0x03707344UL)); VF = SPH_ROTR32(VF ^ V3, 8); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 7);; V0 = (V0 + V5 + (M5 ^ 0x243F6A88UL)); VF = SPH_ROTR32(VF ^ V0, 16); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 12); V0 = (V0 + V5 + (M0 ^ 0x299F31D0UL)); VF = SPH_ROTR32(VF ^ V0, 8); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 7);; V1 = (V1 + V6 + (MF ^ 0xA4093822UL)); VC = SPH_ROTR32(VC ^ V1, 16); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 12); V1 = (V1 + V6 + (M4 ^ 0xB5470917UL)); VC = SPH_ROTR32(VC ^ V1, 8); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 7);; V2 = (V2 + V7 + (M8 ^ 0x082EFA98UL)); VD = SPH_ROTR32(VD ^ V2, 16); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 12); V2 = (V2 + V7 + (M6 ^ 0x452821E6UL)); VD = SPH_ROTR32(VD ^ V2, 8); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 7);; V3 = (V3 + V4 + (M2 ^ 0xBE5466CFUL)); VE = SPH_ROTR32(VE ^ V3, 16); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 12); V3 = (V3 + V4 + (MA ^ 0x13198A2EUL)); VE = SPH_ROTR32(VE ^ V3, 8); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 7);

	// Constants
	// 00 = 0x243F6A88UL 
	// 01 = 0x85A308D3UL 
	// 02 = 0x13198A2EUL 
	// 03 = 0x03707344UL 
	// 04 = 0xA4093822UL 
	// 05 = 0x299F31D0UL 
	// 06 = 0x082EFA98UL 
	// 07 = 0xEC4E6C89UL 
	// 08 = 0x452821E6UL 
	// 09 = 0x38D01377UL 
	// 10 = 0xBE5466CFUL 
	// 11 = 0x34E90C6CUL 
	// 12 = 0xC0AC29B7UL 
	// 13 = 0xC97C50DDUL 
	// 14 = 0x3F84D5B5UL
	// 15 = 0xB5470917UL 
	// A=10,B=11,C=12,D=13,E=14,F=15

	// Round 9: 
	// 6^15
	V0 = (V0 + V4 + (M6 ^ 0xB5470917UL)); VC = SPH_ROTR32(VC ^ V0, 16); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 12); V0 = (V0 + V4 + (MF ^ 0x082EFA98UL)); VC = SPH_ROTR32(VC ^ V0, 8); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 7);; 
	// 14^9
	V1 = (V1 + V5 + (ME ^ 0x38D01377UL)); VD = SPH_ROTR32(VD ^ V1, 16); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 12); V1 = (V1 + V5 + (M9 ^ 0x3F84D5B5UL)); VD = SPH_ROTR32(VD ^ V1, 8); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 7);; 
	// 11^3 
	V2 = (V2 + V6 + (MB ^ 0x03707344UL)); VE = SPH_ROTR32(VE ^ V2, 16); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 12); V2 = (V2 + V6 + (M3 ^ 0x34E90C6CUL)); VE = SPH_ROTR32(VE ^ V2, 8); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 7);; 
	// 0^8 
	V3 = (V3 + V7 + (M0 ^ 0x452821E6UL)); VF = SPH_ROTR32(VF ^ V3, 16); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 12); V3 = (V3 + V7 + (M8 ^ 0x243F6A88UL)); VF = SPH_ROTR32(VF ^ V3, 8); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 7);; 
	// 12^2 
	V0 = (V0 + V5 + (MC ^ 0x13198A2EUL)); VF = SPH_ROTR32(VF ^ V0, 16); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 12); V0 = (V0 + V5 + (M2 ^ 0xC0AC29B7UL)); VF = SPH_ROTR32(VF ^ V0, 8); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 7);; 
	// 13^7 
	V1 = (V1 + V6 + (MD ^ 0xEC4E6C89UL)); VC = SPH_ROTR32(VC ^ V1, 16); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 12); V1 = (V1 + V6 + (M7 ^ 0xC97C50DDUL)); VC = SPH_ROTR32(VC ^ V1, 8); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 7);; 
	// 1^4 
	V2 = (V2 + V7 + (M1 ^ 0xA4093822UL)); VD = SPH_ROTR32(VD ^ V2, 16); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 12); V2 = (V2 + V7 + (M4 ^ 0x85A308D3UL)); VD = SPH_ROTR32(VD ^ V2, 8); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 7);; 
	// 10^5
	V3 = (V3 + V4 + (MA ^ 0x299F31D0UL)); VE = SPH_ROTR32(VE ^ V3, 16); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 12); V3 = (V3 + V4 + (M5 ^ 0xBE5466CFUL)); VE = SPH_ROTR32(VE ^ V3, 8); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 7);

	// Constants
	// 00 = 0x243F6A88UL 
	// 01 = 0x85A308D3UL 
	// 02 = 0x13198A2EUL 
	// 03 = 0x03707344UL 
	// 04 = 0xA4093822UL 
	// 05 = 0x299F31D0UL 
	// 06 = 0x082EFA98UL 
	// 07 = 0xEC4E6C89UL 
	// 08 = 0x452821E6UL 
	// 09 = 0x38D01377UL 
	// 10 = 0xBE5466CFUL 
	// 11 = 0x34E90C6CUL 
	// 12 = 0xC0AC29B7UL 
	// 13 = 0xC97C50DDUL 
	// 14 = 0x3F84D5B5UL
	// 15 = 0xB5470917UL 
	// A=10,B=11,C=12,D=13,E=14,F=15

	// Round 10
	// 10^2
	V0 = (V0 + V4 + (MA ^ 0x13198A2EUL)); VC = SPH_ROTR32(VC ^ V0, 16); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 12); V0 = (V0 + V4 + (M2 ^ 0xBE5466CFUL)); VC = SPH_ROTR32(VC ^ V0, 8); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 7);; 
	// 8^4
	V1 = (V1 + V5 + (M8 ^ 0xA4093822UL)); VD = SPH_ROTR32(VD ^ V1, 16); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 12); V1 = (V1 + V5 + (M4 ^ 0x452821E6UL)); VD = SPH_ROTR32(VD ^ V1, 8); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 7);; 
	// 7^6
	V2 = (V2 + V6 + (M7 ^ 0x082EFA98UL)); VE = SPH_ROTR32(VE ^ V2, 16); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 12); V2 = (V2 + V6 + (M6 ^ 0xEC4E6C89UL)); VE = SPH_ROTR32(VE ^ V2, 8); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 7);; 
	// 1^5
	V3 = (V3 + V7 + (M1 ^ 0x299F31D0UL)); VF = SPH_ROTR32(VF ^ V3, 16); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 12); V3 = (V3 + V7 + (M5 ^ 0x85A308D3UL)); VF = SPH_ROTR32(VF ^ V3, 8); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 7);; 
	// 15^11
	V0 = (V0 + V5 + (MF ^ 0x34E90C6CUL)); VF = SPH_ROTR32(VF ^ V0, 16); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 12); V0 = (V0 + V5 + (MB ^ 0xB5470917UL)); VF = SPH_ROTR32(VF ^ V0, 8); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 7);; 
	// 9^14
	V1 = (V1 + V6 + (M9 ^ 0x3F84D5B5UL)); VC = SPH_ROTR32(VC ^ V1, 16); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 12); V1 = (V1 + V6 + (ME ^ 0x38D01377UL)); VC = SPH_ROTR32(VC ^ V1, 8); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 7);; 
	// 3^12
	V2 = (V2 + V7 + (M3 ^ 0xC0AC29B7UL)); VD = SPH_ROTR32(VD ^ V2, 16); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 12); V2 = (V2 + V7 + (MC ^ 0x03707344UL)); VD = SPH_ROTR32(VD ^ V2, 8); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 7);; 
	// 13^0
	V3 = (V3 + V4 + (MD ^ 0x243F6A88UL)); VE = SPH_ROTR32(VE ^ V3, 16); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 12); V3 = (V3 + V4 + (M0 ^ 0xC97C50DDUL)); VE = SPH_ROTR32(VE ^ V3, 8); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 7);

	// Round 11,12,13,14 repeated from beginning again
	V0 = (V0 + V4 + (M0 ^ 0x85A308D3UL)); VC = SPH_ROTR32(VC ^ V0, 16); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 12); V0 = (V0 + V4 + (M1 ^ 0x243F6A88UL)); VC = SPH_ROTR32(VC ^ V0, 8); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 7);; V1 = (V1 + V5 + (M2 ^ 0x03707344UL)); VD = SPH_ROTR32(VD ^ V1, 16); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 12); V1 = (V1 + V5 + (M3 ^ 0x13198A2EUL)); VD = SPH_ROTR32(VD ^ V1, 8); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 7);; V2 = (V2 + V6 + (M4 ^ 0x299F31D0UL)); VE = SPH_ROTR32(VE ^ V2, 16); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 12); V2 = (V2 + V6 + (M5 ^ 0xA4093822UL)); VE = SPH_ROTR32(VE ^ V2, 8); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 7);; V3 = (V3 + V7 + (M6 ^ 0xEC4E6C89UL)); VF = SPH_ROTR32(VF ^ V3, 16); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 12); V3 = (V3 + V7 + (M7 ^ 0x082EFA98UL)); VF = SPH_ROTR32(VF ^ V3, 8); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 7);; V0 = (V0 + V5 + (M8 ^ 0x38D01377UL)); VF = SPH_ROTR32(VF ^ V0, 16); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 12); V0 = (V0 + V5 + (M9 ^ 0x452821E6UL)); VF = SPH_ROTR32(VF ^ V0, 8); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 7);; V1 = (V1 + V6 + (MA ^ 0x34E90C6CUL)); VC = SPH_ROTR32(VC ^ V1, 16); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 12); V1 = (V1 + V6 + (MB ^ 0xBE5466CFUL)); VC = SPH_ROTR32(VC ^ V1, 8); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 7);; V2 = (V2 + V7 + (MC ^ 0xC97C50DDUL)); VD = SPH_ROTR32(VD ^ V2, 16); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 12); V2 = (V2 + V7 + (MD ^ 0xC0AC29B7UL)); VD = SPH_ROTR32(VD ^ V2, 8); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 7);; V3 = (V3 + V4 + (ME ^ 0xB5470917UL)); VE = SPH_ROTR32(VE ^ V3, 16); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 12); V3 = (V3 + V4 + (MF ^ 0x3F84D5B5UL)); VE = SPH_ROTR32(VE ^ V3, 8); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 7);
	V0 = (V0 + V4 + (ME ^ 0xBE5466CFUL)); VC = SPH_ROTR32(VC ^ V0, 16); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 12); V0 = (V0 + V4 + (MA ^ 0x3F84D5B5UL)); VC = SPH_ROTR32(VC ^ V0, 8); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 7);; V1 = (V1 + V5 + (M4 ^ 0x452821E6UL)); VD = SPH_ROTR32(VD ^ V1, 16); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 12); V1 = (V1 + V5 + (M8 ^ 0xA4093822UL)); VD = SPH_ROTR32(VD ^ V1, 8); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 7);; V2 = (V2 + V6 + (M9 ^ 0xB5470917UL)); VE = SPH_ROTR32(VE ^ V2, 16); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 12); V2 = (V2 + V6 + (MF ^ 0x38D01377UL)); VE = SPH_ROTR32(VE ^ V2, 8); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 7);; V3 = (V3 + V7 + (MD ^ 0x082EFA98UL)); VF = SPH_ROTR32(VF ^ V3, 16); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 12); V3 = (V3 + V7 + (M6 ^ 0xC97C50DDUL)); VF = SPH_ROTR32(VF ^ V3, 8); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 7);; V0 = (V0 + V5 + (M1 ^ 0xC0AC29B7UL)); VF = SPH_ROTR32(VF ^ V0, 16); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 12); V0 = (V0 + V5 + (MC ^ 0x85A308D3UL)); VF = SPH_ROTR32(VF ^ V0, 8); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 7);; V1 = (V1 + V6 + (M0 ^ 0x13198A2EUL)); VC = SPH_ROTR32(VC ^ V1, 16); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 12); V1 = (V1 + V6 + (M2 ^ 0x243F6A88UL)); VC = SPH_ROTR32(VC ^ V1, 8); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 7);; V2 = (V2 + V7 + (MB ^ 0xEC4E6C89UL)); VD = SPH_ROTR32(VD ^ V2, 16); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 12); V2 = (V2 + V7 + (M7 ^ 0x34E90C6CUL)); VD = SPH_ROTR32(VD ^ V2, 8); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 7);; V3 = (V3 + V4 + (M5 ^ 0x03707344UL)); VE = SPH_ROTR32(VE ^ V3, 16); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 12); V3 = (V3 + V4 + (M3 ^ 0x299F31D0UL)); VE = SPH_ROTR32(VE ^ V3, 8); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 7);
	V0 = (V0 + V4 + (MB ^ 0x452821E6UL)); VC = SPH_ROTR32(VC ^ V0, 16); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 12); V0 = (V0 + V4 + (M8 ^ 0x34E90C6CUL)); VC = SPH_ROTR32(VC ^ V0, 8); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 7);; V1 = (V1 + V5 + (MC ^ 0x243F6A88UL)); VD = SPH_ROTR32(VD ^ V1, 16); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 12); V1 = (V1 + V5 + (M0 ^ 0xC0AC29B7UL)); VD = SPH_ROTR32(VD ^ V1, 8); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 7);; V2 = (V2 + V6 + (M5 ^ 0x13198A2EUL)); VE = SPH_ROTR32(VE ^ V2, 16); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 12); V2 = (V2 + V6 + (M2 ^ 0x299F31D0UL)); VE = SPH_ROTR32(VE ^ V2, 8); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 7);; V3 = (V3 + V7 + (MF ^ 0xC97C50DDUL)); VF = SPH_ROTR32(VF ^ V3, 16); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 12); V3 = (V3 + V7 + (MD ^ 0xB5470917UL)); VF = SPH_ROTR32(VF ^ V3, 8); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 7);; V0 = (V0 + V5 + (MA ^ 0x3F84D5B5UL)); VF = SPH_ROTR32(VF ^ V0, 16); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 12); V0 = (V0 + V5 + (ME ^ 0xBE5466CFUL)); VF = SPH_ROTR32(VF ^ V0, 8); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 7);; V1 = (V1 + V6 + (M3 ^ 0x082EFA98UL)); VC = SPH_ROTR32(VC ^ V1, 16); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 12); V1 = (V1 + V6 + (M6 ^ 0x03707344UL)); VC = SPH_ROTR32(VC ^ V1, 8); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 7);; V2 = (V2 + V7 + (M7 ^ 0x85A308D3UL)); VD = SPH_ROTR32(VD ^ V2, 16); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 12); V2 = (V2 + V7 + (M1 ^ 0xEC4E6C89UL)); VD = SPH_ROTR32(VD ^ V2, 8); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 7);; V3 = (V3 + V4 + (M9 ^ 0xA4093822UL)); VE = SPH_ROTR32(VE ^ V3, 16); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 12); V3 = (V3 + V4 + (M4 ^ 0x38D01377UL)); VE = SPH_ROTR32(VE ^ V3, 8); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 7);
	V0 = (V0 + V4 + (M7 ^ 0x38D01377UL)); VC = SPH_ROTR32(VC ^ V0, 16); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 12); V0 = (V0 + V4 + (M9 ^ 0xEC4E6C89UL)); VC = SPH_ROTR32(VC ^ V0, 8); V8 = (V8 + VC); V4 = SPH_ROTR32(V4 ^ V8, 7);; V1 = (V1 + V5 + (M3 ^ 0x85A308D3UL)); VD = SPH_ROTR32(VD ^ V1, 16); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 12); V1 = (V1 + V5 + (M1 ^ 0x03707344UL)); VD = SPH_ROTR32(VD ^ V1, 8); V9 = (V9 + VD); V5 = SPH_ROTR32(V5 ^ V9, 7);; V2 = (V2 + V6 + (MD ^ 0xC0AC29B7UL)); VE = SPH_ROTR32(VE ^ V2, 16); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 12); V2 = (V2 + V6 + (MC ^ 0xC97C50DDUL)); VE = SPH_ROTR32(VE ^ V2, 8); VA = (VA + VE); V6 = SPH_ROTR32(V6 ^ VA, 7);; V3 = (V3 + V7 + (MB ^ 0x3F84D5B5UL)); VF = SPH_ROTR32(VF ^ V3, 16); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 12); V3 = (V3 + V7 + (ME ^ 0x34E90C6CUL)); VF = SPH_ROTR32(VF ^ V3, 8); VB = (VB + VF); V7 = SPH_ROTR32(V7 ^ VB, 7);; V0 = (V0 + V5 + (M2 ^ 0x082EFA98UL)); VF = SPH_ROTR32(VF ^ V0, 16); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 12); V0 = (V0 + V5 + (M6 ^ 0x13198A2EUL)); VF = SPH_ROTR32(VF ^ V0, 8); VA = (VA + VF); V5 = SPH_ROTR32(V5 ^ VA, 7);; V1 = (V1 + V6 + (M5 ^ 0xBE5466CFUL)); VC = SPH_ROTR32(VC ^ V1, 16); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 12); V1 = (V1 + V6 + (MA ^ 0x299F31D0UL)); VC = SPH_ROTR32(VC ^ V1, 8); VB = (VB + VC); V6 = SPH_ROTR32(V6 ^ VB, 7);; V2 = (V2 + V7 + (M4 ^ 0x243F6A88UL)); VD = SPH_ROTR32(VD ^ V2, 16); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 12); V2 = (V2 + V7 + (M0 ^ 0xA4093822UL)); VD = SPH_ROTR32(VD ^ V2, 8); V8 = (V8 + VD); V7 = SPH_ROTR32(V7 ^ V8, 7);; V3 = (V3 + V4 + (MF ^ 0x452821E6UL)); VE = SPH_ROTR32(VE ^ V3, 16); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 12); V3 = (V3 + V4 + (M8 ^ 0xB5470917UL)); VE = SPH_ROTR32(VE ^ V3, 8); V9 = (V9 + VE); V4 = SPH_ROTR32(V4 ^ V9, 7);

	if(pre7 ^ V7 ^ VF)
		return;
	output[output[0xFF]++] = nonce;
}