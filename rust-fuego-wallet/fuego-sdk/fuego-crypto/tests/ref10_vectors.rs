//! Gate G1: byte-exact cross-language vectors.
//!
//! The vectors in `data/vectors.txt` are produced by a C harness linked
//! against the production daemon sources (`crypto-ops.c`, `crypto-ops-data.c`,
//! `keccak.c`, `hash.c`, `crypto.cpp` from /Users/aejt/xfgo). Every ref10
//! function is compared byte-for-byte against the C output.

use fuego_crypto::ref10::*;
use fuego_crypto::ring::{
    check_ring_signature, cn_fast_hash, derive_public_key, derive_secret_key,
    generate_key_derivation, generate_key_image, hash_to_ec, hash_to_scalar,
};

fn hex_to_bytes(s: &str) -> Vec<u8> {
    (0..s.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&s[i..i + 2], 16).unwrap())
        .collect()
}

fn to32(v: &[u8]) -> [u8; 32] {
    let mut a = [0u8; 32];
    a.copy_from_slice(v);
    a
}

#[test]
fn ref10_vectors() {
    let data = include_str!("data/vectors.txt");
    let tokens: Vec<String> = data.split_whitespace().map(|s| s.to_string()).collect();
    let mut i = 0usize;
    let mut checked = 0usize;

    // state for derive_sec (shares derivation/index with preceding derive_pub)
    let mut last_derivation: Option<[u8; 32]> = None;
    let mut last_oi: Option<u64> = None;

    // ring state
    let mut ring_prefix = [0u8; 32];
    let mut ring_image = [0u8; 32];
    let mut ring_pubs: Vec<[u8; 32]> = Vec::new();
    let mut ring_sig: Vec<[u8; 64]> = Vec::new();

    while i < tokens.len() {
        let name = tokens[i].clone();
        i += 1;
        match name.as_str() {
            "V" => {
                let kind = tokens[i].clone();
                i += 1;
                let idx = tokens[i].clone();
                i += 1; // index parsed as string, unused
                let _ = idx;
                macro_rules! hx {
                    () => {{
                        let v = tokens[i].clone();
                        i += 1;
                        v
                    }};
                }
                match kind.as_str() {
                    "ring_prefix" => {
                        ring_prefix = to32(&hex_to_bytes(&idx));
                    }
                    "ring_image" => {
                        ring_image = to32(&hex_to_bytes(&idx));
                    }
                    "ring_pub" => {
                        let p = hex_to_bytes(&hx!());
                        ring_pubs.push(to32(&p));
                    }
                    "ring_sig" => {
                        let bytes = hex_to_bytes(&idx);
                        ring_sig.clear();
                        for chunk in bytes.chunks_exact(64) {
                            let mut sg = [0u8; 64];
                            sg.copy_from_slice(chunk);
                            ring_sig.push(sg);
                        }
                    }
                    "ring_check_valid" => {
                        let expect = idx;
                        let ok = check_ring_signature(&ring_prefix, &ring_image, &ring_pubs, &ring_sig);
                        assert_eq!(ok, expect == "1", "ring check valid");
                        // tampered: byte 77 flipped in the C harness
                        let mut tampered = ring_sig.clone();
                        tampered[1][13] ^= 0x01;
                        assert!(
                            !check_ring_signature(&ring_prefix, &ring_image, &ring_pubs, &tampered),
                            "ring check tampered"
                        );
                    }
                    "ring_check_tampered" => {
                        let expect = idx;
                        let mut tampered = ring_sig.clone();
                        tampered[1][13] ^= 0x01;
                        let ok = check_ring_signature(&ring_prefix, &ring_image, &ring_pubs, &tampered);
                        assert_eq!(ok, expect == "1", "ring check tampered C");
                    }
                    "fe_canon" => {
                        let a = to32(&hex_to_bytes(&hx!()));
                        let out = hex_to_bytes(&hx!());
                        let mut f = Fe::default();
                        fe_frombytes(&mut f, &a);
                        let mut b = [0u8; 32];
                        fe_tobytes(&mut b, f);
                        assert_eq!(b, out[..], "fe_canon");
                    }
                    "fe_mul" | "fe_add" | "fe_sub" | "fe_divpowm1" => {
                        let a = to32(&hex_to_bytes(&hx!()));
                        let b2 = to32(&hex_to_bytes(&hx!()));
                        let out = hex_to_bytes(&hx!());
                        let mut fa = Fe::default();
                        let mut fb = Fe::default();
                        let mut r = Fe::default();
                        fe_frombytes(&mut fa, &a);
                        fe_frombytes(&mut fb, &b2);
                        match kind.as_str() {
                            "fe_mul" => fe_mul(&mut r, fa, fb),
                            "fe_add" => fe_add(&mut r, fa, fb),
                            "fe_sub" => fe_sub(&mut r, fa, fb),
                            "fe_divpowm1" => fe_divpowm1(&mut r, fa, fb),
                            _ => unreachable!(),
                        }
                        let mut o = [0u8; 32];
                        fe_tobytes(&mut o, r);
                        assert_eq!(o, out[..], "{}", kind);
                    }
                    "fe_sq" | "fe_sq2" | "fe_invert" | "fe_neg" => {
                        let a = to32(&hex_to_bytes(&hx!()));
                        let out = hex_to_bytes(&hx!());
                        let mut fa = Fe::default();
                        let mut r = Fe::default();
                        fe_frombytes(&mut fa, &a);
                        match kind.as_str() {
                            "fe_sq" => fe_sq(&mut r, fa),
                            "fe_sq2" => fe_sq2(&mut r, fa),
                            "fe_invert" => fe_invert(&mut r, fa),
                            "fe_neg" => fe_neg(&mut r, fa),
                            _ => unreachable!(),
                        }
                        let mut o = [0u8; 32];
                        fe_tobytes(&mut o, r);
                        assert_eq!(o, out[..], "{}", kind);
                    }
                    "ge_base_mult" => {
                        let a = to32(&hex_to_bytes(&hx!()));
                        let out = hex_to_bytes(&hx!());
                        let mut p = GeP3::default();
                        ge_scalarmult_base(&mut p, &a);
                        let mut o = [0u8; 32];
                        ge_p3_tobytes(&mut o, &p);
                        assert_eq!(o, out[..], "ge_base_mult");
                    }
                    "ge_frombytes" => {
                        let a = to32(&hex_to_bytes(&hx!()));
                        let out = hex_to_bytes(&hx!());
                        let mut p = GeP3::default();
                        assert!(ge_frombytes_vartime(&mut p, &a), "ge_frombytes");
                        let mut o = [0u8; 32];
                        ge_p3_tobytes(&mut o, &p);
                        if o != out[..] {
                            eprintln!("ge_frombytes MISMATCH in={} got={} want={}", hex::encode(a), hex::encode(o), hex::encode(&out));
                            panic!("ge_frombytes");
                        }
                    }
                    "ge_scalarmult" => {
                        let s = to32(&hex_to_bytes(&hx!()));
                        let p = to32(&hex_to_bytes(&hx!()));
                        let out = hex_to_bytes(&hx!());
                        let mut p3 = GeP3::default();
                        assert!(ge_frombytes_vartime(&mut p3, &p));
                        let mut p2 = GeP2::default();
                        ge_scalarmult(&mut p2, &s, &p3);
                        let mut o = [0u8; 32];
                        ge_tobytes(&mut o, &p2);
                        assert_eq!(o, out[..], "ge_scalarmult");
                    }
                    "ge_dsm_base" | "ge_dsm_precomp" => {
                        let s1 = to32(&hex_to_bytes(&hx!()));
                        let s2 = to32(&hex_to_bytes(&hx!()));
                        let p = to32(&hex_to_bytes(&hx!()));
                        let out = hex_to_bytes(&hx!());
                        let mut p3 = GeP3::default();
                        assert!(ge_frombytes_vartime(&mut p3, &p));
                        let mut p2 = GeP2::default();
                        if kind == "ge_dsm_base" {
                            ge_double_scalarmult_base_vartime(&mut p2, &s1, &p3, &s2);
                        } else {
                            let mut pre = [GeCached::default(); 8];
                            ge_dsm_precomp(&mut pre, &p3);
                            ge_double_scalarmult_precomp_vartime(&mut p2, &s1, &p3, &s2, &pre);
                        }
                        let mut o = [0u8; 32];
                        ge_tobytes(&mut o, &p2);
                        assert_eq!(o, out[..], "{}", kind);
                    }
                    "ge_mul8" => {
                        let p = to32(&hex_to_bytes(&hx!()));
                        let out = hex_to_bytes(&hx!());
                        let mut p3 = GeP3::default();
                        assert!(ge_frombytes_vartime(&mut p3, &p));
                        let mut p2 = GeP2::default();
                        ge_p3_to_p2(&mut p2, &p3);
                        let mut p11 = GeP1P1::default();
                        ge_mul8(&mut p11, &p2);
                        ge_p1p1_to_p2(&mut p2, &p11);
                        let mut o = [0u8; 32];
                        ge_tobytes(&mut o, &p2);
                        assert_eq!(o, out[..], "ge_mul8");
                    }
                    "hash_to_ec" => {
                        let a = to32(&hex_to_bytes(&hx!()));
                        let out = hex_to_bytes(&hx!());
                        let p = hash_to_ec(&a);
                        let mut o = [0u8; 32];
                        ge_p3_tobytes(&mut o, &p);
                        assert_eq!(o, out[..], "hash_to_ec");
                    }
                    "key_image" => {
                        let p = to32(&hex_to_bytes(&hx!()));
                        let s = to32(&hex_to_bytes(&hx!()));
                        let out = hex_to_bytes(&hx!());
                        let o = generate_key_image(&p, &s);
                        assert_eq!(o, out[..], "key_image");
                    }
                    "sc_reduce32" => {
                        let a = to32(&hex_to_bytes(&hx!()));
                        let out = hex_to_bytes(&hx!());
                        let mut s = a;
                        sc_reduce32(&mut s);
                        assert_eq!(s, out[..], "sc_reduce32");
                    }
                    "sc_add" | "sc_sub" => {
                        let a = to32(&hex_to_bytes(&hx!()));
                        let b = to32(&hex_to_bytes(&hx!()));
                        let out = hex_to_bytes(&hx!());
                        let mut s = [0u8; 32];
                        if kind == "sc_add" {
                            sc_add(&mut s, &a, &b);
                        } else {
                            sc_sub(&mut s, &a, &b);
                        }
                        assert_eq!(s, out[..], "{}", kind);
                    }
                    "sc_mulsub" => {
                        let a = to32(&hex_to_bytes(&hx!()));
                        let b = to32(&hex_to_bytes(&hx!()));
                        let c = to32(&hex_to_bytes(&hx!()));
                        let out = hex_to_bytes(&hx!());
                        let mut s = [0u8; 32];
                        sc_mulsub(&mut s, &a, &b, &c);
                        assert_eq!(s, out[..], "sc_mulsub");
                    }
                    "sc_check" => {
                        let a = to32(&hex_to_bytes(&hx!()));
                        let expect = tokens[i].clone();
                        i += 1;
                        assert_eq!(sc_check(&a), expect == "0", "sc_check");
                    }
                    "sc_isnonzero" => {
                        let a = to32(&hex_to_bytes(&hx!()));
                        let expect = tokens[i].clone();
                        i += 1;
                        assert_eq!(sc_isnonzero(&a), expect == "1", "sc_isnonzero");
                    }
                    "hash_to_scalar" => {
                        let len: usize = tokens[i].parse().unwrap();
                        i += 1;
                        let data = hex_to_bytes(&hx!());
                        assert_eq!(data.len(), len);
                        let out = hex_to_bytes(&hx!());
                        assert_eq!(hash_to_scalar(&data), out[..], "hash_to_scalar");
                    }
                    "key_derivation" => {
                        let p1 = to32(&hex_to_bytes(&hx!()));
                        let s = to32(&hex_to_bytes(&hx!()));
                        let out = hex_to_bytes(&hx!());
                        let d = generate_key_derivation(&p1, &s).expect("key_derivation");
                        assert_eq!(d, out[..], "key_derivation");
                        last_derivation = Some(d);
                    }
                    "derive_pub" => {
                        let oi: u64 = tokens[i].parse().unwrap();
                        i += 1;
                        let d = to32(&hex_to_bytes(&hx!()));
                        let base = to32(&hex_to_bytes(&hx!()));
                        let out = hex_to_bytes(&hx!());
                        let derived = derive_public_key(&d, oi, &base).expect("derive_pub");
                        assert_eq!(derived, out[..], "derive_pub");
                        last_derivation = Some(d);
                        last_oi = Some(oi);
                    }
                    "derive_sec" => {
                        let sec = to32(&hex_to_bytes(&hx!()));
                        let out = hex_to_bytes(&hx!());
                        let d = last_derivation.expect("derive_sec needs prior derive_pub");
                        let oi = last_oi.expect("derive_sec needs prior derive_pub");
                        if !sc_check(&sec) {
                            eprintln!("derive_sec INVALID sec={} d={} oi={}", hex::encode(sec), hex::encode(d), oi);
                        }
                        let derived = derive_secret_key(&d, oi, &sec).expect("derive_sec");
                        assert_eq!(derived, out[..], "derive_sec");
                    }
                    _ => panic!("unknown vector kind: {} at i={} (next: {})", kind, i, tokens.get(i).cloned().unwrap_or_default()),
                }
                checked += 1;
            }

            _ => panic!("unexpected token: {}", name),
        }
    }
    assert!(checked > 500, "expected many vectors, got {}", checked);
}

#[test]
fn cn_fast_hash_matches_c() {
    // Empty-input keccak, same constant used by the daemon's keccak1600.
    let h = cn_fast_hash(b"");
    assert_eq!(
        hex::encode(h),
        "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"
    );
}

#[test]
fn hash_to_scalar_via_varint_matches_derivation() {
    // derivation_to_scalar path: derivation || varint(index)
    let derivation = [7u8; 32];
    let mut buf = Vec::new();
    buf.extend_from_slice(&derivation);
    fuego_crypto::ring::write_varint(300, &mut buf);
    let s = hash_to_scalar(&buf);
    assert!(sc_check(&s));
}

#[test]
fn rust_generated_ring_vector() {
    use rand::rngs::StdRng;
    use rand::SeedableRng;
    use fuego_crypto::ring::{generate_key_image, generate_ring_signature, check_ring_signature};
    use fuego_crypto::ref10::{ge_p3_tobytes, ge_scalarmult_base, GeP3, random_scalar};

    let mut rng = StdRng::seed_from_u64(0x1234_5678_9abc_def0);
    let mut secs = [[0u8; 32]; 5];
    let mut pubs = [[0u8; 32]; 5];
    for k in 0..5 {
        secs[k] = random_scalar(&mut rng);
        let mut p = GeP3::default();
        ge_scalarmult_base(&mut p, &secs[k]);
        ge_p3_tobytes(&mut pubs[k], &p);
    }
    let mut prefix = [0u8; 32];
    for b in prefix.iter_mut() { *b = random_scalar(&mut rng)[0]; }
    let image = generate_key_image(&pubs[1], &secs[1]);
    let sig = generate_ring_signature(&prefix, &image, &pubs, &secs[1], 1, &mut rng).unwrap();
    assert!(check_ring_signature(&prefix, &image, &pubs, &sig));
    // These exact bytes were verified by the C daemon's check_ring_signature
    // (cross-language harness). Pinned so any drift in the ref10 port is
    // caught in CI.
    assert_eq!(hex::encode(prefix), "082844eeb5068c263cad30b5e76bfae526683208dfce2638283ac2ae778ab336");
    assert_eq!(hex::encode(image), "ba94a21b4bda4e7a5a5e3484a66aa08d2a6117f9d2faf3e4df5543d060cd9572");
    let flat: Vec<u8> = sig.iter().flatten().cloned().collect();
    assert_eq!(hex::encode(flat), "1d7f21956b554b9dd1185c8b18d1665cd218a255d010df66b2dd2121f40d6f0985a202c218fa602af57a89eed3c2ab54226036ea44a10603e2c48e2f00371f0e77215a992033dd7c2dca85510da92c65bfb2b6b6277c914aac865b62661495003932a7a66f8ad1eb764ac552b9e85dce87d1f46b37fbe864e9f7343e74874b0bd7d373d46f27b1148b979f51cef522ae6b213c220ed4771bb42a4de42c2c2a0e7653920de819b8a34a7e1c4b4ed710c059be92f22936abd3e98704362e210b0e216ca0fe6b4593b5b438318cd9bf68fd221541c425b831024a4d025997206c08252acc9a535aac216d1edc262cdca9f03621e05d8ad20089448801714be2410b38db14778ace2dc61fc1d2cad1e919827ef93693aa0b2901205485869b5e130bc07f61d31358717a1183b9a3f9b592a4406c639cf2d4a3b40a3c7ccf8fa95408");
}
