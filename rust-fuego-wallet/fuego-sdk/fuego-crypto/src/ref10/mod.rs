//! Faithful port of the vendored ref10 ed25519 arithmetic from
//! `src/crypto/crypto-ops.c` (Fuego daemon). Every function mirrors the C
//! implementation exactly; byte-for-byte equivalence is enforced by
//! cross-language golden vectors in `tests/ref10_vectors.rs`.
//!
//! This module is deliberately low-level: `fe` limbs are plain `i32`s and all
//! carry chains are translated 1:1 from the C source so the port stays
//! auditable against the daemon.

// The C code declares all temporaries up front and mutates them; the port
// keeps that structure. Mutable-but-once-written bindings are intentional.
#![allow(unused_mut)]

mod tables;

pub use tables::{Precomp, GE_BASE, GE_BI};

// ---------------------------------------------------------------- field ops

pub type Fe = [i32; 10];

pub const FE_MA: [u8; 32] = [
    0xe7, 0x92, 0xf8, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
    0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
    0xff, 0x7f,
];
pub const FE_MA2: [u8; 32] = [
    0xc9, 0xe3, 0x3d, 0xdb, 0xc8, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
    0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
    0xff, 0x7f,
];
pub const FE_FFFB1: [u8; 32] = [
    0xee, 0x41, 0x1c, 0x32, 0x75, 0x69, 0xa7, 0x22, 0x8d, 0x73, 0x2a, 0xb9, 0xa8, 0x04, 0x94,
    0xd1, 0xe3, 0x19, 0xfb, 0x41, 0x37, 0xc5, 0xa9, 0x20, 0x17, 0x1b, 0xd6, 0xda, 0xef, 0xfb,
    0x71, 0x7e,
];
pub const FE_FFFB2: [u8; 32] = [
    0xe0, 0x9a, 0x7c, 0x60, 0x83, 0x64, 0xde, 0xd2, 0xdf, 0xf7, 0x56, 0x04, 0x46, 0x03, 0xde,
    0x51, 0xbe, 0x5f, 0x16, 0xc0, 0xb7, 0x51, 0xd4, 0x91, 0xf6, 0x2c, 0x5a, 0x04, 0x0a, 0x1e,
    0x06, 0x4d,
];
pub const FE_FFFB3: [u8; 32] = [
    0x66, 0x2c, 0x30, 0x17, 0x87, 0x7d, 0x1b, 0x58, 0x29, 0x42, 0x96, 0xa5, 0x4e, 0xff, 0x24,
    0x40, 0xed, 0xa2, 0x0d, 0x3f, 0x40, 0x46, 0x95, 0xb8, 0xef, 0x08, 0xc2, 0x14, 0x0d, 0x11,
    0x4a, 0x67,
];
pub const FE_FFFB4: [u8; 32] = [
    0x86, 0x91, 0xb3, 0xb6, 0x03, 0x19, 0x3d, 0x85, 0x49, 0x4a, 0x3f, 0xa1, 0x08, 0xfc, 0x46,
    0xee, 0x2e, 0x43, 0xf7, 0x7e, 0x88, 0xf4, 0xc0, 0x26, 0xf9, 0xdb, 0x67, 0x10, 0x03, 0xf3,
    0x43, 0x1a,
];
pub const FE_SQRTM1: [u8; 32] = [
    0xb0, 0xa0, 0x0e, 0x4a, 0x27, 0x1b, 0xee, 0xc4, 0x78, 0xe4, 0x2f, 0xad, 0x06, 0x18, 0x43,
    0x2f, 0xa7, 0xd7, 0xfb, 0x3d, 0x99, 0x00, 0x4d, 0x2b, 0x0b, 0xdf, 0xc1, 0x4f, 0x80, 0x24,
    0x83, 0x2b,
];
pub const FE_D: [u8; 32] = [
    0xa3, 0x78, 0x59, 0x13, 0xca, 0x4d, 0xeb, 0x75, 0xab, 0xd8, 0x41, 0x41, 0x4d, 0x0a, 0x70,
    0x00, 0x98, 0xe8, 0x79, 0x77, 0x79, 0x40, 0xc7, 0x8c, 0x73, 0xfe, 0x6f, 0x2b, 0xee, 0x6c,
    0x03, 0x52,
];
pub const FE_D2: [u8; 32] = [
    0x59, 0xf1, 0xb2, 0x26, 0x94, 0x9b, 0xd6, 0xeb, 0x56, 0xb1, 0x83, 0x82, 0x9a, 0x14, 0xe0,
    0x00, 0x30, 0xd1, 0xf3, 0xee, 0xf2, 0x80, 0x8e, 0x19, 0xe7, 0xfc, 0xdf, 0x56, 0xdc, 0xd9,
    0x06, 0x24,
];

pub fn fe_0(h: &mut Fe) {
    *h = [0; 10];
}

pub fn fe_1(h: &mut Fe) {
    let mut r = [0; 10];
    r[0] = 1;
    *h = r;
}

pub fn fe_copy(h: &mut Fe, f: Fe) {
    *h = f;
}

pub fn fe_cmov(f: &mut Fe, g: Fe, b: u32) {
    debug_assert!(b <= 1);
    let f0 = f[0];
    let f1 = f[1];
    let f2 = f[2];
    let f3 = f[3];
    let f4 = f[4];
    let f5 = f[5];
    let f6 = f[6];
    let f7 = f[7];
    let f8 = f[8];
    let f9 = f[9];
    let g0 = g[0];
    let g1 = g[1];
    let g2 = g[2];
    let g3 = g[3];
    let g4 = g[4];
    let g5 = g[5];
    let g6 = g[6];
    let g7 = g[7];
    let g8 = g[8];
    let g9 = g[9];
    let x0 = f0 ^ g0;
    let x1 = f1 ^ g1;
    let x2 = f2 ^ g2;
    let x3 = f3 ^ g3;
    let x4 = f4 ^ g4;
    let x5 = f5 ^ g5;
    let x6 = f6 ^ g6;
    let x7 = f7 ^ g7;
    let x8 = f8 ^ g8;
    let x9 = f9 ^ g9;
    let b = 0u32.wrapping_sub(b) as i32;
    f[0] = f0 ^ (x0 & b);
    f[1] = f1 ^ (x1 & b);
    f[2] = f2 ^ (x2 & b);
    f[3] = f3 ^ (x3 & b);
    f[4] = f4 ^ (x4 & b);
    f[5] = f5 ^ (x5 & b);
    f[6] = f6 ^ (x6 & b);
    f[7] = f7 ^ (x7 & b);
    f[8] = f8 ^ (x8 & b);
    f[9] = f9 ^ (x9 & b);
}

pub fn fe_neg(h: &mut Fe, f: Fe) {
    let f0 = f[0];
    let f1 = f[1];
    let f2 = f[2];
    let f3 = f[3];
    let f4 = f[4];
    let f5 = f[5];
    let f6 = f[6];
    let f7 = f[7];
    let f8 = f[8];
    let f9 = f[9];
    *h = [-f0, -f1, -f2, -f3, -f4, -f5, -f6, -f7, -f8, -f9];
}

pub fn fe_add(h: &mut Fe, f: Fe, g: Fe) {
    let f0 = f[0];
    let f1 = f[1];
    let f2 = f[2];
    let f3 = f[3];
    let f4 = f[4];
    let f5 = f[5];
    let f6 = f[6];
    let f7 = f[7];
    let f8 = f[8];
    let f9 = f[9];
    let g0 = g[0];
    let g1 = g[1];
    let g2 = g[2];
    let g3 = g[3];
    let g4 = g[4];
    let g5 = g[5];
    let g6 = g[6];
    let g7 = g[7];
    let g8 = g[8];
    let g9 = g[9];
    *h = [
        f0 + g0,
        f1 + g1,
        f2 + g2,
        f3 + g3,
        f4 + g4,
        f5 + g5,
        f6 + g6,
        f7 + g7,
        f8 + g8,
        f9 + g9,
    ];
}

pub fn fe_sub(h: &mut Fe, f: Fe, g: Fe) {
    let f0 = f[0];
    let f1 = f[1];
    let f2 = f[2];
    let f3 = f[3];
    let f4 = f[4];
    let f5 = f[5];
    let f6 = f[6];
    let f7 = f[7];
    let f8 = f[8];
    let f9 = f[9];
    let g0 = g[0];
    let g1 = g[1];
    let g2 = g[2];
    let g3 = g[3];
    let g4 = g[4];
    let g5 = g[5];
    let g6 = g[6];
    let g7 = g[7];
    let g8 = g[8];
    let g9 = g[9];
    *h = [
        f0 - g0,
        f1 - g1,
        f2 - g2,
        f3 - g3,
        f4 - g4,
        f5 - g5,
        f6 - g6,
        f7 - g7,
        f8 - g8,
        f9 - g9,
    ];
}

fn load_3(inp: &[u8]) -> u64 {
    let mut result = inp[0] as u64;
    result |= (inp[1] as u64) << 8;
    result |= (inp[2] as u64) << 16;
    result
}

fn load_4(inp: &[u8]) -> u64 {
    let mut result = inp[0] as u64;
    result |= (inp[1] as u64) << 8;
    result |= (inp[2] as u64) << 16;
    result |= (inp[3] as u64) << 24;
    result
}

/// fe_frombytes, inlined from ge_frombytes_vartime / ge_fromfe_frombytes_vartime.
pub fn fe_frombytes(h: &mut Fe, s: &[u8; 32]) {
    let mut h0 = load_4(s) as i64;
    let mut h1 = (load_3(&s[4..]) << 6) as i64;
    let mut h2 = (load_3(&s[7..]) << 5) as i64;
    let mut h3 = (load_3(&s[10..]) << 3) as i64;
    let mut h4 = (load_3(&s[13..]) << 2) as i64;
    let mut h5 = load_4(&s[16..]) as i64;
    let mut h6 = (load_3(&s[20..]) << 7) as i64;
    let mut h7 = (load_3(&s[23..]) << 5) as i64;
    let mut h8 = (load_3(&s[26..]) << 4) as i64;
    let mut h9 = (load_3(&s[29..]) << 2) as i64;
    let carry9 = (h9 + (1 << 24)) >> 25;
    h0 += carry9 * 19;
    h9 -= carry9 << 25;
    let carry1 = (h1 + (1 << 24)) >> 25;
    h2 += carry1;
    h1 -= carry1 << 25;
    let carry3 = (h3 + (1 << 24)) >> 25;
    h4 += carry3;
    h3 -= carry3 << 25;
    let carry5 = (h5 + (1 << 24)) >> 25;
    h6 += carry5;
    h5 -= carry5 << 25;
    let carry7 = (h7 + (1 << 24)) >> 25;
    h8 += carry7;
    h7 -= carry7 << 25;
    let carry0 = (h0 + (1 << 25)) >> 26;
    h1 += carry0;
    h0 -= carry0 << 26;
    let carry2 = (h2 + (1 << 25)) >> 26;
    h3 += carry2;
    h2 -= carry2 << 26;
    let carry4 = (h4 + (1 << 25)) >> 26;
    h5 += carry4;
    h4 -= carry4 << 26;
    let carry6 = (h6 + (1 << 25)) >> 26;
    h7 += carry6;
    h6 -= carry6 << 26;
    let carry8 = (h8 + (1 << 25)) >> 26;
    h9 += carry8;
    h8 -= carry8 << 26;
    *h = [
        h0 as i32, h1 as i32, h2 as i32, h3 as i32, h4 as i32, h5 as i32, h6 as i32, h7 as i32,
        h8 as i32, h9 as i32,
    ];
}

pub fn fe_tobytes(s: &mut [u8; 32], h: Fe) {
    let mut h0 = h[0] as i32;
    let mut h1 = h[1] as i32;
    let mut h2 = h[2] as i32;
    let mut h3 = h[3] as i32;
    let mut h4 = h[4] as i32;
    let mut h5 = h[5] as i32;
    let mut h6 = h[6] as i32;
    let mut h7 = h[7] as i32;
    let mut h8 = h[8] as i32;
    let mut h9 = h[9] as i32;
    let mut q: i32;

    q = (19 * h9 + (1 << 24)) >> 25;
    q = (h0 + q) >> 26;
    q = (h1 + q) >> 25;
    q = (h2 + q) >> 26;
    q = (h3 + q) >> 25;
    q = (h4 + q) >> 26;
    q = (h5 + q) >> 25;
    q = (h6 + q) >> 26;
    q = (h7 + q) >> 25;
    q = (h8 + q) >> 26;
    q = (h9 + q) >> 25;

    h0 += 19 * q;

    let carry0 = h0 >> 26;
    h1 += carry0;
    h0 -= carry0 << 26;
    let carry1 = h1 >> 25;
    h2 += carry1;
    h1 -= carry1 << 25;
    let carry2 = h2 >> 26;
    h3 += carry2;
    h2 -= carry2 << 26;
    let carry3 = h3 >> 25;
    h4 += carry3;
    h3 -= carry3 << 25;
    let carry4 = h4 >> 26;
    h5 += carry4;
    h4 -= carry4 << 26;
    let carry5 = h5 >> 25;
    h6 += carry5;
    h5 -= carry5 << 25;
    let carry6 = h6 >> 26;
    h7 += carry6;
    h6 -= carry6 << 26;
    let carry7 = h7 >> 25;
    h8 += carry7;
    h7 -= carry7 << 25;
    let carry8 = h8 >> 26;
    h9 += carry8;
    h8 -= carry8 << 26;
    let carry9 = h9 >> 25;
    h9 -= carry9 << 25;

    *s = [
        (h0 >> 0) as u8,
        (h0 >> 8) as u8,
        (h0 >> 16) as u8,
        ((h0 >> 24) | (h1 << 2)) as u8,
        (h1 >> 6) as u8,
        (h1 >> 14) as u8,
        ((h1 >> 22) | (h2 << 3)) as u8,
        (h2 >> 5) as u8,
        (h2 >> 13) as u8,
        ((h2 >> 21) | (h3 << 5)) as u8,
        (h3 >> 3) as u8,
        (h3 >> 11) as u8,
        ((h3 >> 19) | (h4 << 6)) as u8,
        (h4 >> 2) as u8,
        (h4 >> 10) as u8,
        (h4 >> 18) as u8,
        (h5 >> 0) as u8,
        (h5 >> 8) as u8,
        (h5 >> 16) as u8,
        ((h5 >> 24) | (h6 << 1)) as u8,
        (h6 >> 7) as u8,
        (h6 >> 15) as u8,
        ((h6 >> 23) | (h7 << 3)) as u8,
        (h7 >> 5) as u8,
        (h7 >> 13) as u8,
        ((h7 >> 21) | (h8 << 4)) as u8,
        (h8 >> 4) as u8,
        (h8 >> 12) as u8,
        ((h8 >> 20) | (h9 << 6)) as u8,
        (h9 >> 2) as u8,
        (h9 >> 10) as u8,
        (h9 >> 18) as u8,
    ];
}

pub fn fe_isnonzero(f: Fe) -> bool {
    let mut s = [0u8; 32];
    fe_tobytes(&mut s, f);
    let mut x = 0i32;
    for b in s.iter() {
        x |= *b as i32;
    }
    (((x - 1) >> 8) + 1) != 0
}

pub fn fe_isnegative(f: Fe) -> bool {
    let mut s = [0u8; 32];
    fe_tobytes(&mut s, f);
    (s[0] & 1) != 0
}

pub fn fe_invert(out: &mut Fe, z: Fe) {
    let mut t0 = [0i32; 10];
    let mut t1 = [0i32; 10];
    let mut t2 = [0i32; 10];
    let mut t3 = [0i32; 10];

    fe_sq(&mut t0, z);
    fe_sq(&mut t1, t0);
    {{ let _t = t1; fe_sq(&mut t1, _t); }};
    {{ let _t = t1; fe_mul(&mut t1, z, _t); }};
    {{ let _t = t0; fe_mul(&mut t0, _t, t1); }};
    fe_sq(&mut t2, t0);
    {{ let _t = t1; fe_mul(&mut t1, _t, t2); }};
    fe_sq(&mut t2, t1);
    for _ in 0..4 {
        {{ let _t = t2; fe_sq(&mut t2, _t); }};
    }
    {{ let _t = t1; fe_mul(&mut t1, t2, _t); }};
    fe_sq(&mut t2, t1);
    for _ in 0..9 {
        {{ let _t = t2; fe_sq(&mut t2, _t); }};
    }
    {{ let _t = t2; fe_mul(&mut t2, _t, t1); }};
    fe_sq(&mut t3, t2);
    for _ in 0..19 {
        {{ let _t = t3; fe_sq(&mut t3, _t); }};
    }
    {{ let _t = t2; fe_mul(&mut t2, t3, _t); }};
    {{ let _t = t2; fe_sq(&mut t2, _t); }};
    for _ in 0..9 {
        {{ let _t = t2; fe_sq(&mut t2, _t); }};
    }
    {{ let _t = t1; fe_mul(&mut t1, t2, _t); }};
    fe_sq(&mut t2, t1);
    for _ in 0..49 {
        {{ let _t = t2; fe_sq(&mut t2, _t); }};
    }
    {{ let _t = t2; fe_mul(&mut t2, _t, t1); }};
    fe_sq(&mut t3, t2);
    for _ in 0..99 {
        {{ let _t = t3; fe_sq(&mut t3, _t); }};
    }
    {{ let _t = t2; fe_mul(&mut t2, t3, _t); }};
    {{ let _t = t2; fe_sq(&mut t2, _t); }};
    for _ in 0..49 {
        {{ let _t = t2; fe_sq(&mut t2, _t); }};
    }
    {{ let _t = t1; fe_mul(&mut t1, t2, _t); }};
    {{ let _t = t1; fe_sq(&mut t1, _t); }};
    for _ in 0..4 {
        {{ let _t = t1; fe_sq(&mut t1, _t); }};
    }
    fe_mul(out, t1, t0);
}

/// r = u^(m+1) * v^(-(m+1))  == (u/v)^((p+3)/8), exact addition chain from C.
pub fn fe_divpowm1(r: &mut Fe, u: Fe, v: Fe) {
    let mut v3 = [0i32; 10];
    let mut uv7 = [0i32; 10];
    let mut t0 = [0i32; 10];
    let mut t1 = [0i32; 10];
    let mut t2 = [0i32; 10];

    fe_sq(&mut v3, v);
    {{ let _t = v3; fe_mul(&mut v3, _t, v); }}; // v3 = v^3
    fe_sq(&mut uv7, v3);
    {{ let _t = uv7; fe_mul(&mut uv7, _t, v); }};
    {{ let _t = uv7; fe_mul(&mut uv7, _t, u); }}; // uv7 = u*v^7

    fe_sq(&mut t0, uv7);
    fe_sq(&mut t1, t0);
    {{ let _t = t1; fe_sq(&mut t1, _t); }};
    {{ let _t = t1; fe_mul(&mut t1, uv7, _t); }};
    {{ let _t = t0; fe_mul(&mut t0, _t, t1); }};
    {{ let _t = t0; fe_sq(&mut t0, _t); }};
    {{ let _t = t0; fe_mul(&mut t0, t1, _t); }};
    fe_sq(&mut t1, t0);
    for _ in 0..4 {
        {{ let _t = t1; fe_sq(&mut t1, _t); }};
    }
    {{ let _t = t0; fe_mul(&mut t0, t1, _t); }};
    fe_sq(&mut t1, t0);
    for _ in 0..9 {
        {{ let _t = t1; fe_sq(&mut t1, _t); }};
    }
    {{ let _t = t1; fe_mul(&mut t1, _t, t0); }};
    fe_sq(&mut t2, t1);
    for _ in 0..19 {
        {{ let _t = t2; fe_sq(&mut t2, _t); }};
    }
    {{ let _t = t1; fe_mul(&mut t1, t2, _t); }};
    for _ in 0..10 {
        {{ let _t = t1; fe_sq(&mut t1, _t); }};
    }
    {{ let _t = t0; fe_mul(&mut t0, t1, _t); }};
    fe_sq(&mut t1, t0);
    for _ in 0..49 {
        {{ let _t = t1; fe_sq(&mut t1, _t); }};
    }
    {{ let _t = t1; fe_mul(&mut t1, _t, t0); }};
    fe_sq(&mut t2, t1);
    for _ in 0..99 {
        {{ let _t = t2; fe_sq(&mut t2, _t); }};
    }
    {{ let _t = t1; fe_mul(&mut t1, t2, _t); }};
    for _ in 0..50 {
        {{ let _t = t1; fe_sq(&mut t1, _t); }};
    }
    {{ let _t = t0; fe_mul(&mut t0, t1, _t); }};
    {{ let _t = t0; fe_sq(&mut t0, _t); }};
    {{ let _t = t0; fe_sq(&mut t0, _t); }};
    {{ let _t = t0; fe_mul(&mut t0, _t, uv7); }};

    {{ let _t = t0; fe_mul(&mut t0, _t, v3); }};
    fe_mul(r, t0, u);
}

pub fn fe_mul(h: &mut Fe, f: Fe, g: Fe) {
    let f0 = f[0];
    let f1 = f[1];
    let f2 = f[2];
    let f3 = f[3];
    let f4 = f[4];
    let f5 = f[5];
    let f6 = f[6];
    let f7 = f[7];
    let f8 = f[8];
    let f9 = f[9];
    let g0 = g[0];
    let g1 = g[1];
    let g2 = g[2];
    let g3 = g[3];
    let g4 = g[4];
    let g5 = g[5];
    let g6 = g[6];
    let g7 = g[7];
    let g8 = g[8];
    let g9 = g[9];
    let g1_19 = 19 * g1;
    let g2_19 = 19 * g2;
    let g3_19 = 19 * g3;
    let g4_19 = 19 * g4;
    let g5_19 = 19 * g5;
    let g6_19 = 19 * g6;
    let g7_19 = 19 * g7;
    let g8_19 = 19 * g8;
    let g9_19 = 19 * g9;
    let f1_2 = 2 * f1;
    let f3_2 = 2 * f3;
    let f5_2 = 2 * f5;
    let f7_2 = 2 * f7;
    let f9_2 = 2 * f9;
    let f0g0 = f0 as i64 * g0 as i64;
    let f0g1 = f0 as i64 * g1 as i64;
    let f0g2 = f0 as i64 * g2 as i64;
    let f0g3 = f0 as i64 * g3 as i64;
    let f0g4 = f0 as i64 * g4 as i64;
    let f0g5 = f0 as i64 * g5 as i64;
    let f0g6 = f0 as i64 * g6 as i64;
    let f0g7 = f0 as i64 * g7 as i64;
    let f0g8 = f0 as i64 * g8 as i64;
    let f0g9 = f0 as i64 * g9 as i64;
    let f1g0 = f1 as i64 * g0 as i64;
    let f1g1_2 = f1_2 as i64 * g1 as i64;
    let f1g2 = f1 as i64 * g2 as i64;
    let f1g3_2 = f1_2 as i64 * g3 as i64;
    let f1g4 = f1 as i64 * g4 as i64;
    let f1g5_2 = f1_2 as i64 * g5 as i64;
    let f1g6 = f1 as i64 * g6 as i64;
    let f1g7_2 = f1_2 as i64 * g7 as i64;
    let f1g8 = f1 as i64 * g8 as i64;
    let f1g9_38 = f1_2 as i64 * g9_19 as i64;
    let f2g0 = f2 as i64 * g0 as i64;
    let f2g1 = f2 as i64 * g1 as i64;
    let f2g2 = f2 as i64 * g2 as i64;
    let f2g3 = f2 as i64 * g3 as i64;
    let f2g4 = f2 as i64 * g4 as i64;
    let f2g5 = f2 as i64 * g5 as i64;
    let f2g6 = f2 as i64 * g6 as i64;
    let f2g7 = f2 as i64 * g7 as i64;
    let f2g8_19 = f2 as i64 * g8_19 as i64;
    let f2g9_19 = f2 as i64 * g9_19 as i64;
    let f3g0 = f3 as i64 * g0 as i64;
    let f3g1_2 = f3_2 as i64 * g1 as i64;
    let f3g2 = f3 as i64 * g2 as i64;
    let f3g3_2 = f3_2 as i64 * g3 as i64;
    let f3g4 = f3 as i64 * g4 as i64;
    let f3g5_2 = f3_2 as i64 * g5 as i64;
    let f3g6 = f3 as i64 * g6 as i64;
    let f3g7_38 = f3_2 as i64 * g7_19 as i64;
    let f3g8_19 = f3 as i64 * g8_19 as i64;
    let f3g9_38 = f3_2 as i64 * g9_19 as i64;
    let f4g0 = f4 as i64 * g0 as i64;
    let f4g1 = f4 as i64 * g1 as i64;
    let f4g2 = f4 as i64 * g2 as i64;
    let f4g3 = f4 as i64 * g3 as i64;
    let f4g4 = f4 as i64 * g4 as i64;
    let f4g5 = f4 as i64 * g5 as i64;
    let f4g6_19 = f4 as i64 * g6_19 as i64;
    let f4g7_19 = f4 as i64 * g7_19 as i64;
    let f4g8_19 = f4 as i64 * g8_19 as i64;
    let f4g9_19 = f4 as i64 * g9_19 as i64;
    let f5g0 = f5 as i64 * g0 as i64;
    let f5g1_2 = f5_2 as i64 * g1 as i64;
    let f5g2 = f5 as i64 * g2 as i64;
    let f5g3_2 = f5_2 as i64 * g3 as i64;
    let f5g4 = f5 as i64 * g4 as i64;
    let f5g5_38 = f5_2 as i64 * g5_19 as i64;
    let f5g6_19 = f5 as i64 * g6_19 as i64;
    let f5g7_38 = f5_2 as i64 * g7_19 as i64;
    let f5g8_19 = f5 as i64 * g8_19 as i64;
    let f5g9_38 = f5_2 as i64 * g9_19 as i64;
    let f6g0 = f6 as i64 * g0 as i64;
    let f6g1 = f6 as i64 * g1 as i64;
    let f6g2 = f6 as i64 * g2 as i64;
    let f6g3 = f6 as i64 * g3 as i64;
    let f6g4_19 = f6 as i64 * g4_19 as i64;
    let f6g5_19 = f6 as i64 * g5_19 as i64;
    let f6g6_19 = f6 as i64 * g6_19 as i64;
    let f6g7_19 = f6 as i64 * g7_19 as i64;
    let f6g8_19 = f6 as i64 * g8_19 as i64;
    let f6g9_19 = f6 as i64 * g9_19 as i64;
    let f7g0 = f7 as i64 * g0 as i64;
    let f7g1_2 = f7_2 as i64 * g1 as i64;
    let f7g2 = f7 as i64 * g2 as i64;
    let f7g3_38 = f7_2 as i64 * g3_19 as i64;
    let f7g4_19 = f7 as i64 * g4_19 as i64;
    let f7g5_38 = f7_2 as i64 * g5_19 as i64;
    let f7g6_19 = f7 as i64 * g6_19 as i64;
    let f7g7_38 = f7_2 as i64 * g7_19 as i64;
    let f7g8_19 = f7 as i64 * g8_19 as i64;
    let f7g9_38 = f7_2 as i64 * g9_19 as i64;
    let f8g0 = f8 as i64 * g0 as i64;
    let f8g1 = f8 as i64 * g1 as i64;
    let f8g2_19 = f8 as i64 * g2_19 as i64;
    let f8g3_19 = f8 as i64 * g3_19 as i64;
    let f8g4_19 = f8 as i64 * g4_19 as i64;
    let f8g5_19 = f8 as i64 * g5_19 as i64;
    let f8g6_19 = f8 as i64 * g6_19 as i64;
    let f8g7_19 = f8 as i64 * g7_19 as i64;
    let f8g8_19 = f8 as i64 * g8_19 as i64;
    let f8g9_19 = f8 as i64 * g9_19 as i64;
    let f9g0 = f9 as i64 * g0 as i64;
    let f9g1_38 = f9_2 as i64 * g1_19 as i64;
    let f9g2_19 = f9 as i64 * g2_19 as i64;
    let f9g3_38 = f9_2 as i64 * g3_19 as i64;
    let f9g4_19 = f9 as i64 * g4_19 as i64;
    let f9g5_38 = f9_2 as i64 * g5_19 as i64;
    let f9g6_19 = f9 as i64 * g6_19 as i64;
    let f9g7_38 = f9_2 as i64 * g7_19 as i64;
    let f9g8_19 = f9 as i64 * g8_19 as i64;
    let f9g9_38 = f9_2 as i64 * g9_19 as i64;
    let mut h0 = f0g0 + f1g9_38 + f2g8_19 + f3g7_38 + f4g6_19 + f5g5_38 + f6g4_19 + f7g3_38 + f8g2_19 + f9g1_38;
    let mut h1 = f0g1 + f1g0 + f2g9_19 + f3g8_19 + f4g7_19 + f5g6_19 + f6g5_19 + f7g4_19 + f8g3_19 + f9g2_19;
    let mut h2 = f0g2 + f1g1_2 + f2g0 + f3g9_38 + f4g8_19 + f5g7_38 + f6g6_19 + f7g5_38 + f8g4_19 + f9g3_38;
    let mut h3 = f0g3 + f1g2 + f2g1 + f3g0 + f4g9_19 + f5g8_19 + f6g7_19 + f7g6_19 + f8g5_19 + f9g4_19;
    let mut h4 = f0g4 + f1g3_2 + f2g2 + f3g1_2 + f4g0 + f5g9_38 + f6g8_19 + f7g7_38 + f8g6_19 + f9g5_38;
    let mut h5 = f0g5 + f1g4 + f2g3 + f3g2 + f4g1 + f5g0 + f6g9_19 + f7g8_19 + f8g7_19 + f9g6_19;
    let mut h6 = f0g6 + f1g5_2 + f2g4 + f3g3_2 + f4g2 + f5g1_2 + f6g0 + f7g9_38 + f8g8_19 + f9g7_38;
    let mut h7 = f0g7 + f1g6 + f2g5 + f3g4 + f4g3 + f5g2 + f6g1 + f7g0 + f8g9_19 + f9g8_19;
    let mut h8 = f0g8 + f1g7_2 + f2g6 + f3g5_2 + f4g4 + f5g3_2 + f6g2 + f7g1_2 + f8g0 + f9g9_38;
    let mut h9 = f0g9 + f1g8 + f2g7 + f3g6 + f4g5 + f5g4 + f6g3 + f7g2 + f8g1 + f9g0;

    let carry0 = (h0 + (1 << 25)) >> 26;
    h1 += carry0;
    h0 -= carry0 << 26;
    let carry4 = (h4 + (1 << 25)) >> 26;
    h5 += carry4;
    h4 -= carry4 << 26;

    let carry1 = (h1 + (1 << 24)) >> 25;
    h2 += carry1;
    h1 -= carry1 << 25;
    let carry5 = (h5 + (1 << 24)) >> 25;
    h6 += carry5;
    h5 -= carry5 << 25;

    let carry2 = (h2 + (1 << 25)) >> 26;
    h3 += carry2;
    h2 -= carry2 << 26;
    let carry6 = (h6 + (1 << 25)) >> 26;
    h7 += carry6;
    h6 -= carry6 << 26;

    let carry3 = (h3 + (1 << 24)) >> 25;
    h4 += carry3;
    h3 -= carry3 << 25;
    let carry7 = (h7 + (1 << 24)) >> 25;
    h8 += carry7;
    h7 -= carry7 << 25;

    let carry4 = (h4 + (1 << 25)) >> 26;
    h5 += carry4;
    h4 -= carry4 << 26;
    let carry8 = (h8 + (1 << 25)) >> 26;
    h9 += carry8;
    h8 -= carry8 << 26;

    let carry9 = (h9 + (1 << 24)) >> 25;
    h0 += carry9 * 19;
    h9 -= carry9 << 25;

    let carry0 = (h0 + (1 << 25)) >> 26;
    h1 += carry0;
    h0 -= carry0 << 26;

    *h = [
        h0 as i32, h1 as i32, h2 as i32, h3 as i32, h4 as i32, h5 as i32, h6 as i32, h7 as i32,
        h8 as i32, h9 as i32,
    ];
}

pub fn fe_sq(h: &mut Fe, f: Fe) {
    let f0 = f[0];
    let f1 = f[1];
    let f2 = f[2];
    let f3 = f[3];
    let f4 = f[4];
    let f5 = f[5];
    let f6 = f[6];
    let f7 = f[7];
    let f8 = f[8];
    let f9 = f[9];
    let f0_2 = 2 * f0;
    let f1_2 = 2 * f1;
    let f2_2 = 2 * f2;
    let f3_2 = 2 * f3;
    let f4_2 = 2 * f4;
    let f5_2 = 2 * f5;
    let f6_2 = 2 * f6;
    let f7_2 = 2 * f7;
    let f5_38 = 38 * f5;
    let f6_19 = 19 * f6;
    let f7_38 = 38 * f7;
    let f8_19 = 19 * f8;
    let f9_38 = 38 * f9;
    let f0f0 = f0 as i64 * f0 as i64;
    let f0f1_2 = f0_2 as i64 * f1 as i64;
    let f0f2_2 = f0_2 as i64 * f2 as i64;
    let f0f3_2 = f0_2 as i64 * f3 as i64;
    let f0f4_2 = f0_2 as i64 * f4 as i64;
    let f0f5_2 = f0_2 as i64 * f5 as i64;
    let f0f6_2 = f0_2 as i64 * f6 as i64;
    let f0f7_2 = f0_2 as i64 * f7 as i64;
    let f0f8_2 = f0_2 as i64 * f8 as i64;
    let f0f9_2 = f0_2 as i64 * f9 as i64;
    let f1f1_2 = f1_2 as i64 * f1 as i64;
    let f1f2_2 = f1_2 as i64 * f2 as i64;
    let f1f3_4 = f1_2 as i64 * f3_2 as i64;
    let f1f4_2 = f1_2 as i64 * f4 as i64;
    let f1f5_4 = f1_2 as i64 * f5_2 as i64;
    let f1f6_2 = f1_2 as i64 * f6 as i64;
    let f1f7_4 = f1_2 as i64 * f7_2 as i64;
    let f1f8_2 = f1_2 as i64 * f8 as i64;
    let f1f9_76 = f1_2 as i64 * f9_38 as i64;
    let f2f2 = f2 as i64 * f2 as i64;
    let f2f3_2 = f2_2 as i64 * f3 as i64;
    let f2f4_2 = f2_2 as i64 * f4 as i64;
    let f2f5_2 = f2_2 as i64 * f5 as i64;
    let f2f6_2 = f2_2 as i64 * f6 as i64;
    let f2f7_2 = f2_2 as i64 * f7 as i64;
    let f2f8_38 = f2_2 as i64 * f8_19 as i64;
    let f2f9_38 = f2 as i64 * f9_38 as i64;
    let f3f3_2 = f3_2 as i64 * f3 as i64;
    let f3f4_2 = f3_2 as i64 * f4 as i64;
    let f3f5_4 = f3_2 as i64 * f5_2 as i64;
    let f3f6_2 = f3_2 as i64 * f6 as i64;
    let f3f7_76 = f3_2 as i64 * f7_38 as i64;
    let f3f8_38 = f3_2 as i64 * f8_19 as i64;
    let f3f9_76 = f3_2 as i64 * f9_38 as i64;
    let f4f4 = f4 as i64 * f4 as i64;
    let f4f5_2 = f4_2 as i64 * f5 as i64;
    let f4f6_38 = f4_2 as i64 * f6_19 as i64;
    let f4f7_38 = f4 as i64 * f7_38 as i64;
    let f4f8_38 = f4_2 as i64 * f8_19 as i64;
    let f4f9_38 = f4 as i64 * f9_38 as i64;
    let f5f5_38 = f5 as i64 * f5_38 as i64;
    let f5f6_38 = f5_2 as i64 * f6_19 as i64;
    let f5f7_76 = f5_2 as i64 * f7_38 as i64;
    let f5f8_38 = f5_2 as i64 * f8_19 as i64;
    let f5f9_76 = f5_2 as i64 * f9_38 as i64;
    let f6f6_19 = f6 as i64 * f6_19 as i64;
    let f6f7_38 = f6 as i64 * f7_38 as i64;
    let f6f8_38 = f6_2 as i64 * f8_19 as i64;
    let f6f9_38 = f6 as i64 * f9_38 as i64;
    let f7f7_38 = f7 as i64 * f7_38 as i64;
    let f7f8_38 = f7_2 as i64 * f8_19 as i64;
    let f7f9_76 = f7_2 as i64 * f9_38 as i64;
    let f8f8_19 = f8 as i64 * f8_19 as i64;
    let f8f9_38 = f8 as i64 * f9_38 as i64;
    let f9f9_38 = f9 as i64 * f9_38 as i64;
    let mut h0 = f0f0 + f1f9_76 + f2f8_38 + f3f7_76 + f4f6_38 + f5f5_38;
    let mut h1 = f0f1_2 + f2f9_38 + f3f8_38 + f4f7_38 + f5f6_38;
    let mut h2 = f0f2_2 + f1f1_2 + f3f9_76 + f4f8_38 + f5f7_76 + f6f6_19;
    let mut h3 = f0f3_2 + f1f2_2 + f4f9_38 + f5f8_38 + f6f7_38;
    let mut h4 = f0f4_2 + f1f3_4 + f2f2 + f5f9_76 + f6f8_38 + f7f7_38;
    let mut h5 = f0f5_2 + f1f4_2 + f2f3_2 + f6f9_38 + f7f8_38;
    let mut h6 = f0f6_2 + f1f5_4 + f2f4_2 + f3f3_2 + f7f9_76 + f8f8_19;
    let mut h7 = f0f7_2 + f1f6_2 + f2f5_2 + f3f4_2 + f8f9_38;
    let mut h8 = f0f8_2 + f1f7_4 + f2f6_2 + f3f5_4 + f4f4 + f9f9_38;
    let mut h9 = f0f9_2 + f1f8_2 + f2f7_2 + f3f6_2 + f4f5_2;

    let carry0 = (h0 + (1 << 25)) >> 26;
    h1 += carry0;
    h0 -= carry0 << 26;
    let carry4 = (h4 + (1 << 25)) >> 26;
    h5 += carry4;
    h4 -= carry4 << 26;

    let carry1 = (h1 + (1 << 24)) >> 25;
    h2 += carry1;
    h1 -= carry1 << 25;
    let carry5 = (h5 + (1 << 24)) >> 25;
    h6 += carry5;
    h5 -= carry5 << 25;

    let carry2 = (h2 + (1 << 25)) >> 26;
    h3 += carry2;
    h2 -= carry2 << 26;
    let carry6 = (h6 + (1 << 25)) >> 26;
    h7 += carry6;
    h6 -= carry6 << 26;

    let carry3 = (h3 + (1 << 24)) >> 25;
    h4 += carry3;
    h3 -= carry3 << 25;
    let carry7 = (h7 + (1 << 24)) >> 25;
    h8 += carry7;
    h7 -= carry7 << 25;

    let carry4 = (h4 + (1 << 25)) >> 26;
    h5 += carry4;
    h4 -= carry4 << 26;
    let carry8 = (h8 + (1 << 25)) >> 26;
    h9 += carry8;
    h8 -= carry8 << 26;

    let carry9 = (h9 + (1 << 24)) >> 25;
    h0 += carry9 * 19;
    h9 -= carry9 << 25;

    let carry0 = (h0 + (1 << 25)) >> 26;
    h1 += carry0;
    h0 -= carry0 << 26;

    *h = [
        h0 as i32, h1 as i32, h2 as i32, h3 as i32, h4 as i32, h5 as i32, h6 as i32, h7 as i32,
        h8 as i32, h9 as i32,
    ];
}

pub fn fe_sq2(h: &mut Fe, f: Fe) {
    let f0 = f[0];
    let f1 = f[1];
    let f2 = f[2];
    let f3 = f[3];
    let f4 = f[4];
    let f5 = f[5];
    let f6 = f[6];
    let f7 = f[7];
    let f8 = f[8];
    let f9 = f[9];
    let f0_2 = 2 * f0;
    let f1_2 = 2 * f1;
    let f2_2 = 2 * f2;
    let f3_2 = 2 * f3;
    let f4_2 = 2 * f4;
    let f5_2 = 2 * f5;
    let f6_2 = 2 * f6;
    let f7_2 = 2 * f7;
    let f5_38 = 38 * f5;
    let f6_19 = 19 * f6;
    let f7_38 = 38 * f7;
    let f8_19 = 19 * f8;
    let f9_38 = 38 * f9;
    let f0f0 = f0 as i64 * f0 as i64;
    let f0f1_2 = f0_2 as i64 * f1 as i64;
    let f0f2_2 = f0_2 as i64 * f2 as i64;
    let f0f3_2 = f0_2 as i64 * f3 as i64;
    let f0f4_2 = f0_2 as i64 * f4 as i64;
    let f0f5_2 = f0_2 as i64 * f5 as i64;
    let f0f6_2 = f0_2 as i64 * f6 as i64;
    let f0f7_2 = f0_2 as i64 * f7 as i64;
    let f0f8_2 = f0_2 as i64 * f8 as i64;
    let f0f9_2 = f0_2 as i64 * f9 as i64;
    let f1f1_2 = f1_2 as i64 * f1 as i64;
    let f1f2_2 = f1_2 as i64 * f2 as i64;
    let f1f3_4 = f1_2 as i64 * f3_2 as i64;
    let f1f4_2 = f1_2 as i64 * f4 as i64;
    let f1f5_4 = f1_2 as i64 * f5_2 as i64;
    let f1f6_2 = f1_2 as i64 * f6 as i64;
    let f1f7_4 = f1_2 as i64 * f7_2 as i64;
    let f1f8_2 = f1_2 as i64 * f8 as i64;
    let f1f9_76 = f1_2 as i64 * f9_38 as i64;
    let f2f2 = f2 as i64 * f2 as i64;
    let f2f3_2 = f2_2 as i64 * f3 as i64;
    let f2f4_2 = f2_2 as i64 * f4 as i64;
    let f2f5_2 = f2_2 as i64 * f5 as i64;
    let f2f6_2 = f2_2 as i64 * f6 as i64;
    let f2f7_2 = f2_2 as i64 * f7 as i64;
    let f2f8_38 = f2_2 as i64 * f8_19 as i64;
    let f2f9_38 = f2 as i64 * f9_38 as i64;
    let f3f3_2 = f3_2 as i64 * f3 as i64;
    let f3f4_2 = f3_2 as i64 * f4 as i64;
    let f3f5_4 = f3_2 as i64 * f5_2 as i64;
    let f3f6_2 = f3_2 as i64 * f6 as i64;
    let f3f7_76 = f3_2 as i64 * f7_38 as i64;
    let f3f8_38 = f3_2 as i64 * f8_19 as i64;
    let f3f9_76 = f3_2 as i64 * f9_38 as i64;
    let f4f4 = f4 as i64 * f4 as i64;
    let f4f5_2 = f4_2 as i64 * f5 as i64;
    let f4f6_38 = f4_2 as i64 * f6_19 as i64;
    let f4f7_38 = f4 as i64 * f7_38 as i64;
    let f4f8_38 = f4_2 as i64 * f8_19 as i64;
    let f4f9_38 = f4 as i64 * f9_38 as i64;
    let f5f5_38 = f5 as i64 * f5_38 as i64;
    let f5f6_38 = f5_2 as i64 * f6_19 as i64;
    let f5f7_76 = f5_2 as i64 * f7_38 as i64;
    let f5f8_38 = f5_2 as i64 * f8_19 as i64;
    let f5f9_76 = f5_2 as i64 * f9_38 as i64;
    let f6f6_19 = f6 as i64 * f6_19 as i64;
    let f6f7_38 = f6 as i64 * f7_38 as i64;
    let f6f8_38 = f6_2 as i64 * f8_19 as i64;
    let f6f9_38 = f6 as i64 * f9_38 as i64;
    let f7f7_38 = f7 as i64 * f7_38 as i64;
    let f7f8_38 = f7_2 as i64 * f8_19 as i64;
    let f7f9_76 = f7_2 as i64 * f9_38 as i64;
    let f8f8_19 = f8 as i64 * f8_19 as i64;
    let f8f9_38 = f8 as i64 * f9_38 as i64;
    let f9f9_38 = f9 as i64 * f9_38 as i64;
    let mut h0 = f0f0 + f1f9_76 + f2f8_38 + f3f7_76 + f4f6_38 + f5f5_38;
    let mut h1 = f0f1_2 + f2f9_38 + f3f8_38 + f4f7_38 + f5f6_38;
    let mut h2 = f0f2_2 + f1f1_2 + f3f9_76 + f4f8_38 + f5f7_76 + f6f6_19;
    let mut h3 = f0f3_2 + f1f2_2 + f4f9_38 + f5f8_38 + f6f7_38;
    let mut h4 = f0f4_2 + f1f3_4 + f2f2 + f5f9_76 + f6f8_38 + f7f7_38;
    let mut h5 = f0f5_2 + f1f4_2 + f2f3_2 + f6f9_38 + f7f8_38;
    let mut h6 = f0f6_2 + f1f5_4 + f2f4_2 + f3f3_2 + f7f9_76 + f8f8_19;
    let mut h7 = f0f7_2 + f1f6_2 + f2f5_2 + f3f4_2 + f8f9_38;
    let mut h8 = f0f8_2 + f1f7_4 + f2f6_2 + f3f5_4 + f4f4 + f9f9_38;
    let mut h9 = f0f9_2 + f1f8_2 + f2f7_2 + f3f6_2 + f4f5_2;

    h0 += h0;
    h1 += h1;
    h2 += h2;
    h3 += h3;
    h4 += h4;
    h5 += h5;
    h6 += h6;
    h7 += h7;
    h8 += h8;
    h9 += h9;

    let carry0 = (h0 + (1 << 25)) >> 26;
    h1 += carry0;
    h0 -= carry0 << 26;
    let carry4 = (h4 + (1 << 25)) >> 26;
    h5 += carry4;
    h4 -= carry4 << 26;

    let carry1 = (h1 + (1 << 24)) >> 25;
    h2 += carry1;
    h1 -= carry1 << 25;
    let carry5 = (h5 + (1 << 24)) >> 25;
    h6 += carry5;
    h5 -= carry5 << 25;

    let carry2 = (h2 + (1 << 25)) >> 26;
    h3 += carry2;
    h2 -= carry2 << 26;
    let carry6 = (h6 + (1 << 25)) >> 26;
    h7 += carry6;
    h6 -= carry6 << 26;

    let carry3 = (h3 + (1 << 24)) >> 25;
    h4 += carry3;
    h3 -= carry3 << 25;
    let carry7 = (h7 + (1 << 24)) >> 25;
    h8 += carry7;
    h7 -= carry7 << 25;

    let carry4 = (h4 + (1 << 25)) >> 26;
    h5 += carry4;
    h4 -= carry4 << 26;
    let carry8 = (h8 + (1 << 25)) >> 26;
    h9 += carry8;
    h8 -= carry8 << 26;

    let carry9 = (h9 + (1 << 24)) >> 25;
    h0 += carry9 * 19;
    h9 -= carry9 << 25;

    let carry0 = (h0 + (1 << 25)) >> 26;
    h1 += carry0;
    h0 -= carry0 << 26;

    *h = [
        h0 as i32, h1 as i32, h2 as i32, h3 as i32, h4 as i32, h5 as i32, h6 as i32, h7 as i32,
        h8 as i32, h9 as i32,
    ];
}

// ---------------------------------------------------------------- group ops

#[derive(Clone, Copy, Default)]
pub struct GeP2 {
    pub x: Fe,
    pub y: Fe,
    pub z: Fe,
}

#[derive(Clone, Copy, Default)]
pub struct GeP3 {
    pub x: Fe,
    pub y: Fe,
    pub z: Fe,
    pub t: Fe,
}

#[derive(Clone, Copy, Default)]
pub struct GeP1P1 {
    pub x: Fe,
    pub y: Fe,
    pub z: Fe,
    pub t: Fe,
}

#[derive(Clone, Copy, Default)]
pub struct GeCached {
    pub yplus_x: Fe,
    pub yminus_x: Fe,
    pub z: Fe,
    pub t2d: Fe,
}

pub type GeDsmp = [GeCached; 8];

pub fn ge_p3_to_cached(r: &mut GeCached, p: &GeP3) {
    let mut t = [0i32; 10];
    fe_add(&mut r.yplus_x, p.y, p.x);
    fe_sub(&mut r.yminus_x, p.y, p.x);
    r.z = p.z;
    fe_frombytes(&mut t, &FE_D2);
    fe_mul(&mut r.t2d, p.t, t);
}

pub fn ge_add(r: &mut GeP1P1, p: &GeP3, q: &GeCached) {
    let mut t0 = [0i32; 10];
    fe_add(&mut r.x, p.y, p.x);
    fe_sub(&mut r.y, p.y, p.x);
    fe_mul(&mut r.z, r.x, q.yplus_x);
    {{ let _t = r.y; fe_mul(&mut r.y, _t, q.yminus_x); }};
    fe_mul(&mut r.t, q.t2d, p.t);
    fe_mul(&mut r.x, p.z, q.z);
    fe_add(&mut t0, r.x, r.x);
    fe_sub(&mut r.x, r.z, r.y);
    {{ let _t = r.y; fe_add(&mut r.y, r.z, _t); }};
    fe_add(&mut r.z, t0, r.t);
    {{ let _t = r.t; fe_sub(&mut r.t, t0, _t); }};
}

pub fn ge_sub(r: &mut GeP1P1, p: &GeP3, q: &GeCached) {
    let mut t0 = [0i32; 10];
    fe_add(&mut r.x, p.y, p.x);
    fe_sub(&mut r.y, p.y, p.x);
    fe_mul(&mut r.z, r.x, q.yminus_x);
    {{ let _t = r.y; fe_mul(&mut r.y, _t, q.yplus_x); }};
    fe_mul(&mut r.t, q.t2d, p.t);
    fe_mul(&mut r.x, p.z, q.z);
    fe_add(&mut t0, r.x, r.x);
    fe_sub(&mut r.x, r.z, r.y);
    {{ let _t = r.y; fe_add(&mut r.y, r.z, _t); }};
    fe_sub(&mut r.z, t0, r.t);
    {{ let _t = r.t; fe_add(&mut r.t, t0, _t); }};
}

fn ge_madd(r: &mut GeP1P1, p: &GeP3, q: &Precomp) {
    let mut t0 = [0i32; 10];
    fe_add(&mut r.x, p.y, p.x);
    fe_sub(&mut r.y, p.y, p.x);
    fe_mul(&mut r.z, r.x, q.yplusx);
    {{ let _t = r.y; fe_mul(&mut r.y, _t, q.yminusx); }};
    fe_mul(&mut r.t, q.xy2d, p.t);
    fe_add(&mut t0, p.z, p.z);
    fe_sub(&mut r.x, r.z, r.y);
    {{ let _t = r.y; fe_add(&mut r.y, r.z, _t); }};
    fe_add(&mut r.z, t0, r.t);
    {{ let _t = r.t; fe_sub(&mut r.t, t0, _t); }};
}

fn ge_msub(r: &mut GeP1P1, p: &GeP3, q: &Precomp) {
    let mut t0 = [0i32; 10];
    fe_add(&mut r.x, p.y, p.x);
    fe_sub(&mut r.y, p.y, p.x);
    fe_mul(&mut r.z, r.x, q.yminusx);
    {{ let _t = r.y; fe_mul(&mut r.y, _t, q.yplusx); }};
    fe_mul(&mut r.t, q.xy2d, p.t);
    fe_add(&mut t0, p.z, p.z);
    fe_sub(&mut r.x, r.z, r.y);
    {{ let _t = r.y; fe_add(&mut r.y, r.z, _t); }};
    fe_sub(&mut r.z, t0, r.t);
    {{ let _t = r.t; fe_add(&mut r.t, t0, _t); }};
}

pub fn ge_p1p1_to_p2(r: &mut GeP2, p: &GeP1P1) {
    fe_mul(&mut r.x, p.x, p.t);
    fe_mul(&mut r.y, p.y, p.z);
    fe_mul(&mut r.z, p.z, p.t);
}

pub fn ge_p1p1_to_p3(r: &mut GeP3, p: &GeP1P1) {
    fe_mul(&mut r.x, p.x, p.t);
    fe_mul(&mut r.y, p.y, p.z);
    fe_mul(&mut r.z, p.z, p.t);
    fe_mul(&mut r.t, p.x, p.y);
}

pub fn ge_p2_0(h: &mut GeP2) {
    fe_0(&mut h.x);
    fe_1(&mut h.y);
    fe_1(&mut h.z);
}

pub fn ge_p2_dbl(r: &mut GeP1P1, p: &GeP2) {
    let mut t0 = [0i32; 10];
    fe_sq(&mut r.x, p.x);
    fe_sq(&mut r.z, p.y);
    fe_sq2(&mut r.t, p.z);
    fe_add(&mut r.y, p.x, p.y);
    fe_sq(&mut t0, r.y);
    fe_add(&mut r.y, r.z, r.x);
    {{ let _t = r.z; fe_sub(&mut r.z, _t, r.x); }};
    fe_sub(&mut r.x, t0, r.y);
    {{ let _t = r.t; fe_sub(&mut r.t, _t, r.z); }};
}

pub fn ge_p3_0(h: &mut GeP3) {
    fe_0(&mut h.x);
    fe_1(&mut h.y);
    fe_1(&mut h.z);
    fe_0(&mut h.t);
}

pub fn ge_p3_dbl(r: &mut GeP1P1, p: &GeP3) {
    let mut q = GeP2 { x: [0; 10], y: [0; 10], z: [0; 10] };
    ge_p3_to_p2(&mut q, p);
    ge_p2_dbl(r, &q);
}

pub fn ge_p3_to_p2(r: &mut GeP2, p: &GeP3) {
    r.x = p.x;
    r.y = p.y;
    r.z = p.z;
}

pub fn ge_p3_tobytes(s: &mut [u8; 32], h: &GeP3) {
    let mut recip = [0i32; 10];
    let mut x = [0i32; 10];
    let mut y = [0i32; 10];

    fe_invert(&mut recip, h.z);
    fe_mul(&mut x, h.x, recip);
    fe_mul(&mut y, h.y, recip);
    fe_tobytes(s, y);
    s[31] ^= (fe_isnegative(x) as u8) << 7;
}

pub fn ge_tobytes(s: &mut [u8; 32], h: &GeP2) {
    let mut recip = [0i32; 10];
    let mut x = [0i32; 10];
    let mut y = [0i32; 10];

    fe_invert(&mut recip, h.z);
    fe_mul(&mut x, h.x, recip);
    fe_mul(&mut y, h.y, recip);
    fe_tobytes(s, y);
    s[31] ^= (fe_isnegative(x) as u8) << 7;
}

/// ge_frombytes_vartime: decompress a compressed Edwards point. Includes the
/// testnet non-canonical-encoding rejection from crypto-ops.c.
pub fn ge_frombytes_vartime(h: &mut GeP3, s: &[u8; 32]) -> bool {
    let mut u = [0i32; 10];
    let mut v = [0i32; 10];
    let mut vxx = [0i32; 10];
    let mut check = [0i32; 10];

    let mut h0 = load_4(s) as i64;
    let mut h1 = (load_3(&s[4..]) << 6) as i64;
    let mut h2 = (load_3(&s[7..]) << 5) as i64;
    let mut h3 = (load_3(&s[10..]) << 3) as i64;
    let mut h4 = (load_3(&s[13..]) << 2) as i64;
    let mut h5 = load_4(&s[16..]) as i64;
    let mut h6 = (load_3(&s[20..]) << 7) as i64;
    let mut h7 = (load_3(&s[23..]) << 5) as i64;
    let mut h8 = (load_3(&s[26..]) << 4) as i64;
    let mut h9 = ((load_3(&s[29..]) & 8388607) as i64) << 2;

    // Validate the number to be canonical - Testnet
    if h9 == 33554428
        && h8 == 268435440
        && h7 == 536870880
        && h6 == 2147483520
        && h5 == 4294967295
        && h4 == 67108860
        && h3 == 134217720
        && h2 == 536870880
        && h1 == 1073741760
        && h0 >= 4294967277
    {
        return false;
    }

    let carry9 = (h9 + (1 << 24)) >> 25;
    h0 += carry9 * 19;
    h9 -= carry9 << 25;
    let carry1 = (h1 + (1 << 24)) >> 25;
    h2 += carry1;
    h1 -= carry1 << 25;
    let carry3 = (h3 + (1 << 24)) >> 25;
    h4 += carry3;
    h3 -= carry3 << 25;
    let carry5 = (h5 + (1 << 24)) >> 25;
    h6 += carry5;
    h5 -= carry5 << 25;
    let carry7 = (h7 + (1 << 24)) >> 25;
    h8 += carry7;
    h7 -= carry7 << 25;

    let carry0 = (h0 + (1 << 25)) >> 26;
    h1 += carry0;
    h0 -= carry0 << 26;
    let carry2 = (h2 + (1 << 25)) >> 26;
    h3 += carry2;
    h2 -= carry2 << 26;
    let carry4 = (h4 + (1 << 25)) >> 26;
    h5 += carry4;
    h4 -= carry4 << 26;
    let carry6 = (h6 + (1 << 25)) >> 26;
    h7 += carry6;
    h6 -= carry6 << 26;
    let carry8 = (h8 + (1 << 25)) >> 26;
    h9 += carry8;
    h8 -= carry8 << 26;

    h.y = [
        h0 as i32, h1 as i32, h2 as i32, h3 as i32, h4 as i32, h5 as i32, h6 as i32, h7 as i32,
        h8 as i32, h9 as i32,
    ];
    fe_1(&mut h.z);

    fe_sq(&mut u, h.y);
    let mut d = [0i32; 10];
    fe_frombytes(&mut d, &FE_D);
    fe_mul(&mut v, u, d);
    {{ let _t = u; fe_sub(&mut u, _t, h.z); }};
    {{ let _t = v; fe_add(&mut v, _t, h.z); }};

    fe_divpowm1(&mut h.x, u, v);

    fe_sq(&mut vxx, h.x);
    {{ let _t = vxx; fe_mul(&mut vxx, _t, v); }};
    fe_sub(&mut check, vxx, u);
    if fe_isnonzero(check) {
        fe_add(&mut check, vxx, u);
        if fe_isnonzero(check) {
            return false;
        }
        let mut sqrtm1 = [0i32; 10];
        fe_frombytes(&mut sqrtm1, &FE_SQRTM1);
        {{ let _t = h.x; fe_mul(&mut h.x, _t, sqrtm1); }};
    }

    if fe_isnegative(h.x) != ((s[31] >> 7) != 0) {
        if !fe_isnonzero(h.x) {
            return false;
        }
        {{ let _t = h.x; fe_neg(&mut h.x, _t); }};
    }

    fe_mul(&mut h.t, h.x, h.y);
    true
}

fn ge_precomp_0(h: &mut Precomp) {
    *h = Precomp { yplusx: [1, 0, 0, 0, 0, 0, 0, 0, 0, 0], yminusx: [1, 0, 0, 0, 0, 0, 0, 0, 0, 0], xy2d: [0; 10] };
}

fn equal(b: i8, c: i8) -> u8 {
    let ub = b as u8;
    let uc = c as u8;
    let x = ub ^ uc;
    let mut y = x as u32;
    y = y.wrapping_sub(1);
    (y >> 31) as u8
}

fn negative(b: i8) -> u8 {
    ((b as i64 as u64) >> 63) as u8
}

fn ge_precomp_cmov(t: &mut Precomp, u: &Precomp, b: u8) {
    let mut yp = t.yplusx;
    let mut ym = t.yminusx;
    let mut xd = t.xy2d;
    fe_cmov(&mut yp, u.yplusx, b as u32);
    fe_cmov(&mut ym, u.yminusx, b as u32);
    fe_cmov(&mut xd, u.xy2d, b as u32);
    t.yplusx = yp;
    t.yminusx = ym;
    t.xy2d = xd;
}

fn select(t: &mut Precomp, pos: usize, b: i8) {
    let mut minust = Precomp { yplusx: [0; 10], yminusx: [0; 10], xy2d: [0; 10] };
    let bnegative = negative(b);
    let babs = b - ((((bnegative as i8).wrapping_neg()) & b) << 1);

    ge_precomp_0(t);
    for j in 0..8u8 {
        ge_precomp_cmov(t, &GE_BASE[pos][j as usize], equal(babs, (j + 1) as i8));
    }
    minust.yplusx = t.yminusx;
    minust.yminusx = t.yplusx;
    minust.xy2d = t.xy2d;
    fe_neg(&mut minust.xy2d, t.xy2d);
    ge_precomp_cmov(t, &minust, bnegative);
}

/// h = a * B. Precondition: a[31] <= 127.
pub fn ge_scalarmult_base(h: &mut GeP3, a: &[u8; 32]) {
    let mut e = [0i8; 64];
    let mut carry: i8;
    let mut r = GeP1P1 { x: [0; 10], y: [0; 10], z: [0; 10], t: [0; 10] };
    let mut s = GeP2 { x: [0; 10], y: [0; 10], z: [0; 10] };
    let mut t = Precomp { yplusx: [0; 10], yminusx: [0; 10], xy2d: [0; 10] };

    for i in 0..32 {
        e[2 * i] = (a[i] & 15) as i8;
        e[2 * i + 1] = ((a[i] >> 4) & 15) as i8;
    }

    carry = 0;
    for i in 0..63 {
        e[i] += carry;
        carry = (e[i] + 8) >> 4;
        e[i] -= carry << 4;
    }
    e[63] += carry;

    ge_p3_0(h);
    let mut i = 1;
    while i < 64 {
        select(&mut t, i / 2, e[i]);
        ge_madd(&mut r, h, &t);
        ge_p1p1_to_p3(h, &r);
        i += 2;
    }

    ge_p3_dbl(&mut r, h);
    ge_p1p1_to_p2(&mut s, &r);
    ge_p2_dbl(&mut r, &s);
    ge_p1p1_to_p2(&mut s, &r);
    ge_p2_dbl(&mut r, &s);
    ge_p1p1_to_p2(&mut s, &r);
    ge_p2_dbl(&mut r, &s);
    ge_p1p1_to_p3(h, &r);

    i = 0;
    while i < 64 {
        select(&mut t, i / 2, e[i]);
        ge_madd(&mut r, h, &t);
        ge_p1p1_to_p3(h, &r);
        i += 2;
    }
}

fn slide(r: &mut [i8; 256], a: &[u8; 32]) {
    for i in 0..256 {
        r[i] = (1 & (a[i >> 3] >> (i & 7))) as i8;
    }
    let mut i = 0;
    while i < 256 {
        if r[i] != 0 {
            let mut b = 1;
            while b <= 6 && i + b < 256 {
                if r[i + b] != 0 {
                    if r[i] + (r[i + b] << b) <= 15 {
                        r[i] += r[i + b] << b;
                        r[i + b] = 0;
                    } else if r[i] - (r[i + b] << b) >= -15 {
                        r[i] -= r[i + b] << b;
                        let mut k = i + b;
                        loop {
                            if k >= 256 {
                                break;
                            }
                            if r[k] == 0 {
                                r[k] = 1;
                                break;
                            }
                            r[k] = 0;
                            k += 1;
                        }
                    } else {
                        break;
                    }
                }
                b += 1;
            }
        }
        i += 1;
    }
}

pub fn ge_dsm_precomp(r: &mut GeDsmp, s: &GeP3) {
    let mut t = GeP1P1 { x: [0; 10], y: [0; 10], z: [0; 10], t: [0; 10] };
    let mut s2 = GeP3 { x: [0; 10], y: [0; 10], z: [0; 10], t: [0; 10] };
    let mut u = GeP3 { x: [0; 10], y: [0; 10], z: [0; 10], t: [0; 10] };
    ge_p3_to_cached(&mut r[0], s);
    ge_p3_dbl(&mut t, s);
    ge_p1p1_to_p3(&mut s2, &t);
    ge_add(&mut t, &s2, &r[0]);
    ge_p1p1_to_p3(&mut u, &t);
    ge_p3_to_cached(&mut r[1], &u);
    ge_add(&mut t, &s2, &r[1]);
    ge_p1p1_to_p3(&mut u, &t);
    ge_p3_to_cached(&mut r[2], &u);
    ge_add(&mut t, &s2, &r[2]);
    ge_p1p1_to_p3(&mut u, &t);
    ge_p3_to_cached(&mut r[3], &u);
    ge_add(&mut t, &s2, &r[3]);
    ge_p1p1_to_p3(&mut u, &t);
    ge_p3_to_cached(&mut r[4], &u);
    ge_add(&mut t, &s2, &r[4]);
    ge_p1p1_to_p3(&mut u, &t);
    ge_p3_to_cached(&mut r[5], &u);
    ge_add(&mut t, &s2, &r[5]);
    ge_p1p1_to_p3(&mut u, &t);
    ge_p3_to_cached(&mut r[6], &u);
    ge_add(&mut t, &s2, &r[6]);
    ge_p1p1_to_p3(&mut u, &t);
    ge_p3_to_cached(&mut r[7], &u);
}

/// r = a * A + b * B
pub fn ge_double_scalarmult_base_vartime(r: &mut GeP2, a: &[u8; 32], big_a: &GeP3, b: &[u8; 32]) {
    let mut aslide = [0i8; 256];
    let mut bslide = [0i8; 256];
    let mut ai = [GeCached { yplus_x: [0; 10], yminus_x: [0; 10], z: [0; 10], t2d: [0; 10] }; 8];
    let mut t = GeP1P1 { x: [0; 10], y: [0; 10], z: [0; 10], t: [0; 10] };
    let mut u = GeP3 { x: [0; 10], y: [0; 10], z: [0; 10], t: [0; 10] };

    slide(&mut aslide, a);
    slide(&mut bslide, b);
    ge_dsm_precomp(&mut ai, big_a);

    ge_p2_0(r);

    let mut i = 255i32;
    loop {
        if aslide[i as usize] != 0 || bslide[i as usize] != 0 {
            break;
        }
        if i == 0 {
            break;
        }
        i -= 1;
    }
    while i >= 0 {
        ge_p2_dbl(&mut t, r);

        if aslide[i as usize] > 0 {
            ge_p1p1_to_p3(&mut u, &t);
            ge_add(&mut t, &u, &ai[(aslide[i as usize] / 2) as usize]);
        } else if aslide[i as usize] < 0 {
            ge_p1p1_to_p3(&mut u, &t);
            ge_sub(&mut t, &u, &ai[((-aslide[i as usize]) / 2) as usize]);
        }

        if bslide[i as usize] > 0 {
            ge_p1p1_to_p3(&mut u, &t);
            ge_madd(&mut t, &u, &GE_BI[(bslide[i as usize] / 2) as usize]);
        } else if bslide[i as usize] < 0 {
            ge_p1p1_to_p3(&mut u, &t);
            ge_msub(&mut t, &u, &GE_BI[((-bslide[i as usize]) / 2) as usize]);
        }

        ge_p1p1_to_p2(r, &t);
        if i == 0 {
            break;
        }
        i -= 1;
    }
}

fn ge_cached_0(r: &mut GeCached) {
    fe_1(&mut r.yplus_x);
    fe_1(&mut r.yminus_x);
    fe_1(&mut r.z);
    fe_0(&mut r.t2d);
}

fn ge_cached_cmov(t: &mut GeCached, u: &GeCached, b: u8) {
    let mut yp = t.yplus_x;
    let mut ym = t.yminus_x;
    let mut z = t.z;
    let mut t2 = t.t2d;
    fe_cmov(&mut yp, u.yplus_x, b as u32);
    fe_cmov(&mut ym, u.yminus_x, b as u32);
    fe_cmov(&mut z, u.z, b as u32);
    fe_cmov(&mut t2, u.t2d, b as u32);
    t.yplus_x = yp;
    t.yminus_x = ym;
    t.z = z;
    t.t2d = t2;
}

/// Assumes that a[31] <= 127.
pub fn ge_scalarmult(r: &mut GeP2, a: &[u8; 32], big_a: &GeP3) {
    let mut e = [0i8; 64];
    let mut carry: i32;
    let mut carry2: i32;
    let mut ai = [GeCached { yplus_x: [0; 10], yminus_x: [0; 10], z: [0; 10], t2d: [0; 10] }; 8];
    let mut t = GeP1P1 { x: [0; 10], y: [0; 10], z: [0; 10], t: [0; 10] };
    let mut u = GeP3 { x: [0; 10], y: [0; 10], z: [0; 10], t: [0; 10] };

    carry = 0;
    for i in 0..31 {
        carry += a[i] as i32;
        carry2 = (carry + 8) >> 4;
        e[2 * i] = (carry - (carry2 << 4)) as i8;
        carry = (carry2 + 8) >> 4;
        e[2 * i + 1] = (carry2 - (carry << 4)) as i8;
    }
    carry += a[31] as i32;
    carry2 = (carry + 8) >> 4;
    e[62] = (carry - (carry2 << 4)) as i8;
    e[63] = carry2 as i8;

    ge_p3_to_cached(&mut ai[0], big_a);
    for i in 0..7 {
        ge_add(&mut t, big_a, &ai[i]);
        ge_p1p1_to_p3(&mut u, &t);
        ge_p3_to_cached(&mut ai[i + 1], &u);
    }

    ge_p2_0(r);
    let mut i = 63i32;
    while i >= 0 {
        let b = e[i as usize];
        let bnegative = negative(b);
        let babs = b - ((((bnegative as i8).wrapping_neg()) & b) << 1);
        let mut cur = GeCached { yplus_x: [0; 10], yminus_x: [0; 10], z: [0; 10], t2d: [0; 10] };
        let mut minuscur = GeCached { yplus_x: [0; 10], yminus_x: [0; 10], z: [0; 10], t2d: [0; 10] };
        ge_p2_dbl(&mut t, r);
        ge_p1p1_to_p2(r, &t);
        ge_p2_dbl(&mut t, r);
        ge_p1p1_to_p2(r, &t);
        ge_p2_dbl(&mut t, r);
        ge_p1p1_to_p2(r, &t);
        ge_p2_dbl(&mut t, r);
        ge_p1p1_to_p3(&mut u, &t);
        ge_cached_0(&mut cur);
        for j in 0..8u8 {
            ge_cached_cmov(&mut cur, &ai[j as usize], equal(babs, (j + 1) as i8));
        }
        minuscur.yplus_x = cur.yminus_x;
        minuscur.yminus_x = cur.yplus_x;
        minuscur.z = cur.z;
        fe_neg(&mut minuscur.t2d, cur.t2d);
        ge_cached_cmov(&mut cur, &minuscur, bnegative);
        ge_add(&mut t, &u, &cur);
        ge_p1p1_to_p2(r, &t);
        if i == 0 {
            break;
        }
        i -= 1;
    }
}

/// r = a * A + b * Bi
pub fn ge_double_scalarmult_precomp_vartime(
    r: &mut GeP2,
    a: &[u8; 32],
    big_a: &GeP3,
    b: &[u8; 32],
    bi: &GeDsmp,
) {
    let mut aslide = [0i8; 256];
    let mut bslide = [0i8; 256];
    let mut ai = [GeCached { yplus_x: [0; 10], yminus_x: [0; 10], z: [0; 10], t2d: [0; 10] }; 8];
    let mut t = GeP1P1 { x: [0; 10], y: [0; 10], z: [0; 10], t: [0; 10] };
    let mut u = GeP3 { x: [0; 10], y: [0; 10], z: [0; 10], t: [0; 10] };

    slide(&mut aslide, a);
    slide(&mut bslide, b);
    ge_dsm_precomp(&mut ai, big_a);

    ge_p2_0(r);

    let mut i = 255i32;
    loop {
        if aslide[i as usize] != 0 || bslide[i as usize] != 0 {
            break;
        }
        if i == 0 {
            break;
        }
        i -= 1;
    }
    while i >= 0 {
        ge_p2_dbl(&mut t, r);

        if aslide[i as usize] > 0 {
            ge_p1p1_to_p3(&mut u, &t);
            ge_add(&mut t, &u, &ai[(aslide[i as usize] / 2) as usize]);
        } else if aslide[i as usize] < 0 {
            ge_p1p1_to_p3(&mut u, &t);
            ge_sub(&mut t, &u, &ai[((-aslide[i as usize]) / 2) as usize]);
        }

        if bslide[i as usize] > 0 {
            ge_p1p1_to_p3(&mut u, &t);
            ge_add(&mut t, &u, &bi[(bslide[i as usize] / 2) as usize]);
        } else if bslide[i as usize] < 0 {
            ge_p1p1_to_p3(&mut u, &t);
            ge_sub(&mut t, &u, &bi[((-bslide[i as usize]) / 2) as usize]);
        }

        ge_p1p1_to_p2(r, &t);
        if i == 0 {
            break;
        }
        i -= 1;
    }
}

pub fn ge_mul8(r: &mut GeP1P1, t: &GeP2) {
    let mut u = GeP2 { x: [0; 10], y: [0; 10], z: [0; 10] };
    ge_p2_dbl(r, t);
    ge_p1p1_to_p2(&mut u, r);
    ge_p2_dbl(r, &u);
    ge_p1p1_to_p2(&mut u, r);
    ge_p2_dbl(r, &u);
}

/// ge_fromfe_frombytes_vartime: map a 256-bit value interpreted as a field
/// element to a projective Edwards point (Montgomery conversion), exactly as
/// crypto-ops.c.
pub fn ge_fromfe_frombytes_vartime(r: &mut GeP2, s: &[u8; 32]) {
    let mut u = [0i32; 10];
    let mut v = [0i32; 10];
    let mut w = [0i32; 10];
    let mut x = [0i32; 10];
    let mut y = [0i32; 10];
    let mut z;
    let sign: u8;

    fe_frombytes(&mut u, s);

    fe_sq2(&mut v, u); // 2 * u^2
    fe_1(&mut w);
    {{ let _t = w; fe_add(&mut w, v, _t); }}; // w = 2 * u^2 + 1
    fe_sq(&mut x, w); // w^2
    let mut ma2 = [0i32; 10];
    fe_frombytes(&mut ma2, &FE_MA2);
    fe_mul(&mut y, ma2, v); // -2 * A^2 * u^2
    {{ let _t = x; fe_add(&mut x, _t, y); }}; // x = w^2 - 2 * A^2 * u^2
    fe_divpowm1(&mut r.x, w, x); // (w / x)^(m + 1)
    fe_sq(&mut y, r.x);
    {{ let _t = x; fe_mul(&mut x, y, _t); }};
    fe_sub(&mut y, w, x);
    let mut ma = [0i32; 10];
    fe_frombytes(&mut ma, &FE_MA);
    z = ma;

    if fe_isnonzero(y) {
        fe_add(&mut y, w, x);
        if fe_isnonzero(y) {
            // negative branch
            let mut sqrtm1 = [0i32; 10];
            fe_frombytes(&mut sqrtm1, &FE_SQRTM1);
            {{ let _t = x; fe_mul(&mut x, _t, sqrtm1); }};
            fe_sub(&mut y, w, x);
            if fe_isnonzero(y) {
                debug_assert!({
                    fe_add(&mut y, w, x);
                    !fe_isnonzero(y)
                });
                let mut fffb3 = [0i32; 10];
                fe_frombytes(&mut fffb3, &FE_FFFB3);
                {{ let _t = r.x; fe_mul(&mut r.x, _t, fffb3); }};
            } else {
                let mut fffb4 = [0i32; 10];
                fe_frombytes(&mut fffb4, &FE_FFFB4);
                {{ let _t = r.x; fe_mul(&mut r.x, _t, fffb4); }};
            }
            sign = 1;
        } else {
            let mut fffb1 = [0i32; 10];
            fe_frombytes(&mut fffb1, &FE_FFFB1);
            {{ let _t = r.x; fe_mul(&mut r.x, _t, fffb1); }};
            {{ let _t = r.x; fe_mul(&mut r.x, _t, u); }};
            {{ let _t = z; fe_mul(&mut z, _t, v); }};
            sign = 0;
        }
    } else {
        let mut fffb2 = [0i32; 10];
        fe_frombytes(&mut fffb2, &FE_FFFB2);
        {{ let _t = r.x; fe_mul(&mut r.x, _t, fffb2); }};
        {{ let _t = r.x; fe_mul(&mut r.x, _t, u); }};
        {{ let _t = z; fe_mul(&mut z, _t, v); }};
        sign = 0;
    }

    if fe_isnegative(r.x) != (sign != 0) {
        debug_assert!(fe_isnonzero(r.x));
        {{ let _t = r.x; fe_neg(&mut r.x, _t); }};
    }
    fe_add(&mut r.z, z, w);
    fe_sub(&mut r.y, z, w);
    {{ let _t = r.x; fe_mul(&mut r.x, _t, r.z); }};
}

// ---------------------------------------------------------------- scalar ops

pub fn sc_0(s: &mut [u8; 32]) {
    *s = [0u8; 32];
}

pub fn sc_reduce(s: &mut [u8; 64]) {
    let mut s0 = (2097151 & load_3(s)) as i64;
    let mut s1 = (2097151 & (load_4(&s[2..]) >> 5)) as i64;
    let mut s2 = (2097151 & (load_3(&s[5..]) >> 2)) as i64;
    let mut s3 = (2097151 & (load_4(&s[7..]) >> 7)) as i64;
    let mut s4 = (2097151 & (load_4(&s[10..]) >> 4)) as i64;
    let mut s5 = (2097151 & (load_3(&s[13..]) >> 1)) as i64;
    let mut s6 = (2097151 & (load_4(&s[15..]) >> 6)) as i64;
    let mut s7 = (2097151 & (load_3(&s[18..]) >> 3)) as i64;
    let mut s8 = (2097151 & load_3(&s[21..])) as i64;
    let mut s9 = (2097151 & (load_4(&s[23..]) >> 5)) as i64;
    let mut s10 = (2097151 & (load_3(&s[26..]) >> 2)) as i64;
    let mut s11 = (2097151 & (load_4(&s[28..]) >> 7)) as i64;
    let mut s12 = (2097151 & (load_4(&s[31..]) >> 4)) as i64;
    let mut s13 = (2097151 & (load_3(&s[34..]) >> 1)) as i64;
    let mut s14 = (2097151 & (load_4(&s[36..]) >> 6)) as i64;
    let mut s15 = (2097151 & (load_3(&s[39..]) >> 3)) as i64;
    let mut s16 = (2097151 & load_3(&s[42..])) as i64;
    let mut s17 = (2097151 & (load_4(&s[44..]) >> 5)) as i64;
    let mut s18 = (2097151 & (load_3(&s[47..]) >> 2)) as i64;
    let mut s19 = (2097151 & (load_4(&s[49..]) >> 7)) as i64;
    let mut s20 = (2097151 & (load_4(&s[52..]) >> 4)) as i64;
    let mut s21 = (2097151 & (load_3(&s[55..]) >> 1)) as i64;
    let mut s22 = (2097151 & (load_4(&s[57..]) >> 6)) as i64;
    let mut s23 = (load_4(&s[60..]) >> 3) as i64;

    s11 += s23 * 666643;
    s12 += s23 * 470296;
    s13 += s23 * 654183;
    s14 -= s23 * 997805;
    s15 += s23 * 136657;
    s16 -= s23 * 683901;

    s10 += s22 * 666643;
    s11 += s22 * 470296;
    s12 += s22 * 654183;
    s13 -= s22 * 997805;
    s14 += s22 * 136657;
    s15 -= s22 * 683901;

    s9 += s21 * 666643;
    s10 += s21 * 470296;
    s11 += s21 * 654183;
    s12 -= s21 * 997805;
    s13 += s21 * 136657;
    s14 -= s21 * 683901;

    s8 += s20 * 666643;
    s9 += s20 * 470296;
    s10 += s20 * 654183;
    s11 -= s20 * 997805;
    s12 += s20 * 136657;
    s13 -= s20 * 683901;

    s7 += s19 * 666643;
    s8 += s19 * 470296;
    s9 += s19 * 654183;
    s10 -= s19 * 997805;
    s11 += s19 * 136657;
    s12 -= s19 * 683901;

    s6 += s18 * 666643;
    s7 += s18 * 470296;
    s8 += s18 * 654183;
    s9 -= s18 * 997805;
    s10 += s18 * 136657;
    s11 -= s18 * 683901;

    let carry6 = (s6 + (1 << 20)) >> 21;
    s7 += carry6;
    s6 -= carry6 << 21;
    let carry8 = (s8 + (1 << 20)) >> 21;
    s9 += carry8;
    s8 -= carry8 << 21;
    let carry10 = (s10 + (1 << 20)) >> 21;
    s11 += carry10;
    s10 -= carry10 << 21;
    let carry12 = (s12 + (1 << 20)) >> 21;
    s13 += carry12;
    s12 -= carry12 << 21;
    let carry14 = (s14 + (1 << 20)) >> 21;
    s15 += carry14;
    s14 -= carry14 << 21;
    let carry16 = (s16 + (1 << 20)) >> 21;
    s17 += carry16;
    s16 -= carry16 << 21;

    let carry7 = (s7 + (1 << 20)) >> 21;
    s8 += carry7;
    s7 -= carry7 << 21;
    let carry9 = (s9 + (1 << 20)) >> 21;
    s10 += carry9;
    s9 -= carry9 << 21;
    let carry11 = (s11 + (1 << 20)) >> 21;
    s12 += carry11;
    s11 -= carry11 << 21;
    let carry13 = (s13 + (1 << 20)) >> 21;
    s14 += carry13;
    s13 -= carry13 << 21;
    let carry15 = (s15 + (1 << 20)) >> 21;
    s16 += carry15;
    s15 -= carry15 << 21;

    s5 += s17 * 666643;
    s6 += s17 * 470296;
    s7 += s17 * 654183;
    s8 -= s17 * 997805;
    s9 += s17 * 136657;
    s10 -= s17 * 683901;

    s4 += s16 * 666643;
    s5 += s16 * 470296;
    s6 += s16 * 654183;
    s7 -= s16 * 997805;
    s8 += s16 * 136657;
    s9 -= s16 * 683901;

    s3 += s15 * 666643;
    s4 += s15 * 470296;
    s5 += s15 * 654183;
    s6 -= s15 * 997805;
    s7 += s15 * 136657;
    s8 -= s15 * 683901;

    s2 += s14 * 666643;
    s3 += s14 * 470296;
    s4 += s14 * 654183;
    s5 -= s14 * 997805;
    s6 += s14 * 136657;
    s7 -= s14 * 683901;

    s1 += s13 * 666643;
    s2 += s13 * 470296;
    s3 += s13 * 654183;
    s4 -= s13 * 997805;
    s5 += s13 * 136657;
    s6 -= s13 * 683901;

    s0 += s12 * 666643;
    s1 += s12 * 470296;
    s2 += s12 * 654183;
    s3 -= s12 * 997805;
    s4 += s12 * 136657;
    s5 -= s12 * 683901;
    s12 = 0;

    let carry0 = (s0 + (1 << 20)) >> 21;
    s1 += carry0;
    s0 -= carry0 << 21;
    let carry2 = (s2 + (1 << 20)) >> 21;
    s3 += carry2;
    s2 -= carry2 << 21;
    let carry4 = (s4 + (1 << 20)) >> 21;
    s5 += carry4;
    s4 -= carry4 << 21;
    let carry6 = (s6 + (1 << 20)) >> 21;
    s7 += carry6;
    s6 -= carry6 << 21;
    let carry8 = (s8 + (1 << 20)) >> 21;
    s9 += carry8;
    s8 -= carry8 << 21;
    let carry10 = (s10 + (1 << 20)) >> 21;
    s11 += carry10;
    s10 -= carry10 << 21;

    let carry1 = (s1 + (1 << 20)) >> 21;
    s2 += carry1;
    s1 -= carry1 << 21;
    let carry3 = (s3 + (1 << 20)) >> 21;
    s4 += carry3;
    s3 -= carry3 << 21;
    let carry5 = (s5 + (1 << 20)) >> 21;
    s6 += carry5;
    s5 -= carry5 << 21;
    let carry7 = (s7 + (1 << 20)) >> 21;
    s8 += carry7;
    s7 -= carry7 << 21;
    let carry9 = (s9 + (1 << 20)) >> 21;
    s10 += carry9;
    s9 -= carry9 << 21;
    let carry11 = (s11 + (1 << 20)) >> 21;
    s12 += carry11;
    s11 -= carry11 << 21;

    s0 += s12 * 666643;
    s1 += s12 * 470296;
    s2 += s12 * 654183;
    s3 -= s12 * 997805;
    s4 += s12 * 136657;
    s5 -= s12 * 683901;
    s12 = 0;

    let carry0 = s0 >> 21;
    s1 += carry0;
    s0 -= carry0 << 21;
    let carry1 = s1 >> 21;
    s2 += carry1;
    s1 -= carry1 << 21;
    let carry2 = s2 >> 21;
    s3 += carry2;
    s2 -= carry2 << 21;
    let carry3 = s3 >> 21;
    s4 += carry3;
    s3 -= carry3 << 21;
    let carry4 = s4 >> 21;
    s5 += carry4;
    s4 -= carry4 << 21;
    let carry5 = s5 >> 21;
    s6 += carry5;
    s5 -= carry5 << 21;
    let carry6 = s6 >> 21;
    s7 += carry6;
    s6 -= carry6 << 21;
    let carry7 = s7 >> 21;
    s8 += carry7;
    s7 -= carry7 << 21;
    let carry8 = s8 >> 21;
    s9 += carry8;
    s8 -= carry8 << 21;
    let carry9 = s9 >> 21;
    s10 += carry9;
    s9 -= carry9 << 21;
    let carry10 = s10 >> 21;
    s11 += carry10;
    s10 -= carry10 << 21;
    let carry11 = s11 >> 21;
    s12 += carry11;
    s11 -= carry11 << 21;

    s0 += s12 * 666643;
    s1 += s12 * 470296;
    s2 += s12 * 654183;
    s3 -= s12 * 997805;
    s4 += s12 * 136657;
    s5 -= s12 * 683901;

    let carry0 = s0 >> 21;
    s1 += carry0;
    s0 -= carry0 << 21;
    let carry1 = s1 >> 21;
    s2 += carry1;
    s1 -= carry1 << 21;
    let carry2 = s2 >> 21;
    s3 += carry2;
    s2 -= carry2 << 21;
    let carry3 = s3 >> 21;
    s4 += carry3;
    s3 -= carry3 << 21;
    let carry4 = s4 >> 21;
    s5 += carry4;
    s4 -= carry4 << 21;
    let carry5 = s5 >> 21;
    s6 += carry5;
    s5 -= carry5 << 21;
    let carry6 = s6 >> 21;
    s7 += carry6;
    s6 -= carry6 << 21;
    let carry7 = s7 >> 21;
    s8 += carry7;
    s7 -= carry7 << 21;
    let carry8 = s8 >> 21;
    s9 += carry8;
    s8 -= carry8 << 21;
    let carry9 = s9 >> 21;
    s10 += carry9;
    s9 -= carry9 << 21;
    let carry10 = s10 >> 21;
    s11 += carry10;
    s10 -= carry10 << 21;

    *s = [0u8; 64];
    s[0] = (s0 >> 0) as u8;
    s[1] = (s0 >> 8) as u8;
    s[2] = ((s0 >> 16) | (s1 << 5)) as u8;
    s[3] = (s1 >> 3) as u8;
    s[4] = (s1 >> 11) as u8;
    s[5] = ((s1 >> 19) | (s2 << 2)) as u8;
    s[6] = (s2 >> 6) as u8;
    s[7] = ((s2 >> 14) | (s3 << 7)) as u8;
    s[8] = (s3 >> 1) as u8;
    s[9] = (s3 >> 9) as u8;
    s[10] = ((s3 >> 17) | (s4 << 4)) as u8;
    s[11] = (s4 >> 4) as u8;
    s[12] = (s4 >> 12) as u8;
    s[13] = ((s4 >> 20) | (s5 << 1)) as u8;
    s[14] = (s5 >> 7) as u8;
    s[15] = ((s5 >> 15) | (s6 << 6)) as u8;
    s[16] = (s6 >> 2) as u8;
    s[17] = (s6 >> 10) as u8;
    s[18] = ((s6 >> 18) | (s7 << 3)) as u8;
    s[19] = (s7 >> 5) as u8;
    s[20] = (s7 >> 13) as u8;
    s[21] = (s8 >> 0) as u8;
    s[22] = (s8 >> 8) as u8;
    s[23] = ((s8 >> 16) | (s9 << 5)) as u8;
    s[24] = (s9 >> 3) as u8;
    s[25] = (s9 >> 11) as u8;
    s[26] = ((s9 >> 19) | (s10 << 2)) as u8;
    s[27] = (s10 >> 6) as u8;
    s[28] = ((s10 >> 14) | (s11 << 7)) as u8;
    s[29] = (s11 >> 1) as u8;
    s[30] = (s11 >> 9) as u8;
    s[31] = (s11 >> 17) as u8;
}

pub fn sc_reduce32(s: &mut [u8; 32]) {
    let mut s0 = (2097151 & load_3(s)) as i64;
    let mut s1 = (2097151 & (load_4(&s[2..]) >> 5)) as i64;
    let mut s2 = (2097151 & (load_3(&s[5..]) >> 2)) as i64;
    let mut s3 = (2097151 & (load_4(&s[7..]) >> 7)) as i64;
    let mut s4 = (2097151 & (load_4(&s[10..]) >> 4)) as i64;
    let mut s5 = (2097151 & (load_3(&s[13..]) >> 1)) as i64;
    let mut s6 = (2097151 & (load_4(&s[15..]) >> 6)) as i64;
    let mut s7 = (2097151 & (load_3(&s[18..]) >> 3)) as i64;
    let mut s8 = (2097151 & load_3(&s[21..])) as i64;
    let mut s9 = (2097151 & (load_4(&s[23..]) >> 5)) as i64;
    let mut s10 = (2097151 & (load_3(&s[26..]) >> 2)) as i64;
    let mut s11 = (load_4(&s[28..]) >> 7) as i64;
    let mut s12 = 0i64;

    let carry0 = (s0 + (1 << 20)) >> 21;
    s1 += carry0;
    s0 -= carry0 << 21;
    let carry2 = (s2 + (1 << 20)) >> 21;
    s3 += carry2;
    s2 -= carry2 << 21;
    let carry4 = (s4 + (1 << 20)) >> 21;
    s5 += carry4;
    s4 -= carry4 << 21;
    let carry6 = (s6 + (1 << 20)) >> 21;
    s7 += carry6;
    s6 -= carry6 << 21;
    let carry8 = (s8 + (1 << 20)) >> 21;
    s9 += carry8;
    s8 -= carry8 << 21;
    let carry10 = (s10 + (1 << 20)) >> 21;
    s11 += carry10;
    s10 -= carry10 << 21;

    let carry1 = (s1 + (1 << 20)) >> 21;
    s2 += carry1;
    s1 -= carry1 << 21;
    let carry3 = (s3 + (1 << 20)) >> 21;
    s4 += carry3;
    s3 -= carry3 << 21;
    let carry5 = (s5 + (1 << 20)) >> 21;
    s6 += carry5;
    s5 -= carry5 << 21;
    let carry7 = (s7 + (1 << 20)) >> 21;
    s8 += carry7;
    s7 -= carry7 << 21;
    let carry9 = (s9 + (1 << 20)) >> 21;
    s10 += carry9;
    s9 -= carry9 << 21;
    let carry11 = (s11 + (1 << 20)) >> 21;
    s12 += carry11;
    s11 -= carry11 << 21;

    s0 += s12 * 666643;
    s1 += s12 * 470296;
    s2 += s12 * 654183;
    s3 -= s12 * 997805;
    s4 += s12 * 136657;
    s5 -= s12 * 683901;
    s12 = 0;

    let carry0 = s0 >> 21;
    s1 += carry0;
    s0 -= carry0 << 21;
    let carry1 = s1 >> 21;
    s2 += carry1;
    s1 -= carry1 << 21;
    let carry2 = s2 >> 21;
    s3 += carry2;
    s2 -= carry2 << 21;
    let carry3 = s3 >> 21;
    s4 += carry3;
    s3 -= carry3 << 21;
    let carry4 = s4 >> 21;
    s5 += carry4;
    s4 -= carry4 << 21;
    let carry5 = s5 >> 21;
    s6 += carry5;
    s5 -= carry5 << 21;
    let carry6 = s6 >> 21;
    s7 += carry6;
    s6 -= carry6 << 21;
    let carry7 = s7 >> 21;
    s8 += carry7;
    s7 -= carry7 << 21;
    let carry8 = s8 >> 21;
    s9 += carry8;
    s8 -= carry8 << 21;
    let carry9 = s9 >> 21;
    s10 += carry9;
    s9 -= carry9 << 21;
    let carry10 = s10 >> 21;
    s11 += carry10;
    s10 -= carry10 << 21;
    let carry11 = s11 >> 21;
    s12 += carry11;
    s11 -= carry11 << 21;

    s0 += s12 * 666643;
    s1 += s12 * 470296;
    s2 += s12 * 654183;
    s3 -= s12 * 997805;
    s4 += s12 * 136657;
    s5 -= s12 * 683901;

    let carry0 = s0 >> 21;
    s1 += carry0;
    s0 -= carry0 << 21;
    let carry1 = s1 >> 21;
    s2 += carry1;
    s1 -= carry1 << 21;
    let carry2 = s2 >> 21;
    s3 += carry2;
    s2 -= carry2 << 21;
    let carry3 = s3 >> 21;
    s4 += carry3;
    s3 -= carry3 << 21;
    let carry4 = s4 >> 21;
    s5 += carry4;
    s4 -= carry4 << 21;
    let carry5 = s5 >> 21;
    s6 += carry5;
    s5 -= carry5 << 21;
    let carry6 = s6 >> 21;
    s7 += carry6;
    s6 -= carry6 << 21;
    let carry7 = s7 >> 21;
    s8 += carry7;
    s7 -= carry7 << 21;
    let carry8 = s8 >> 21;
    s9 += carry8;
    s8 -= carry8 << 21;
    let carry9 = s9 >> 21;
    s10 += carry9;
    s9 -= carry9 << 21;
    let carry10 = s10 >> 21;
    s11 += carry10;
    s10 -= carry10 << 21;

    s[0] = (s0 >> 0) as u8;
    s[1] = (s0 >> 8) as u8;
    s[2] = ((s0 >> 16) | (s1 << 5)) as u8;
    s[3] = (s1 >> 3) as u8;
    s[4] = (s1 >> 11) as u8;
    s[5] = ((s1 >> 19) | (s2 << 2)) as u8;
    s[6] = (s2 >> 6) as u8;
    s[7] = ((s2 >> 14) | (s3 << 7)) as u8;
    s[8] = (s3 >> 1) as u8;
    s[9] = (s3 >> 9) as u8;
    s[10] = ((s3 >> 17) | (s4 << 4)) as u8;
    s[11] = (s4 >> 4) as u8;
    s[12] = (s4 >> 12) as u8;
    s[13] = ((s4 >> 20) | (s5 << 1)) as u8;
    s[14] = (s5 >> 7) as u8;
    s[15] = ((s5 >> 15) | (s6 << 6)) as u8;
    s[16] = (s6 >> 2) as u8;
    s[17] = (s6 >> 10) as u8;
    s[18] = ((s6 >> 18) | (s7 << 3)) as u8;
    s[19] = (s7 >> 5) as u8;
    s[20] = (s7 >> 13) as u8;
    s[21] = (s8 >> 0) as u8;
    s[22] = (s8 >> 8) as u8;
    s[23] = ((s8 >> 16) | (s9 << 5)) as u8;
    s[24] = (s9 >> 3) as u8;
    s[25] = (s9 >> 11) as u8;
    s[26] = ((s9 >> 19) | (s10 << 2)) as u8;
    s[27] = (s10 >> 6) as u8;
    s[28] = ((s10 >> 14) | (s11 << 7)) as u8;
    s[29] = (s11 >> 1) as u8;
    s[30] = (s11 >> 9) as u8;
    s[31] = (s11 >> 17) as u8;
}

pub fn sc_add(s: &mut [u8; 32], a: &[u8; 32], b: &[u8; 32]) {
    let mut a0 = (2097151 & load_3(a)) as i64;
    let mut a1 = (2097151 & (load_4(&a[2..]) >> 5)) as i64;
    let mut a2 = (2097151 & (load_3(&a[5..]) >> 2)) as i64;
    let mut a3 = (2097151 & (load_4(&a[7..]) >> 7)) as i64;
    let mut a4 = (2097151 & (load_4(&a[10..]) >> 4)) as i64;
    let mut a5 = (2097151 & (load_3(&a[13..]) >> 1)) as i64;
    let mut a6 = (2097151 & (load_4(&a[15..]) >> 6)) as i64;
    let mut a7 = (2097151 & (load_3(&a[18..]) >> 3)) as i64;
    let mut a8 = (2097151 & load_3(&a[21..])) as i64;
    let mut a9 = (2097151 & (load_4(&a[23..]) >> 5)) as i64;
    let mut a10 = (2097151 & (load_3(&a[26..]) >> 2)) as i64;
    let mut a11 = (load_4(&a[28..]) >> 7) as i64;
    let mut b0 = (2097151 & load_3(b)) as i64;
    let mut b1 = (2097151 & (load_4(&b[2..]) >> 5)) as i64;
    let mut b2 = (2097151 & (load_3(&b[5..]) >> 2)) as i64;
    let mut b3 = (2097151 & (load_4(&b[7..]) >> 7)) as i64;
    let mut b4 = (2097151 & (load_4(&b[10..]) >> 4)) as i64;
    let mut b5 = (2097151 & (load_3(&b[13..]) >> 1)) as i64;
    let mut b6 = (2097151 & (load_4(&b[15..]) >> 6)) as i64;
    let mut b7 = (2097151 & (load_3(&b[18..]) >> 3)) as i64;
    let mut b8 = (2097151 & load_3(&b[21..])) as i64;
    let mut b9 = (2097151 & (load_4(&b[23..]) >> 5)) as i64;
    let mut b10 = (2097151 & (load_3(&b[26..]) >> 2)) as i64;
    let mut b11 = (load_4(&b[28..]) >> 7) as i64;
    let mut s0 = a0 + b0;
    let mut s1 = a1 + b1;
    let mut s2 = a2 + b2;
    let mut s3 = a3 + b3;
    let mut s4 = a4 + b4;
    let mut s5 = a5 + b5;
    let mut s6 = a6 + b6;
    let mut s7 = a7 + b7;
    let mut s8 = a8 + b8;
    let mut s9 = a9 + b9;
    let mut s10 = a10 + b10;
    let mut s11 = a11 + b11;
    let mut s12 = 0i64;

    let carry0 = (s0 + (1 << 20)) >> 21;
    s1 += carry0;
    s0 -= carry0 << 21;
    let carry2 = (s2 + (1 << 20)) >> 21;
    s3 += carry2;
    s2 -= carry2 << 21;
    let carry4 = (s4 + (1 << 20)) >> 21;
    s5 += carry4;
    s4 -= carry4 << 21;
    let carry6 = (s6 + (1 << 20)) >> 21;
    s7 += carry6;
    s6 -= carry6 << 21;
    let carry8 = (s8 + (1 << 20)) >> 21;
    s9 += carry8;
    s8 -= carry8 << 21;
    let carry10 = (s10 + (1 << 20)) >> 21;
    s11 += carry10;
    s10 -= carry10 << 21;

    let carry1 = (s1 + (1 << 20)) >> 21;
    s2 += carry1;
    s1 -= carry1 << 21;
    let carry3 = (s3 + (1 << 20)) >> 21;
    s4 += carry3;
    s3 -= carry3 << 21;
    let carry5 = (s5 + (1 << 20)) >> 21;
    s6 += carry5;
    s5 -= carry5 << 21;
    let carry7 = (s7 + (1 << 20)) >> 21;
    s8 += carry7;
    s7 -= carry7 << 21;
    let carry9 = (s9 + (1 << 20)) >> 21;
    s10 += carry9;
    s9 -= carry9 << 21;
    let carry11 = (s11 + (1 << 20)) >> 21;
    s12 += carry11;
    s11 -= carry11 << 21;

    s0 += s12 * 666643;
    s1 += s12 * 470296;
    s2 += s12 * 654183;
    s3 -= s12 * 997805;
    s4 += s12 * 136657;
    s5 -= s12 * 683901;
    s12 = 0;

    let carry0 = s0 >> 21;
    s1 += carry0;
    s0 -= carry0 << 21;
    let carry1 = s1 >> 21;
    s2 += carry1;
    s1 -= carry1 << 21;
    let carry2 = s2 >> 21;
    s3 += carry2;
    s2 -= carry2 << 21;
    let carry3 = s3 >> 21;
    s4 += carry3;
    s3 -= carry3 << 21;
    let carry4 = s4 >> 21;
    s5 += carry4;
    s4 -= carry4 << 21;
    let carry5 = s5 >> 21;
    s6 += carry5;
    s5 -= carry5 << 21;
    let carry6 = s6 >> 21;
    s7 += carry6;
    s6 -= carry6 << 21;
    let carry7 = s7 >> 21;
    s8 += carry7;
    s7 -= carry7 << 21;
    let carry8 = s8 >> 21;
    s9 += carry8;
    s8 -= carry8 << 21;
    let carry9 = s9 >> 21;
    s10 += carry9;
    s9 -= carry9 << 21;
    let carry10 = s10 >> 21;
    s11 += carry10;
    s10 -= carry10 << 21;
    let carry11 = s11 >> 21;
    s12 += carry11;
    s11 -= carry11 << 21;

    s0 += s12 * 666643;
    s1 += s12 * 470296;
    s2 += s12 * 654183;
    s3 -= s12 * 997805;
    s4 += s12 * 136657;
    s5 -= s12 * 683901;

    let carry0 = s0 >> 21;
    s1 += carry0;
    s0 -= carry0 << 21;
    let carry1 = s1 >> 21;
    s2 += carry1;
    s1 -= carry1 << 21;
    let carry2 = s2 >> 21;
    s3 += carry2;
    s2 -= carry2 << 21;
    let carry3 = s3 >> 21;
    s4 += carry3;
    s3 -= carry3 << 21;
    let carry4 = s4 >> 21;
    s5 += carry4;
    s4 -= carry4 << 21;
    let carry5 = s5 >> 21;
    s6 += carry5;
    s5 -= carry5 << 21;
    let carry6 = s6 >> 21;
    s7 += carry6;
    s6 -= carry6 << 21;
    let carry7 = s7 >> 21;
    s8 += carry7;
    s7 -= carry7 << 21;
    let carry8 = s8 >> 21;
    s9 += carry8;
    s8 -= carry8 << 21;
    let carry9 = s9 >> 21;
    s10 += carry9;
    s9 -= carry9 << 21;
    let carry10 = s10 >> 21;
    s11 += carry10;
    s10 -= carry10 << 21;

    s[0] = (s0 >> 0) as u8;
    s[1] = (s0 >> 8) as u8;
    s[2] = ((s0 >> 16) | (s1 << 5)) as u8;
    s[3] = (s1 >> 3) as u8;
    s[4] = (s1 >> 11) as u8;
    s[5] = ((s1 >> 19) | (s2 << 2)) as u8;
    s[6] = (s2 >> 6) as u8;
    s[7] = ((s2 >> 14) | (s3 << 7)) as u8;
    s[8] = (s3 >> 1) as u8;
    s[9] = (s3 >> 9) as u8;
    s[10] = ((s3 >> 17) | (s4 << 4)) as u8;
    s[11] = (s4 >> 4) as u8;
    s[12] = (s4 >> 12) as u8;
    s[13] = ((s4 >> 20) | (s5 << 1)) as u8;
    s[14] = (s5 >> 7) as u8;
    s[15] = ((s5 >> 15) | (s6 << 6)) as u8;
    s[16] = (s6 >> 2) as u8;
    s[17] = (s6 >> 10) as u8;
    s[18] = ((s6 >> 18) | (s7 << 3)) as u8;
    s[19] = (s7 >> 5) as u8;
    s[20] = (s7 >> 13) as u8;
    s[21] = (s8 >> 0) as u8;
    s[22] = (s8 >> 8) as u8;
    s[23] = ((s8 >> 16) | (s9 << 5)) as u8;
    s[24] = (s9 >> 3) as u8;
    s[25] = (s9 >> 11) as u8;
    s[26] = ((s9 >> 19) | (s10 << 2)) as u8;
    s[27] = (s10 >> 6) as u8;
    s[28] = ((s10 >> 14) | (s11 << 7)) as u8;
    s[29] = (s11 >> 1) as u8;
    s[30] = (s11 >> 9) as u8;
    s[31] = (s11 >> 17) as u8;
}

pub fn sc_sub(s: &mut [u8; 32], a: &[u8; 32], b: &[u8; 32]) {
    let mut a0 = (2097151 & load_3(a)) as i64;
    let mut a1 = (2097151 & (load_4(&a[2..]) >> 5)) as i64;
    let mut a2 = (2097151 & (load_3(&a[5..]) >> 2)) as i64;
    let mut a3 = (2097151 & (load_4(&a[7..]) >> 7)) as i64;
    let mut a4 = (2097151 & (load_4(&a[10..]) >> 4)) as i64;
    let mut a5 = (2097151 & (load_3(&a[13..]) >> 1)) as i64;
    let mut a6 = (2097151 & (load_4(&a[15..]) >> 6)) as i64;
    let mut a7 = (2097151 & (load_3(&a[18..]) >> 3)) as i64;
    let mut a8 = (2097151 & load_3(&a[21..])) as i64;
    let mut a9 = (2097151 & (load_4(&a[23..]) >> 5)) as i64;
    let mut a10 = (2097151 & (load_3(&a[26..]) >> 2)) as i64;
    let mut a11 = (load_4(&a[28..]) >> 7) as i64;
    let mut b0 = (2097151 & load_3(b)) as i64;
    let mut b1 = (2097151 & (load_4(&b[2..]) >> 5)) as i64;
    let mut b2 = (2097151 & (load_3(&b[5..]) >> 2)) as i64;
    let mut b3 = (2097151 & (load_4(&b[7..]) >> 7)) as i64;
    let mut b4 = (2097151 & (load_4(&b[10..]) >> 4)) as i64;
    let mut b5 = (2097151 & (load_3(&b[13..]) >> 1)) as i64;
    let mut b6 = (2097151 & (load_4(&b[15..]) >> 6)) as i64;
    let mut b7 = (2097151 & (load_3(&b[18..]) >> 3)) as i64;
    let mut b8 = (2097151 & load_3(&b[21..])) as i64;
    let mut b9 = (2097151 & (load_4(&b[23..]) >> 5)) as i64;
    let mut b10 = (2097151 & (load_3(&b[26..]) >> 2)) as i64;
    let mut b11 = (load_4(&b[28..]) >> 7) as i64;
    let mut s0 = a0 - b0;
    let mut s1 = a1 - b1;
    let mut s2 = a2 - b2;
    let mut s3 = a3 - b3;
    let mut s4 = a4 - b4;
    let mut s5 = a5 - b5;
    let mut s6 = a6 - b6;
    let mut s7 = a7 - b7;
    let mut s8 = a8 - b8;
    let mut s9 = a9 - b9;
    let mut s10 = a10 - b10;
    let mut s11 = a11 - b11;
    let mut s12 = 0i64;

    let carry0 = (s0 + (1 << 20)) >> 21;
    s1 += carry0;
    s0 -= carry0 << 21;
    let carry2 = (s2 + (1 << 20)) >> 21;
    s3 += carry2;
    s2 -= carry2 << 21;
    let carry4 = (s4 + (1 << 20)) >> 21;
    s5 += carry4;
    s4 -= carry4 << 21;
    let carry6 = (s6 + (1 << 20)) >> 21;
    s7 += carry6;
    s6 -= carry6 << 21;
    let carry8 = (s8 + (1 << 20)) >> 21;
    s9 += carry8;
    s8 -= carry8 << 21;
    let carry10 = (s10 + (1 << 20)) >> 21;
    s11 += carry10;
    s10 -= carry10 << 21;

    let carry1 = (s1 + (1 << 20)) >> 21;
    s2 += carry1;
    s1 -= carry1 << 21;
    let carry3 = (s3 + (1 << 20)) >> 21;
    s4 += carry3;
    s3 -= carry3 << 21;
    let carry5 = (s5 + (1 << 20)) >> 21;
    s6 += carry5;
    s5 -= carry5 << 21;
    let carry7 = (s7 + (1 << 20)) >> 21;
    s8 += carry7;
    s7 -= carry7 << 21;
    let carry9 = (s9 + (1 << 20)) >> 21;
    s10 += carry9;
    s9 -= carry9 << 21;
    let carry11 = (s11 + (1 << 20)) >> 21;
    s12 += carry11;
    s11 -= carry11 << 21;

    s0 += s12 * 666643;
    s1 += s12 * 470296;
    s2 += s12 * 654183;
    s3 -= s12 * 997805;
    s4 += s12 * 136657;
    s5 -= s12 * 683901;
    s12 = 0;

    let carry0 = s0 >> 21;
    s1 += carry0;
    s0 -= carry0 << 21;
    let carry1 = s1 >> 21;
    s2 += carry1;
    s1 -= carry1 << 21;
    let carry2 = s2 >> 21;
    s3 += carry2;
    s2 -= carry2 << 21;
    let carry3 = s3 >> 21;
    s4 += carry3;
    s3 -= carry3 << 21;
    let carry4 = s4 >> 21;
    s5 += carry4;
    s4 -= carry4 << 21;
    let carry5 = s5 >> 21;
    s6 += carry5;
    s5 -= carry5 << 21;
    let carry6 = s6 >> 21;
    s7 += carry6;
    s6 -= carry6 << 21;
    let carry7 = s7 >> 21;
    s8 += carry7;
    s7 -= carry7 << 21;
    let carry8 = s8 >> 21;
    s9 += carry8;
    s8 -= carry8 << 21;
    let carry9 = s9 >> 21;
    s10 += carry9;
    s9 -= carry9 << 21;
    let carry10 = s10 >> 21;
    s11 += carry10;
    s10 -= carry10 << 21;
    let carry11 = s11 >> 21;
    s12 += carry11;
    s11 -= carry11 << 21;

    s0 += s12 * 666643;
    s1 += s12 * 470296;
    s2 += s12 * 654183;
    s3 -= s12 * 997805;
    s4 += s12 * 136657;
    s5 -= s12 * 683901;

    let carry0 = s0 >> 21;
    s1 += carry0;
    s0 -= carry0 << 21;
    let carry1 = s1 >> 21;
    s2 += carry1;
    s1 -= carry1 << 21;
    let carry2 = s2 >> 21;
    s3 += carry2;
    s2 -= carry2 << 21;
    let carry3 = s3 >> 21;
    s4 += carry3;
    s3 -= carry3 << 21;
    let carry4 = s4 >> 21;
    s5 += carry4;
    s4 -= carry4 << 21;
    let carry5 = s5 >> 21;
    s6 += carry5;
    s5 -= carry5 << 21;
    let carry6 = s6 >> 21;
    s7 += carry6;
    s6 -= carry6 << 21;
    let carry7 = s7 >> 21;
    s8 += carry7;
    s7 -= carry7 << 21;
    let carry8 = s8 >> 21;
    s9 += carry8;
    s8 -= carry8 << 21;
    let carry9 = s9 >> 21;
    s10 += carry9;
    s9 -= carry9 << 21;
    let carry10 = s10 >> 21;
    s11 += carry10;
    s10 -= carry10 << 21;

    s[0] = (s0 >> 0) as u8;
    s[1] = (s0 >> 8) as u8;
    s[2] = ((s0 >> 16) | (s1 << 5)) as u8;
    s[3] = (s1 >> 3) as u8;
    s[4] = (s1 >> 11) as u8;
    s[5] = ((s1 >> 19) | (s2 << 2)) as u8;
    s[6] = (s2 >> 6) as u8;
    s[7] = ((s2 >> 14) | (s3 << 7)) as u8;
    s[8] = (s3 >> 1) as u8;
    s[9] = (s3 >> 9) as u8;
    s[10] = ((s3 >> 17) | (s4 << 4)) as u8;
    s[11] = (s4 >> 4) as u8;
    s[12] = (s4 >> 12) as u8;
    s[13] = ((s4 >> 20) | (s5 << 1)) as u8;
    s[14] = (s5 >> 7) as u8;
    s[15] = ((s5 >> 15) | (s6 << 6)) as u8;
    s[16] = (s6 >> 2) as u8;
    s[17] = (s6 >> 10) as u8;
    s[18] = ((s6 >> 18) | (s7 << 3)) as u8;
    s[19] = (s7 >> 5) as u8;
    s[20] = (s7 >> 13) as u8;
    s[21] = (s8 >> 0) as u8;
    s[22] = (s8 >> 8) as u8;
    s[23] = ((s8 >> 16) | (s9 << 5)) as u8;
    s[24] = (s9 >> 3) as u8;
    s[25] = (s9 >> 11) as u8;
    s[26] = ((s9 >> 19) | (s10 << 2)) as u8;
    s[27] = (s10 >> 6) as u8;
    s[28] = ((s10 >> 14) | (s11 << 7)) as u8;
    s[29] = (s11 >> 1) as u8;
    s[30] = (s11 >> 9) as u8;
    s[31] = (s11 >> 17) as u8;
}

/// s = (c - a*b) mod l
pub fn sc_mulsub(s: &mut [u8; 32], a: &[u8; 32], b: &[u8; 32], c: &[u8; 32]) {
    let a0 = (2097151 & load_3(a)) as i64;
    let a1 = (2097151 & (load_4(&a[2..]) >> 5)) as i64;
    let a2 = (2097151 & (load_3(&a[5..]) >> 2)) as i64;
    let a3 = (2097151 & (load_4(&a[7..]) >> 7)) as i64;
    let a4 = (2097151 & (load_4(&a[10..]) >> 4)) as i64;
    let a5 = (2097151 & (load_3(&a[13..]) >> 1)) as i64;
    let a6 = (2097151 & (load_4(&a[15..]) >> 6)) as i64;
    let a7 = (2097151 & (load_3(&a[18..]) >> 3)) as i64;
    let a8 = (2097151 & load_3(&a[21..])) as i64;
    let a9 = (2097151 & (load_4(&a[23..]) >> 5)) as i64;
    let a10 = (2097151 & (load_3(&a[26..]) >> 2)) as i64;
    let a11 = (load_4(&a[28..]) >> 7) as i64;
    let b0 = (2097151 & load_3(b)) as i64;
    let b1 = (2097151 & (load_4(&b[2..]) >> 5)) as i64;
    let b2 = (2097151 & (load_3(&b[5..]) >> 2)) as i64;
    let b3 = (2097151 & (load_4(&b[7..]) >> 7)) as i64;
    let b4 = (2097151 & (load_4(&b[10..]) >> 4)) as i64;
    let b5 = (2097151 & (load_3(&b[13..]) >> 1)) as i64;
    let b6 = (2097151 & (load_4(&b[15..]) >> 6)) as i64;
    let b7 = (2097151 & (load_3(&b[18..]) >> 3)) as i64;
    let b8 = (2097151 & load_3(&b[21..])) as i64;
    let b9 = (2097151 & (load_4(&b[23..]) >> 5)) as i64;
    let b10 = (2097151 & (load_3(&b[26..]) >> 2)) as i64;
    let b11 = (load_4(&b[28..]) >> 7) as i64;
    let c0 = (2097151 & load_3(c)) as i64;
    let c1 = (2097151 & (load_4(&c[2..]) >> 5)) as i64;
    let c2 = (2097151 & (load_3(&c[5..]) >> 2)) as i64;
    let c3 = (2097151 & (load_4(&c[7..]) >> 7)) as i64;
    let c4 = (2097151 & (load_4(&c[10..]) >> 4)) as i64;
    let c5 = (2097151 & (load_3(&c[13..]) >> 1)) as i64;
    let c6 = (2097151 & (load_4(&c[15..]) >> 6)) as i64;
    let c7 = (2097151 & (load_3(&c[18..]) >> 3)) as i64;
    let c8 = (2097151 & load_3(&c[21..])) as i64;
    let c9 = (2097151 & (load_4(&c[23..]) >> 5)) as i64;
    let c10 = (2097151 & (load_3(&c[26..]) >> 2)) as i64;
    let c11 = (load_4(&c[28..]) >> 7) as i64;
    let mut s0;
    let mut s1;
    let mut s2;
    let mut s3;
    let mut s4;
    let mut s5;
    let mut s6;
    let mut s7;
    let mut s8;
    let mut s9;
    let mut s10;
    let mut s11;
    let mut s12;
    let mut s13;
    let mut s14;
    let mut s15;
    let mut s16;
    let mut s17;
    let mut s18;
    let mut s19;
    let mut s20;
    let mut s21;
    let mut s22;
    let mut s23;

    s0 = c0 - a0 * b0;
    s1 = c1 - (a0 * b1 + a1 * b0);
    s2 = c2 - (a0 * b2 + a1 * b1 + a2 * b0);
    s3 = c3 - (a0 * b3 + a1 * b2 + a2 * b1 + a3 * b0);
    s4 = c4 - (a0 * b4 + a1 * b3 + a2 * b2 + a3 * b1 + a4 * b0);
    s5 = c5 - (a0 * b5 + a1 * b4 + a2 * b3 + a3 * b2 + a4 * b1 + a5 * b0);
    s6 = c6 - (a0 * b6 + a1 * b5 + a2 * b4 + a3 * b3 + a4 * b2 + a5 * b1 + a6 * b0);
    s7 = c7 - (a0 * b7 + a1 * b6 + a2 * b5 + a3 * b4 + a4 * b3 + a5 * b2 + a6 * b1 + a7 * b0);
    s8 = c8 - (a0 * b8 + a1 * b7 + a2 * b6 + a3 * b5 + a4 * b4 + a5 * b3 + a6 * b2 + a7 * b1 + a8 * b0);
    s9 = c9 - (a0 * b9 + a1 * b8 + a2 * b7 + a3 * b6 + a4 * b5 + a5 * b4 + a6 * b3 + a7 * b2 + a8 * b1 + a9 * b0);
    s10 = c10 - (a0 * b10 + a1 * b9 + a2 * b8 + a3 * b7 + a4 * b6 + a5 * b5 + a6 * b4 + a7 * b3 + a8 * b2 + a9 * b1 + a10 * b0);
    s11 = c11 - (a0 * b11 + a1 * b10 + a2 * b9 + a3 * b8 + a4 * b7 + a5 * b6 + a6 * b5 + a7 * b4 + a8 * b3 + a9 * b2 + a10 * b1 + a11 * b0);
    s12 = -(a1 * b11 + a2 * b10 + a3 * b9 + a4 * b8 + a5 * b7 + a6 * b6 + a7 * b5 + a8 * b4 + a9 * b3 + a10 * b2 + a11 * b1);
    s13 = -(a2 * b11 + a3 * b10 + a4 * b9 + a5 * b8 + a6 * b7 + a7 * b6 + a8 * b5 + a9 * b4 + a10 * b3 + a11 * b2);
    s14 = -(a3 * b11 + a4 * b10 + a5 * b9 + a6 * b8 + a7 * b7 + a8 * b6 + a9 * b5 + a10 * b4 + a11 * b3);
    s15 = -(a4 * b11 + a5 * b10 + a6 * b9 + a7 * b8 + a8 * b7 + a9 * b6 + a10 * b5 + a11 * b4);
    s16 = -(a5 * b11 + a6 * b10 + a7 * b9 + a8 * b8 + a9 * b7 + a10 * b6 + a11 * b5);
    s17 = -(a6 * b11 + a7 * b10 + a8 * b9 + a9 * b8 + a10 * b7 + a11 * b6);
    s18 = -(a7 * b11 + a8 * b10 + a9 * b9 + a10 * b8 + a11 * b7);
    s19 = -(a8 * b11 + a9 * b10 + a10 * b9 + a11 * b8);
    s20 = -(a9 * b11 + a10 * b10 + a11 * b9);
    s21 = -(a10 * b11 + a11 * b10);
    s22 = -a11 * b11;
    s23 = 0;

    let carry0 = (s0 + (1 << 20)) >> 21;
    s1 += carry0;
    s0 -= carry0 << 21;
    let carry2 = (s2 + (1 << 20)) >> 21;
    s3 += carry2;
    s2 -= carry2 << 21;
    let carry4 = (s4 + (1 << 20)) >> 21;
    s5 += carry4;
    s4 -= carry4 << 21;
    let carry6 = (s6 + (1 << 20)) >> 21;
    s7 += carry6;
    s6 -= carry6 << 21;
    let carry8 = (s8 + (1 << 20)) >> 21;
    s9 += carry8;
    s8 -= carry8 << 21;
    let carry10 = (s10 + (1 << 20)) >> 21;
    s11 += carry10;
    s10 -= carry10 << 21;
    let carry12 = (s12 + (1 << 20)) >> 21;
    s13 += carry12;
    s12 -= carry12 << 21;
    let carry14 = (s14 + (1 << 20)) >> 21;
    s15 += carry14;
    s14 -= carry14 << 21;
    let carry16 = (s16 + (1 << 20)) >> 21;
    s17 += carry16;
    s16 -= carry16 << 21;
    let carry18 = (s18 + (1 << 20)) >> 21;
    s19 += carry18;
    s18 -= carry18 << 21;
    let carry20 = (s20 + (1 << 20)) >> 21;
    s21 += carry20;
    s20 -= carry20 << 21;
    let carry22 = (s22 + (1 << 20)) >> 21;
    s23 += carry22;
    s22 -= carry22 << 21;

    let carry1 = (s1 + (1 << 20)) >> 21;
    s2 += carry1;
    s1 -= carry1 << 21;
    let carry3 = (s3 + (1 << 20)) >> 21;
    s4 += carry3;
    s3 -= carry3 << 21;
    let carry5 = (s5 + (1 << 20)) >> 21;
    s6 += carry5;
    s5 -= carry5 << 21;
    let carry7 = (s7 + (1 << 20)) >> 21;
    s8 += carry7;
    s7 -= carry7 << 21;
    let carry9 = (s9 + (1 << 20)) >> 21;
    s10 += carry9;
    s9 -= carry9 << 21;
    let carry11 = (s11 + (1 << 20)) >> 21;
    s12 += carry11;
    s11 -= carry11 << 21;
    let carry13 = (s13 + (1 << 20)) >> 21;
    s14 += carry13;
    s13 -= carry13 << 21;
    let carry15 = (s15 + (1 << 20)) >> 21;
    s16 += carry15;
    s15 -= carry15 << 21;
    let carry17 = (s17 + (1 << 20)) >> 21;
    s18 += carry17;
    s17 -= carry17 << 21;
    let carry19 = (s19 + (1 << 20)) >> 21;
    s20 += carry19;
    s19 -= carry19 << 21;
    let carry21 = (s21 + (1 << 20)) >> 21;
    s22 += carry21;
    s21 -= carry21 << 21;

    s11 += s23 * 666643;
    s12 += s23 * 470296;
    s13 += s23 * 654183;
    s14 -= s23 * 997805;
    s15 += s23 * 136657;
    s16 -= s23 * 683901;

    s10 += s22 * 666643;
    s11 += s22 * 470296;
    s12 += s22 * 654183;
    s13 -= s22 * 997805;
    s14 += s22 * 136657;
    s15 -= s22 * 683901;

    s9 += s21 * 666643;
    s10 += s21 * 470296;
    s11 += s21 * 654183;
    s12 -= s21 * 997805;
    s13 += s21 * 136657;
    s14 -= s21 * 683901;

    s8 += s20 * 666643;
    s9 += s20 * 470296;
    s10 += s20 * 654183;
    s11 -= s20 * 997805;
    s12 += s20 * 136657;
    s13 -= s20 * 683901;

    s7 += s19 * 666643;
    s8 += s19 * 470296;
    s9 += s19 * 654183;
    s10 -= s19 * 997805;
    s11 += s19 * 136657;
    s12 -= s19 * 683901;

    s6 += s18 * 666643;
    s7 += s18 * 470296;
    s8 += s18 * 654183;
    s9 -= s18 * 997805;
    s10 += s18 * 136657;
    s11 -= s18 * 683901;

    let carry6 = (s6 + (1 << 20)) >> 21;
    s7 += carry6;
    s6 -= carry6 << 21;
    let carry8 = (s8 + (1 << 20)) >> 21;
    s9 += carry8;
    s8 -= carry8 << 21;
    let carry10 = (s10 + (1 << 20)) >> 21;
    s11 += carry10;
    s10 -= carry10 << 21;
    let carry12 = (s12 + (1 << 20)) >> 21;
    s13 += carry12;
    s12 -= carry12 << 21;
    let carry14 = (s14 + (1 << 20)) >> 21;
    s15 += carry14;
    s14 -= carry14 << 21;
    let carry16 = (s16 + (1 << 20)) >> 21;
    s17 += carry16;
    s16 -= carry16 << 21;

    let carry7 = (s7 + (1 << 20)) >> 21;
    s8 += carry7;
    s7 -= carry7 << 21;
    let carry9 = (s9 + (1 << 20)) >> 21;
    s10 += carry9;
    s9 -= carry9 << 21;
    let carry11 = (s11 + (1 << 20)) >> 21;
    s12 += carry11;
    s11 -= carry11 << 21;
    let carry13 = (s13 + (1 << 20)) >> 21;
    s14 += carry13;
    s13 -= carry13 << 21;
    let carry15 = (s15 + (1 << 20)) >> 21;
    s16 += carry15;
    s15 -= carry15 << 21;

    s5 += s17 * 666643;
    s6 += s17 * 470296;
    s7 += s17 * 654183;
    s8 -= s17 * 997805;
    s9 += s17 * 136657;
    s10 -= s17 * 683901;

    s4 += s16 * 666643;
    s5 += s16 * 470296;
    s6 += s16 * 654183;
    s7 -= s16 * 997805;
    s8 += s16 * 136657;
    s9 -= s16 * 683901;

    s3 += s15 * 666643;
    s4 += s15 * 470296;
    s5 += s15 * 654183;
    s6 -= s15 * 997805;
    s7 += s15 * 136657;
    s8 -= s15 * 683901;

    s2 += s14 * 666643;
    s3 += s14 * 470296;
    s4 += s14 * 654183;
    s5 -= s14 * 997805;
    s6 += s14 * 136657;
    s7 -= s14 * 683901;

    s1 += s13 * 666643;
    s2 += s13 * 470296;
    s3 += s13 * 654183;
    s4 -= s13 * 997805;
    s5 += s13 * 136657;
    s6 -= s13 * 683901;

    s0 += s12 * 666643;
    s1 += s12 * 470296;
    s2 += s12 * 654183;
    s3 -= s12 * 997805;
    s4 += s12 * 136657;
    s5 -= s12 * 683901;
    s12 = 0;

    let carry0 = (s0 + (1 << 20)) >> 21;
    s1 += carry0;
    s0 -= carry0 << 21;
    let carry2 = (s2 + (1 << 20)) >> 21;
    s3 += carry2;
    s2 -= carry2 << 21;
    let carry4 = (s4 + (1 << 20)) >> 21;
    s5 += carry4;
    s4 -= carry4 << 21;
    let carry6 = (s6 + (1 << 20)) >> 21;
    s7 += carry6;
    s6 -= carry6 << 21;
    let carry8 = (s8 + (1 << 20)) >> 21;
    s9 += carry8;
    s8 -= carry8 << 21;
    let carry10 = (s10 + (1 << 20)) >> 21;
    s11 += carry10;
    s10 -= carry10 << 21;

    let carry1 = (s1 + (1 << 20)) >> 21;
    s2 += carry1;
    s1 -= carry1 << 21;
    let carry3 = (s3 + (1 << 20)) >> 21;
    s4 += carry3;
    s3 -= carry3 << 21;
    let carry5 = (s5 + (1 << 20)) >> 21;
    s6 += carry5;
    s5 -= carry5 << 21;
    let carry7 = (s7 + (1 << 20)) >> 21;
    s8 += carry7;
    s7 -= carry7 << 21;
    let carry9 = (s9 + (1 << 20)) >> 21;
    s10 += carry9;
    s9 -= carry9 << 21;
    let carry11 = (s11 + (1 << 20)) >> 21;
    s12 += carry11;
    s11 -= carry11 << 21;

    s0 += s12 * 666643;
    s1 += s12 * 470296;
    s2 += s12 * 654183;
    s3 -= s12 * 997805;
    s4 += s12 * 136657;
    s5 -= s12 * 683901;
    s12 = 0;

    let carry0 = s0 >> 21;
    s1 += carry0;
    s0 -= carry0 << 21;
    let carry1 = s1 >> 21;
    s2 += carry1;
    s1 -= carry1 << 21;
    let carry2 = s2 >> 21;
    s3 += carry2;
    s2 -= carry2 << 21;
    let carry3 = s3 >> 21;
    s4 += carry3;
    s3 -= carry3 << 21;
    let carry4 = s4 >> 21;
    s5 += carry4;
    s4 -= carry4 << 21;
    let carry5 = s5 >> 21;
    s6 += carry5;
    s5 -= carry5 << 21;
    let carry6 = s6 >> 21;
    s7 += carry6;
    s6 -= carry6 << 21;
    let carry7 = s7 >> 21;
    s8 += carry7;
    s7 -= carry7 << 21;
    let carry8 = s8 >> 21;
    s9 += carry8;
    s8 -= carry8 << 21;
    let carry9 = s9 >> 21;
    s10 += carry9;
    s9 -= carry9 << 21;
    let carry10 = s10 >> 21;
    s11 += carry10;
    s10 -= carry10 << 21;
    let carry11 = s11 >> 21;
    s12 += carry11;
    s11 -= carry11 << 21;

    s0 += s12 * 666643;
    s1 += s12 * 470296;
    s2 += s12 * 654183;
    s3 -= s12 * 997805;
    s4 += s12 * 136657;
    s5 -= s12 * 683901;

    let carry0 = s0 >> 21;
    s1 += carry0;
    s0 -= carry0 << 21;
    let carry1 = s1 >> 21;
    s2 += carry1;
    s1 -= carry1 << 21;
    let carry2 = s2 >> 21;
    s3 += carry2;
    s2 -= carry2 << 21;
    let carry3 = s3 >> 21;
    s4 += carry3;
    s3 -= carry3 << 21;
    let carry4 = s4 >> 21;
    s5 += carry4;
    s4 -= carry4 << 21;
    let carry5 = s5 >> 21;
    s6 += carry5;
    s5 -= carry5 << 21;
    let carry6 = s6 >> 21;
    s7 += carry6;
    s6 -= carry6 << 21;
    let carry7 = s7 >> 21;
    s8 += carry7;
    s7 -= carry7 << 21;
    let carry8 = s8 >> 21;
    s9 += carry8;
    s8 -= carry8 << 21;
    let carry9 = s9 >> 21;
    s10 += carry9;
    s9 -= carry9 << 21;
    let carry10 = s10 >> 21;
    s11 += carry10;
    s10 -= carry10 << 21;

    s[0] = (s0 >> 0) as u8;
    s[1] = (s0 >> 8) as u8;
    s[2] = ((s0 >> 16) | (s1 << 5)) as u8;
    s[3] = (s1 >> 3) as u8;
    s[4] = (s1 >> 11) as u8;
    s[5] = ((s1 >> 19) | (s2 << 2)) as u8;
    s[6] = (s2 >> 6) as u8;
    s[7] = ((s2 >> 14) | (s3 << 7)) as u8;
    s[8] = (s3 >> 1) as u8;
    s[9] = (s3 >> 9) as u8;
    s[10] = ((s3 >> 17) | (s4 << 4)) as u8;
    s[11] = (s4 >> 4) as u8;
    s[12] = (s4 >> 12) as u8;
    s[13] = ((s4 >> 20) | (s5 << 1)) as u8;
    s[14] = (s5 >> 7) as u8;
    s[15] = ((s5 >> 15) | (s6 << 6)) as u8;
    s[16] = (s6 >> 2) as u8;
    s[17] = (s6 >> 10) as u8;
    s[18] = ((s6 >> 18) | (s7 << 3)) as u8;
    s[19] = (s7 >> 5) as u8;
    s[20] = (s7 >> 13) as u8;
    s[21] = (s8 >> 0) as u8;
    s[22] = (s8 >> 8) as u8;
    s[23] = ((s8 >> 16) | (s9 << 5)) as u8;
    s[24] = (s9 >> 3) as u8;
    s[25] = (s9 >> 11) as u8;
    s[26] = ((s9 >> 19) | (s10 << 2)) as u8;
    s[27] = (s10 >> 6) as u8;
    s[28] = ((s10 >> 14) | (s11 << 7)) as u8;
    s[29] = (s11 >> 1) as u8;
    s[30] = (s11 >> 9) as u8;
    s[31] = (s11 >> 17) as u8;
}

fn signum(a: i64) -> i64 {
    (a >> 63) - ((-a) >> 63)
}

/// Returns true if the scalar is canonically reduced (0 <= s < l).
pub fn sc_check(s: &[u8; 32]) -> bool {
    let s0 = load_4(s) as i64;
    let s1 = load_4(&s[4..]) as i64;
    let s2 = load_4(&s[8..]) as i64;
    let s3 = load_4(&s[12..]) as i64;
    let s4 = load_4(&s[16..]) as i64;
    let s5 = load_4(&s[20..]) as i64;
    let s6 = load_4(&s[24..]) as i64;
    let s7 = load_4(&s[28..]) as i64;
    ((signum(1559614444 - s0)
        + (signum(1477600026 - s1) << 1)
        + (signum(2734136534 - s2) << 2)
        + (signum(350157278 - s3) << 3)
        + (signum(-s4) << 4)
        + (signum(-s5) << 5)
        + (signum(-s6) << 6)
        + (signum(268435456 - s7) << 7))
        >> 8) == 0
}

/// Does not normalize.
pub fn sc_isnonzero(s: &[u8; 32]) -> bool {
    let mut x = 0i32;
    for b in s.iter() {
        x |= *b as i32;
    }
    (((x - 1) >> 8) + 1) != 0
}

/// Uniformly random scalar mod l, equivalent to the C random_scalar
/// (64 random bytes reduced mod l).
pub fn random_scalar(rng: &mut impl rand::RngCore) -> [u8; 32] {
    let mut tmp = [0u8; 64];
    rng.fill_bytes(&mut tmp);
    sc_reduce(&mut tmp);
    let mut out = [0u8; 32];
    out.copy_from_slice(&tmp[..32]);
    out
}
