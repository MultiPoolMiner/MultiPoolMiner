// OpenCL kernel to perform Skein hashes for SKC mining
//
// copyright 2013-2014 reorder
//

#define ROL32(x, n)  rotate(x, (uint) n)
#define SHR(x, n)    ((x) >> n)
#define SWAP32(a)    (as_uint(as_uchar4(a).wzyx))

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

inline uint sha256_res(uint16 data)
{
    uint temp1;
    uint W0 = SWAP32(data.s0);
    uint W1 = SWAP32(data.s1);
    uint W2 = SWAP32(data.s2);
    uint W3 = SWAP32(data.s3);
    uint W4 = SWAP32(data.s4);
    uint W5 = SWAP32(data.s5);
    uint W6 = SWAP32(data.s6);
    uint W7 = SWAP32(data.s7);
    uint W8 = SWAP32(data.s8);
    uint W9 = SWAP32(data.s9);
    uint W10 = SWAP32(data.sA);
    uint W11 = SWAP32(data.sB);
    uint W12 = SWAP32(data.sC);
    uint W13 = SWAP32(data.sD);
    uint W14 = SWAP32(data.sE);
    uint W15 = SWAP32(data.sF);

    uint v0 = 0x6A09E667;
    uint v1 = 0xBB67AE85;
    uint v2 = 0x3C6EF372;
    uint v3 = 0xA54FF53A;
    uint v4 = 0x510E527F;
    uint v5 = 0x9B05688C;
    uint v6 = 0x1F83D9AB;
    uint v7 = 0x5BE0CD19;

    P( v0, v1, v2, v3, v4, v5, v6, v7, W0, 0x428A2F98 );
    P( v7, v0, v1, v2, v3, v4, v5, v6, W1, 0x71374491 );
    P( v6, v7, v0, v1, v2, v3, v4, v5, W2, 0xB5C0FBCF );
    P( v5, v6, v7, v0, v1, v2, v3, v4, W3, 0xE9B5DBA5 );
    P( v4, v5, v6, v7, v0, v1, v2, v3, W4, 0x3956C25B );
    P( v3, v4, v5, v6, v7, v0, v1, v2, W5, 0x59F111F1 );
    P( v2, v3, v4, v5, v6, v7, v0, v1, W6, 0x923F82A4 );
    P( v1, v2, v3, v4, v5, v6, v7, v0, W7, 0xAB1C5ED5 );
    P( v0, v1, v2, v3, v4, v5, v6, v7, W8, 0xD807AA98 );
    P( v7, v0, v1, v2, v3, v4, v5, v6, W9, 0x12835B01 );
    P( v6, v7, v0, v1, v2, v3, v4, v5, W10, 0x243185BE );
    P( v5, v6, v7, v0, v1, v2, v3, v4, W11, 0x550C7DC3 );
    P( v4, v5, v6, v7, v0, v1, v2, v3, W12, 0x72BE5D74 );
    P( v3, v4, v5, v6, v7, v0, v1, v2, W13, 0x80DEB1FE );
    P( v2, v3, v4, v5, v6, v7, v0, v1, W14, 0x9BDC06A7 );
    P( v1, v2, v3, v4, v5, v6, v7, v0, W15, 0xC19BF174 );

    P( v0, v1, v2, v3, v4, v5, v6, v7, R0, 0xE49B69C1 );
    P( v7, v0, v1, v2, v3, v4, v5, v6, R1, 0xEFBE4786 );
    P( v6, v7, v0, v1, v2, v3, v4, v5, R2, 0x0FC19DC6 );
    P( v5, v6, v7, v0, v1, v2, v3, v4, R3, 0x240CA1CC );
    P( v4, v5, v6, v7, v0, v1, v2, v3, R4, 0x2DE92C6F );
    P( v3, v4, v5, v6, v7, v0, v1, v2, R5, 0x4A7484AA );
    P( v2, v3, v4, v5, v6, v7, v0, v1, R6, 0x5CB0A9DC );
    P( v1, v2, v3, v4, v5, v6, v7, v0, R7, 0x76F988DA );
    P( v0, v1, v2, v3, v4, v5, v6, v7, R8, 0x983E5152 );
    P( v7, v0, v1, v2, v3, v4, v5, v6, R9, 0xA831C66D );
    P( v6, v7, v0, v1, v2, v3, v4, v5, R10, 0xB00327C8 );
    P( v5, v6, v7, v0, v1, v2, v3, v4, R11, 0xBF597FC7 );
    P( v4, v5, v6, v7, v0, v1, v2, v3, R12, 0xC6E00BF3 );
    P( v3, v4, v5, v6, v7, v0, v1, v2, R13, 0xD5A79147 );
    P( v2, v3, v4, v5, v6, v7, v0, v1, R14, 0x06CA6351 );
    P( v1, v2, v3, v4, v5, v6, v7, v0, R15, 0x14292967 );

    P( v0, v1, v2, v3, v4, v5, v6, v7, R0,  0x27B70A85 );
    P( v7, v0, v1, v2, v3, v4, v5, v6, R1,  0x2E1B2138 );
    P( v6, v7, v0, v1, v2, v3, v4, v5, R2,  0x4D2C6DFC );
    P( v5, v6, v7, v0, v1, v2, v3, v4, R3,  0x53380D13 );
    P( v4, v5, v6, v7, v0, v1, v2, v3, R4,  0x650A7354 );
    P( v3, v4, v5, v6, v7, v0, v1, v2, R5,  0x766A0ABB );
    P( v2, v3, v4, v5, v6, v7, v0, v1, R6,  0x81C2C92E );
    P( v1, v2, v3, v4, v5, v6, v7, v0, R7,  0x92722C85 );
    P( v0, v1, v2, v3, v4, v5, v6, v7, R8,  0xA2BFE8A1 );
    P( v7, v0, v1, v2, v3, v4, v5, v6, R9,  0xA81A664B );
    P( v6, v7, v0, v1, v2, v3, v4, v5, R10, 0xC24B8B70 );
    P( v5, v6, v7, v0, v1, v2, v3, v4, R11, 0xC76C51A3 );
    P( v4, v5, v6, v7, v0, v1, v2, v3, R12, 0xD192E819 );
    P( v3, v4, v5, v6, v7, v0, v1, v2, R13, 0xD6990624 );
    P( v2, v3, v4, v5, v6, v7, v0, v1, R14, 0xF40E3585 );
    P( v1, v2, v3, v4, v5, v6, v7, v0, R15, 0x106AA070 );

    P( v0, v1, v2, v3, v4, v5, v6, v7, R0,  0x19A4C116 );
    P( v7, v0, v1, v2, v3, v4, v5, v6, R1,  0x1E376C08 );
    P( v6, v7, v0, v1, v2, v3, v4, v5, R2,  0x2748774C );
    P( v5, v6, v7, v0, v1, v2, v3, v4, R3,  0x34B0BCB5 );
    P( v4, v5, v6, v7, v0, v1, v2, v3, R4,  0x391C0CB3 );
    P( v3, v4, v5, v6, v7, v0, v1, v2, R5,  0x4ED8AA4A );
    P( v2, v3, v4, v5, v6, v7, v0, v1, R6,  0x5B9CCA4F );
    P( v1, v2, v3, v4, v5, v6, v7, v0, R7,  0x682E6FF3 );
    P( v0, v1, v2, v3, v4, v5, v6, v7, R8,  0x748F82EE );
    P( v7, v0, v1, v2, v3, v4, v5, v6, R9,  0x78A5636F );
    P( v6, v7, v0, v1, v2, v3, v4, v5, R10, 0x84C87814 );
    P( v5, v6, v7, v0, v1, v2, v3, v4, R11, 0x8CC70208 );
    P( v4, v5, v6, v7, v0, v1, v2, v3, R12, 0x90BEFFFA );
    P( v3, v4, v5, v6, v7, v0, v1, v2, R13, 0xA4506CEB );
    P( v2, v3, v4, v5, v6, v7, v0, v1, RD14, 0xBEF9A3F7 );
    P( v1, v2, v3, v4, v5, v6, v7, v0, RD15, 0xC67178F2 );

    v0 += 0x6A09E667;
    v1 += 0xBB67AE85;
    v2 += 0x3C6EF372;
    v3 += 0xA54FF53A;
    v4 += 0x510E527F;
    v5 += 0x9B05688C;
    v6 += 0x1F83D9AB;
    v7 += 0x5BE0CD19;
    uint s7 = v7;

    P( v0, v1, v2, v3, v4, v5, v6, v7, 0x80000000, 0x428A2F98 );
    P( v7, v0, v1, v2, v3, v4, v5, v6, 0, 0x71374491 );
    P( v6, v7, v0, v1, v2, v3, v4, v5, 0, 0xB5C0FBCF );
    P( v5, v6, v7, v0, v1, v2, v3, v4, 0, 0xE9B5DBA5 );
    P( v4, v5, v6, v7, v0, v1, v2, v3, 0, 0x3956C25B );
    P( v3, v4, v5, v6, v7, v0, v1, v2, 0, 0x59F111F1 );
    P( v2, v3, v4, v5, v6, v7, v0, v1, 0, 0x923F82A4 );
    P( v1, v2, v3, v4, v5, v6, v7, v0, 0, 0xAB1C5ED5 );
    P( v0, v1, v2, v3, v4, v5, v6, v7, 0, 0xD807AA98 );
    P( v7, v0, v1, v2, v3, v4, v5, v6, 0, 0x12835B01 );
    P( v6, v7, v0, v1, v2, v3, v4, v5, 0, 0x243185BE );
    P( v5, v6, v7, v0, v1, v2, v3, v4, 0, 0x550C7DC3 );
    P( v4, v5, v6, v7, v0, v1, v2, v3, 0, 0x72BE5D74 );
    P( v3, v4, v5, v6, v7, v0, v1, v2, 0, 0x80DEB1FE );
    P( v2, v3, v4, v5, v6, v7, v0, v1, 0, 0x9BDC06A7 );
    P( v1, v2, v3, v4, v5, v6, v7, v0, 512, 0xC19BF174 );

    P( v0, v1, v2, v3, v4, v5, v6, v7, 0x80000000U, 0xE49B69C1U );
    P( v7, v0, v1, v2, v3, v4, v5, v6, 0x01400000U, 0xEFBE4786U );
    P( v6, v7, v0, v1, v2, v3, v4, v5, 0x00205000U, 0x0FC19DC6U );
    P( v5, v6, v7, v0, v1, v2, v3, v4, 0x00005088U, 0x240CA1CCU );
    P( v4, v5, v6, v7, v0, v1, v2, v3, 0x22000800U, 0x2DE92C6FU );
    P( v3, v4, v5, v6, v7, v0, v1, v2, 0x22550014U, 0x4A7484AAU );
    P( v2, v3, v4, v5, v6, v7, v0, v1, 0x05089742U, 0x5CB0A9DCU );
    P( v1, v2, v3, v4, v5, v6, v7, v0, 0xa0000020U, 0x76F988DAU );
    P( v0, v1, v2, v3, v4, v5, v6, v7, 0x5a880000U, 0x983E5152U );
    P( v7, v0, v1, v2, v3, v4, v5, v6, 0x005c9400U, 0xA831C66DU );
    P( v6, v7, v0, v1, v2, v3, v4, v5, 0x0016d49dU, 0xB00327C8U );
    P( v5, v6, v7, v0, v1, v2, v3, v4, 0xfa801f00U, 0xBF597FC7U );
    P( v4, v5, v6, v7, v0, v1, v2, v3, 0xd33225d0U, 0xC6E00BF3U );
    P( v3, v4, v5, v6, v7, v0, v1, v2, 0x11675959U, 0xD5A79147U );
    P( v2, v3, v4, v5, v6, v7, v0, v1, 0xf6e6bfdaU, 0x06CA6351U );
    P( v1, v2, v3, v4, v5, v6, v7, v0, 0xb30c1549U, 0x14292967U );
    P( v0, v1, v2, v3, v4, v5, v6, v7, 0x08b2b050U, 0x27B70A85U );
    P( v7, v0, v1, v2, v3, v4, v5, v6, 0x9d7c4c27U, 0x2E1B2138U );
    P( v6, v7, v0, v1, v2, v3, v4, v5, 0x0ce2a393U, 0x4D2C6DFCU );
    P( v5, v6, v7, v0, v1, v2, v3, v4, 0x88e6e1eaU, 0x53380D13U );
    P( v4, v5, v6, v7, v0, v1, v2, v3, 0xa52b4335U, 0x650A7354U );
    P( v3, v4, v5, v6, v7, v0, v1, v2, 0x67a16f49U, 0x766A0ABBU );
    P( v2, v3, v4, v5, v6, v7, v0, v1, 0xd732016fU, 0x81C2C92EU );
    P( v1, v2, v3, v4, v5, v6, v7, v0, 0x4eeb2e91U, 0x92722C85U );
    P( v0, v1, v2, v3, v4, v5, v6, v7, 0x5dbf55e5U, 0xA2BFE8A1U );
    P( v7, v0, v1, v2, v3, v4, v5, v6, 0x8eee2335U, 0xA81A664BU );
    P( v6, v7, v0, v1, v2, v3, v4, v5, 0xe2bc5ec2U, 0xC24B8B70U );
    P( v5, v6, v7, v0, v1, v2, v3, v4, 0xa83f4394U, 0xC76C51A3U );
    P( v4, v5, v6, v7, v0, v1, v2, v3, 0x45ad78f7U, 0xD192E819U );
    P( v3, v4, v5, v6, v7, v0, v1, v2, 0x36f3d0cdU, 0xD6990624U );
    P( v2, v3, v4, v5, v6, v7, v0, v1, 0xd99c05e8U, 0xF40E3585U );
    P( v1, v2, v3, v4, v5, v6, v7, v0, 0xb0511dc7U, 0x106AA070U );
    P( v0, v1, v2, v3, v4, v5, v6, v7, 0x69bc7ac4U, 0x19A4C116U );
    P( v7, v0, v1, v2, v3, v4, v5, v6, 0xbd11375bU, 0x1E376C08U );
    P( v6, v7, v0, v1, v2, v3, v4, v5, 0xe3ba71e5U, 0x2748774CU );
    P( v5, v6, v7, v0, v1, v2, v3, v4, 0x3b209ff2U, 0x34B0BCB5U );
    P( v4, v5, v6, v7, v0, v1, v2, v3, 0x18feee17U, 0x391C0CB3U );
    P( v3, v4, v5, v6, v7, v0, v1, v2, 0xe25ad9e7U, 0x4ED8AA4AU );
    P( v2, v3, v4, v5, v6, v7, v0, v1, 0x13375046U, 0x5B9CCA4FU );
    P( v1, v2, v3, v4, v5, v6, v7, v0, 0x0515089dU, 0x682E6FF3U );
    P( v0, v1, v2, v3, v4, v5, v6, v7, 0x4f0d0f04U, 0x748F82EEU );
    P( v7, v0, v1, v2, v3, v4, v5, v6, 0x2627484eU, 0x78A5636FU );
    P( v6, v7, v0, v1, v2, v3, v4, v5, 0x310128d2U, 0x84C87814U );
    P( v5, v6, v7, v0, v1, v2, v3, v4, 0xc668b434U, 0x8CC70208U );
    PLAST( v4, v5, v6, v7, v0, v1, v2, v3, 0x420841ccU, 0x90BEFFFAU );

    return v7 + s7;
}

#if 1
#define rolhackl(n) \
inline ulong rol ## n  (ulong l) \
{ \
    uint2 t = rotate(as_uint2(l), (n)); \
    return as_ulong((uint2)(bitselect(t.s0, t.s1, (uint)(1 << (n)) - 1), bitselect(t.s0, t.s1, (uint)(~((1 << (n)) - 1))))); \
}

rolhackl(8)
rolhackl(9)
rolhackl(10)
rolhackl(13)
rolhackl(14)
rolhackl(17)
rolhackl(19)
rolhackl(22)
rolhackl(24)
rolhackl(25)
rolhackl(27)
rolhackl(29)
rolhackl(30)

#define rolhackr(n) \
inline ulong rol ## n  (ulong l) \
{ \
    uint2 t = rotate(as_uint2(l), (n - 32)); \
    return as_ulong((uint2)(bitselect(t.s1, t.s0, (uint)(1 << (n - 32)) - 1), bitselect(t.s1, t.s0, (uint)(~((1 << (n - 32)) - 1))))); \
}

rolhackr(33)
rolhackr(34)
rolhackr(35)
rolhackr(36)
rolhackr(37)
rolhackr(39)
rolhackr(42)
rolhackr(43)
rolhackr(44)
rolhackr(46)
rolhackr(49)
rolhackr(50)
rolhackr(54)
rolhackr(56)
#else
#define rol8(l) rotate(l, 8UL)
#define rol9(l) rotate(l, 9UL)
#define rol10(l) rotate(l, 10UL)
#define rol13(l) rotate(l, 13UL)
#define rol14(l) rotate(l, 14UL)
#define rol17(l) rotate(l, 17UL)
#define rol19(l) rotate(l, 19UL)
#define rol22(l) rotate(l, 22UL)
#define rol24(l) rotate(l, 24UL)
#define rol25(l) rotate(l, 25UL)
#define rol27(l) rotate(l, 27UL)
#define rol29(l) rotate(l, 29UL)
#define rol30(l) rotate(l, 30UL)
#define rol33(l) rotate(l, 33UL)
#define rol34(l) rotate(l, 34UL)
#define rol35(l) rotate(l, 35UL)
#define rol36(l) rotate(l, 36UL)
#define rol37(l) rotate(l, 37UL)
#define rol39(l) rotate(l, 39UL)
#define rol42(l) rotate(l, 42UL)
#define rol43(l) rotate(l, 43UL)
#define rol44(l) rotate(l, 44UL)
#define rol46(l) rotate(l, 46UL)
#define rol49(l) rotate(l, 49UL)
#define rol50(l) rotate(l, 50UL)
#define rol54(l) rotate(l, 54UL)
#define rol56(l) rotate(l, 56UL)
#endif

#define SKEIN_ROL_0_0(x) rol46(x)
#define SKEIN_ROL_0_1(x) rol36(x) 
#define SKEIN_ROL_0_2(x) rol19(x) 
#define SKEIN_ROL_0_3(x) rol37(x) 
#define SKEIN_ROL_1_0(x) rol33(x) 
#define SKEIN_ROL_1_1(x) rol27(x) 
#define SKEIN_ROL_1_2(x) rol14(x) 
#define SKEIN_ROL_1_3(x) rol42(x) 
#define SKEIN_ROL_2_0(x) rol17(x) 
#define SKEIN_ROL_2_1(x) rol49(x) 
#define SKEIN_ROL_2_2(x) rol36(x) 
#define SKEIN_ROL_2_3(x) rol39(x) 
#define SKEIN_ROL_3_0(x) rol44(x) 
#define SKEIN_ROL_3_1(x) rol9(x) 
#define SKEIN_ROL_3_2(x) rol54(x) 
#define SKEIN_ROL_3_3(x) rol56(x) 
#define SKEIN_ROL_4_0(x) rol39(x) 
#define SKEIN_ROL_4_1(x) rol30(x) 
#define SKEIN_ROL_4_2(x) rol34(x) 
#define SKEIN_ROL_4_3(x) rol24(x) 
#define SKEIN_ROL_5_0(x) rol13(x) 
#define SKEIN_ROL_5_1(x) rol50(x) 
#define SKEIN_ROL_5_2(x) rol10(x) 
#define SKEIN_ROL_5_3(x) rol17(x) 
#define SKEIN_ROL_6_0(x) rol25(x) 
#define SKEIN_ROL_6_1(x) rol29(x) 
#define SKEIN_ROL_6_2(x) rol39(x) 
#define SKEIN_ROL_6_3(x) rol43(x) 
#define SKEIN_ROL_7_0(x) rol8(x) 
#define SKEIN_ROL_7_1(x) rol35(x) 
#define SKEIN_ROL_7_2(x) rol56(x) 
#define SKEIN_ROL_7_3(x) rol22(x) 

#define SKEIN_KS_PARITY         0x1BD11BDAA9FC1A22UL

#define SKEIN_R512(X, p0, p1, p2, p3, p4, p5, p6, p7, ROTS) \
{ \
    X.s##p0 += X.s##p1; \
    X.s##p2 += X.s##p3; \
    X.s##p4 += X.s##p5; \
    X.s##p6 += X.s##p7; \
    X.s##p1 = SKEIN_ROL_ ## ROTS ## _0(X.s##p1) ^ X.s##p0; \
    X.s##p3 = SKEIN_ROL_ ## ROTS ## _1(X.s##p3) ^ X.s##p2; \
    X.s##p5 = SKEIN_ROL_ ## ROTS ## _2(X.s##p5) ^ X.s##p4; \
    X.s##p7 = SKEIN_ROL_ ## ROTS ## _3(X.s##p7) ^ X.s##p6; \
}

#define SKEIN_I512_0(X, ks, ts) \
    X.s0   += ks##1; \
    X.s1   += ks##2; \
    X.s2   += ks##3; \
    X.s3   += ks##4; \
    X.s4   += ks##5; \
    X.s5   += ks##6 + ts##1; \
    X.s6   += ks##7 + ts##2; \
    X.s7   += ks##8 + 1;

#define SKEIN_I512_1(X, ks, ts) \
    X.s0   += ks##2; \
    X.s1   += ks##3; \
    X.s2   += ks##4; \
    X.s3   += ks##5; \
    X.s4   += ks##6; \
    X.s5   += ks##7 + ts##2; \
    X.s6   += ks##8 + ts##0; \
    X.s7   += ks##0 + 2;

#define SKEIN_I512_2(X, ks, ts) \
    X.s0   += ks##3; \
    X.s1   += ks##4; \
    X.s2   += ks##5; \
    X.s3   += ks##6; \
    X.s4   += ks##7; \
    X.s5   += ks##8 + ts##0; \
    X.s6   += ks##0 + ts##1; \
    X.s7   += ks##1 + 3;

#define SKEIN_I512_3(X, ks, ts) \
    X.s0   += ks##4; \
    X.s1   += ks##5; \
    X.s2   += ks##6; \
    X.s3   += ks##7; \
    X.s4   += ks##8; \
    X.s5   += ks##0 + ts##1; \
    X.s6   += ks##1 + ts##2; \
    X.s7   += ks##2 + 4;

#define SKEIN_I512_4(X, ks, ts) \
    X.s0   += ks##5; \
    X.s1   += ks##6; \
    X.s2   += ks##7; \
    X.s3   += ks##8; \
    X.s4   += ks##0; \
    X.s5   += ks##1 + ts##2; \
    X.s6   += ks##2 + ts##0; \
    X.s7   += ks##3 + 5;

#define SKEIN_I512_5(X, ks, ts) \
    X.s0   += ks##6; \
    X.s1   += ks##7; \
    X.s2   += ks##8; \
    X.s3   += ks##0; \
    X.s4   += ks##1; \
    X.s5   += ks##2 + ts##0; \
    X.s6   += ks##3 + ts##1; \
    X.s7   += ks##4 + 6;

#define SKEIN_I512_6(X, ks, ts) \
    X.s0   += ks##7; \
    X.s1   += ks##8; \
    X.s2   += ks##0; \
    X.s3   += ks##1; \
    X.s4   += ks##2; \
    X.s5   += ks##3 + ts##1; \
    X.s6   += ks##4 + ts##2; \
    X.s7   += ks##5 + 7;

#define SKEIN_I512_7(X, ks, ts) \
    X.s0   += ks##8; \
    X.s1   += ks##0; \
    X.s2   += ks##1; \
    X.s3   += ks##2; \
    X.s4   += ks##3; \
    X.s5   += ks##4 + ts##2; \
    X.s6   += ks##5 + ts##0; \
    X.s7   += ks##6 + 8;

#define SKEIN_I512_8(X, ks, ts) \
    X.s0   += ks##0; \
    X.s1   += ks##1; \
    X.s2   += ks##2; \
    X.s3   += ks##3; \
    X.s4   += ks##4; \
    X.s5   += ks##5 + ts##0; \
    X.s6   += ks##6 + ts##1; \
    X.s7   += ks##7 + 9;

#define SKEIN_I512_9(X, ks, ts) \
    X.s0   += ks##1; \
    X.s1   += ks##2; \
    X.s2   += ks##3; \
    X.s3   += ks##4; \
    X.s4   += ks##5; \
    X.s5   += ks##6 + ts##1; \
    X.s6   += ks##7 + ts##2; \
    X.s7   += ks##8 + 10;

#define SKEIN_I512_10(X, ks, ts) \
    X.s0   += ks##2; \
    X.s1   += ks##3; \
    X.s2   += ks##4; \
    X.s3   += ks##5; \
    X.s4   += ks##6; \
    X.s5   += ks##7 + ts##2; \
    X.s6   += ks##8 + ts##0; \
    X.s7   += ks##0 + 11;

#define SKEIN_I512_11(X, ks, ts) \
    X.s0   += ks##3; \
    X.s1   += ks##4; \
    X.s2   += ks##5; \
    X.s3   += ks##6; \
    X.s4   += ks##7; \
    X.s5   += ks##8 + ts##0; \
    X.s6   += ks##0 + ts##1; \
    X.s7   += ks##1 + 12;

#define SKEIN_I512_12(X, ks, ts) \
    X.s0   += ks##4; \
    X.s1   += ks##5; \
    X.s2   += ks##6; \
    X.s3   += ks##7; \
    X.s4   += ks##8; \
    X.s5   += ks##0 + ts##1; \
    X.s6   += ks##1 + ts##2; \
    X.s7   += ks##2 + 13;

#define SKEIN_I512_13(X, ks, ts) \
    X.s0   += ks##5; \
    X.s1   += ks##6; \
    X.s2   += ks##7; \
    X.s3   += ks##8; \
    X.s4   += ks##0; \
    X.s5   += ks##1 + ts##2; \
    X.s6   += ks##2 + ts##0; \
    X.s7   += ks##3 + 14;

#define SKEIN_I512_14(X, ks, ts) \
    X.s0   += ks##6; \
    X.s1   += ks##7; \
    X.s2   += ks##8; \
    X.s3   += ks##0; \
    X.s4   += ks##1; \
    X.s5   += ks##2 + ts##0; \
    X.s6   += ks##3 + ts##1; \
    X.s7   += ks##4 + 15;

#define SKEIN_I512_15(X, ks, ts) \
    X.s0   += ks##7; \
    X.s1   += ks##8; \
    X.s2   += ks##0; \
    X.s3   += ks##1; \
    X.s4   += ks##2; \
    X.s5   += ks##3 + ts##1; \
    X.s6   += ks##4 + ts##2; \
    X.s7   += ks##5 + 16;

#define SKEIN_I512_16(X, ks, ts) \
    X.s0   += ks##8; \
    X.s1   += ks##0; \
    X.s2   += ks##1; \
    X.s3   += ks##2; \
    X.s4   += ks##3; \
    X.s5   += ks##4 + ts##2; \
    X.s6   += ks##5 + ts##0; \
    X.s7   += ks##6 + 17;

#define SKEIN_I512_17(X, ks, ts) \
    X.s0   += ks##0; \
    X.s1   += ks##1; \
    X.s2   += ks##2; \
    X.s3   += ks##3; \
    X.s4   += ks##4; \
    X.s5   += ks##5 + ts##0; \
    X.s6   += ks##6 + ts##1; \
    X.s7   += ks##7 + 18;

#define SKEIN_R512_8_halfround_0(X) \
        SKEIN_R512(X, 0,1,2,3,4,5,6,7, 0);   \
        SKEIN_R512(X, 2,1,4,7,6,5,0,3, 1);   \
        SKEIN_R512(X, 4,1,6,3,0,5,2,7, 2);   \
        SKEIN_R512(X, 6,1,0,7,2,5,4,3, 3);

#define SKEIN_R512_8_halfround_1(X) \
        SKEIN_R512(X, 0,1,2,3,4,5,6,7, 4);   \
        SKEIN_R512(X, 2,1,4,7,6,5,0,3, 5);   \
        SKEIN_R512(X, 4,1,6,3,0,5,2,7, 6);   \
        SKEIN_R512(X, 6,1,0,7,2,5,4,3, 7);

#define SKEIN_R512_8_rounds(X, ks, ts) \
    SKEIN_R512_8_halfround_0(X); \
    SKEIN_I512_0(X, ks, ts); \
    SKEIN_R512_8_halfround_1(X); \
    SKEIN_I512_1(X, ks, ts); \
    SKEIN_R512_8_halfround_0(X); \
    SKEIN_I512_2(X, ks, ts); \
    SKEIN_R512_8_halfround_1(X); \
    SKEIN_I512_3(X, ks, ts); \
    SKEIN_R512_8_halfround_0(X); \
    SKEIN_I512_4(X, ks, ts); \
    SKEIN_R512_8_halfround_1(X); \
    SKEIN_I512_5(X, ks, ts); \
    SKEIN_R512_8_halfround_0(X); \
    SKEIN_I512_6(X, ks, ts); \
    SKEIN_R512_8_halfround_1(X); \
    SKEIN_I512_7(X, ks, ts); \
    SKEIN_R512_8_halfround_0(X); \
    SKEIN_I512_8(X, ks, ts); \
    SKEIN_R512_8_halfround_1(X); \
    SKEIN_I512_9(X, ks, ts); \
    SKEIN_R512_8_halfround_0(X); \
    SKEIN_I512_10(X, ks, ts); \
    SKEIN_R512_8_halfround_1(X); \
    SKEIN_I512_11(X, ks, ts); \
    SKEIN_R512_8_halfround_0(X); \
    SKEIN_I512_12(X, ks, ts); \
    SKEIN_R512_8_halfround_1(X); \
    SKEIN_I512_13(X, ks, ts); \
    SKEIN_R512_8_halfround_0(X); \
    SKEIN_I512_14(X, ks, ts); \
    SKEIN_R512_8_halfround_1(X); \
    SKEIN_I512_15(X, ks, ts); \
    SKEIN_R512_8_halfround_0(X); \
    SKEIN_I512_16(X, ks, ts); \
    SKEIN_R512_8_halfround_1(X); \
    SKEIN_I512_17(X, ks, ts);

inline ulong8 skein512_mid_impl(ulong8 X, ulong2 msg)
{
    ulong ts0, ts1, ts2;
    ulong ks0 = X.s0, ks1 = X.s1, ks2 = X.s2, ks3 = X.s3,
          ks4 = X.s4, ks5 = X.s5, ks6 = X.s6, ks7 = X.s7;
    ulong ks8 = ks0 ^ ks1 ^ ks2 ^ ks3 ^ ks4 ^ ks5 ^ ks6 ^ ks7 ^ SKEIN_KS_PARITY;

    X.s01 += msg;

    ts0 = 80;
    ts1 = 176UL << 56;
    ts2 = 0xB000000000000050UL;

    X.s5 += 80;
    X.s6 += 176UL << 56;

    SKEIN_R512_8_rounds(X, ks, ts);

    X.s01 ^= msg;
    ks0 = X.s0; ks1 = X.s1; ks2 = X.s2; ks3 = X.s3;
    ks4 = X.s4; ks5 = X.s5; ks6 = X.s6; ks7 = X.s7;
    ks8 = ks0 ^ ks1 ^ ks2 ^ ks3 ^ ks4 ^ ks5 ^ ks6 ^ ks7 ^ SKEIN_KS_PARITY;

    ts0 = 8UL;
    ts1 = 255UL << 56;
    ts2 = 0xFF00000000000008UL;

    X.s5 += 8UL;
    X.s6 += 255UL << 56;

    SKEIN_R512_8_rounds(X, ks, ts);

    return X;
}

#define FOUND (0xFF)
#define SETFOUND(Xnonce) output[output[FOUND]++] = Xnonce

__kernel void search(const ulong state0, const ulong state1, const ulong state2, const ulong state3,
                     const ulong state4, const ulong state5, const ulong state6, const ulong state7,
                     const uint data16, const uint data17, const uint data18,
                     __global volatile uint* output)
{
    uint nonce = get_global_id(0);
    ulong8 state = (ulong8)(state0, state1, state2, state3, state4, state5, state6, state7);

    ulong2 msg = as_ulong2((uint4)(data16, data17, data18, SWAP32(nonce)));

    if(sha256_res(as_uint16(skein512_mid_impl(state, msg))) /*& 0xf0ffffff */  & 0xc0ffffff)
        return;
    SETFOUND(nonce);
}
