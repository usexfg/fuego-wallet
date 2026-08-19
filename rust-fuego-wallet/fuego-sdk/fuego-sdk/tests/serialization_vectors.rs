//! Gate G3: wire-format byte compatibility with the daemon's production
//! serializer (BinaryOutputStreamSerializer + CryptoNoteSerialization.cpp).
//! The golden hex below was produced by a C harness linked against the
//! daemon sources.

use fuego_sdk::serialization::{
    parse_prefix, serialize_prefix, serialize_tx, tx_prefix_hash, KeyInput, OutputTarget,
    Transaction, TransactionPrefix, TxInput, TxOutput,
};

fn key(start: u8) -> [u8; 32] {
    let mut k = [0u8; 32];
    for (i, b) in k.iter_mut().enumerate() {
        *b = start.wrapping_add(i as u8);
    }
    k
}

fn test_tx() -> Transaction {
    Transaction {
        prefix: TransactionPrefix {
            version: 1,
            unlock_time: 0,
            inputs: vec![
                TxInput::Key(KeyInput {
                    amount: 12345,
                    offsets: vec![17, 29, 1002, 1009],
                    key_image: key(0x01),
                }),
                TxInput::Key(KeyInput {
                    amount: 987654321,
                    offsets: vec![5],
                    key_image: key(0x21),
                }),
            ],
            outputs: vec![
                TxOutput { amount: 1_000_000, target: OutputTarget::Key(key(0x41)) },
                TxOutput { amount: 500_000, target: OutputTarget::Key(key(0x61)) },
            ],
            extra: {
                let mut e = vec![0x01u8];
                e.extend_from_slice(&key(0x81));
                e
            },
        },
        signatures: vec![
            {
                let mut sigs = Vec::new();
                for s in 0..4u8 {
                    let mut sig = [0u8; 64];
                    for i in 0..32 {
                        sig[i] = 0xa1u8.wrapping_add(s.wrapping_mul(3)).wrapping_add(i as u8);
                        sig[32 + i] = 0xc1u8.wrapping_add(s.wrapping_mul(3)).wrapping_add(i as u8);
                    }
                    sigs.push(sig);
                }
                sigs
            },
            {
                let mut sig = [0u8; 64];
                for i in 0..32 {
                    sig[i] = 0xe1u8.wrapping_add(i as u8);
                    sig[32 + i] = 0xf1u8.wrapping_add(i as u8);
                }
                vec![sig]
            },
        ],
    }
}

const GOLDEN_TX_HEX: &str = "01000202b96004110ccd07070102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f2002b1d1f9d60301052122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f4002c0843d024142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f60a0c21e026162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f8021018182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9fa0a1a2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3d4d5d6d7d8d9dadbdcdddedfe0a4a5a6a7a8a9aaabacadaeafb0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3d4d5d6d7d8d9dadbdcdddedfe0e1e2e3a7a8a9aaabacadaeafb0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3d4d5d6d7d8d9dadbdcdddedfe0e1e2e3e4e5e6aaabacadaeafb0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3d4d5d6d7d8d9dadbdcdddedfe0e1e2e3e4e5e6e7e8e9e1e2e3e4e5e6e7e8e9eaebecedeeeff0f1f2f3f4f5f6f7f8f9fafbfcfdfeff00f1f2f3f4f5f6f7f8f9fafbfcfdfeff000102030405060708090a0b0c0d0e0f10";

const GOLDEN_FULL_HASH: &str = "e308dba0935b42298e323955d079abd040082feb662951c926057c9be7e3bf60";
const GOLDEN_PREFIX_HASH: &str = "394f0177824f2ae5407b86accd30fa2c1320e1c233bcff74aa4e64230db8b836";

#[test]
fn tx_serialization_matches_cpp() {
    let tx = test_tx();
    let bytes = serialize_tx(&tx);
    assert_eq!(hex::encode(&bytes), GOLDEN_TX_HEX, "tx bytes must match C++");
    let ph = tx_prefix_hash(&tx.prefix);
    assert_eq!(hex::encode(ph), GOLDEN_PREFIX_HASH, "prefix hash must match C++");
    let full = fuego_crypto::cn_fast_hash(&bytes);
    assert_eq!(hex::encode(full), GOLDEN_FULL_HASH, "full tx hash must match C++");
}

#[test]
fn prefix_parse_roundtrip() {
    let tx = test_tx();
    let bytes = serialize_prefix(&tx.prefix);
    let parsed = parse_prefix(&bytes).expect("parse_prefix");
    assert_eq!(parsed, tx.prefix);
}

#[test]
fn offsets_roundtrip() {
    use fuego_sdk::serialization::{absolute_offsets_to_relative, relative_offsets_to_absolute};
    let abs = vec![17u32, 29, 1002, 1009];
    let rel = absolute_offsets_to_relative(&abs);
    assert_eq!(rel, vec![17, 12, 973, 7]);
    let back = relative_offsets_to_absolute(&rel).unwrap();
    assert_eq!(back, abs);
}
