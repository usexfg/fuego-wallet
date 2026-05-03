# Fuego SDK Build Status

## Latest Build Results

| Platform | Status | Artifacts |
|----------|--------|-----------|
| macOS ARM64 | ✅ Built | `libfuego_sdk.dylib` (99K) |
| Linux x64 | ⏳ Pending | `libfuego_sdk.so` |
| Windows x64 | ⏳ Pending | `fuego_sdk.dll` |
| Android ARM64 | ⏳ Pending | `libfuego_sdk.so` |
| iOS ARM64 | ⏳ Pending | `FuegoSDK.framework` |

**Build Date:** 2026-04-28  
**Compiler:** AppleClang 17.0.0  
**Boost:** 1.85.0

---

## Cryptographic Implementations

### Atomic Swaps - Adaptor Signatures (NOT HTLC)

Fuego uses **Adaptor Signatures** for atomic swaps, NOT HTLC:

| Component | Implementation | Source Files |
|-----------|---------------|--------------|
| **Adaptor Signatures** | Ed25519-based adaptor signatures | `src/crypto/adaptor.h/cpp` |
| **MuSig2** | 2-of-2 multi-signature scheme | `src/crypto/musig2.h/cpp` |
| **DLEQ Proofs** | Chaum-Pedersen discrete log equality | `src/crypto/dleq.h/cpp` |
| **Swap Protocol** | 10-step adaptor swap protocol | `src/SwapDaemon/AdaptorSwap.h/cpp` |

**Protocol Flow:**
1. Key Generation - Both parties generate Ed25519 swap keys
2. Key Aggregation - Compute MuSig2 joint escrow key P
3. Adaptor Point - Bob generates T=t*G with DLEQ proof
4. Adaptor Verify - Alice verifies Bob's DLEQ proof
5. Nonce Generation - Both generate MuSig2 per-session nonces
6. Session Init - Aggregate nonces, init with tx prefix hash
7. Partial Sign - Create MuSig2 partial signatures
8. Partial Verify - Verify peer's partial signature
9. Aggregate - Combine partial sigs (with adaptor adaptation)
10. Extract - Alice claims, Bob extracts t from on-chain signature

**Key Advantage:** The XFG transaction signature is indistinguishable from a normal transaction signature, providing better privacy than HTLC-based swaps.

**Counterparty Chains:** Only the counterparty chains (ETH, SOL, BCH) use HTLC because they don't support adaptor signatures natively.

### HEAT Proofs - SP1 zkVM (NOT SNARKs)

Fuego uses **SP1 zkVM** (RISC-V zero-knowledge virtual machine), NOT traditional SNARKs or Winterfell STARKs:

| Component | Implementation | Source Files |
|-----------|---------------|--------------|
| **SP1 Circuit** | RISC-V bytecode for zkVM | `fuego-prover/fuego-circuit/src/main.rs` |
| **Core Types** | Merkle proof verification | `fuego-prover/fuego-core/src/lib.rs` |
| **CryptoNight** | PoW verification (UPX/2) | `fuego-prover/fuego-cn/src/lib.rs` |
| **Merkle Tree** | Keccak256 binary tree | `src/SwapDaemon/PoolAttestation.h/cpp` |

**What HEAT Proofs Verify:**
1. Block chain linkage via Keccak256(PoW bytes)
2. Commitment scan from tx_extra (tag 0x08)
3. Merkle root computation (Keccak256 binary tree)
4. Checkpoint hash validation

**HEAT Commitment Format (56 bytes):**
```
secret[32] || amount_le64[8] || network_id_le32[4] ||
chain_id_le32[4] || version_le32[4] || term_le32[4]
```

**Nullifier:** `Keccak256(secret[0:32] || "nullifier" || amount_le64[32:40])`

**Commitment:** `Keccak256(preimage)`

### Crypto Primitives

| Primitive | Implementation | Source Files |
|-----------|---------------|--------------|
| **Ed25519** | Standard Ed25519 with Schnorr signatures | `src/crypto/crypto.h/cpp` |
| **Ring Signatures** | MLSAG (2-layer, Monero-style) | `src/crypto/mlsag.h/cpp` |
| **Pedersen Commitments** | Standard Pedersen over Ed25519 | `src/crypto/pedersen.h/cpp` |
| **Membership Proofs** | Cramer-Damgård-Schoenmakers OR proofs | `src/crypto/tier_proof.h/cpp` |

---

## Implementation Status

| Module | C API | C++ Impl | Dart FFI | Flutter | Tests |
|--------|-------|----------|----------|---------|-------|
| SDK Core | ✅ | ✅ | ✅ | ✅ | ⏳ |
| Node (Remote) | ✅ | 🟡 | ✅ | ✅ | ⏳ |
| Node (Embedded) | ✅ | ⏳ | ✅ | ✅ | ⏳ |
| Mining | ✅ | ✅ | ✅ | ✅ | ⏳ |
| Atomic Swaps | ✅ | 🟡 | ✅ | ✅ | ⏳ |
| HEAT Proofs | ✅ | 🟡 | ✅ | ✅ | ⏳ |
| Alias Service | ✅ | ✅ | ✅ | ✅ | ⏳ |
| CDs | ✅ | 🟡 | ✅ | ✅ | ⏳ |

**Legend:** 
- ✅ Complete
- 🟡 Stub (needs Fuego core integration)
- ⏳ Pending

**Notes:**
- Atomic swaps use adaptor signatures (NOT HTLC) - stub needs `src/SwapDaemon/AdaptorSwap` integration
- HEAT proofs use SP1 zkVM (NOT SNARKs) - stub needs `fuego-prover` integration
- Mining, Alias have working stub implementations
- Node requires Fuego RPC or embedded node integration

---

## Next Steps

1. **Integrate Adaptor Swap Protocol**
   - Link against `src/SwapDaemon/AdaptorSwap.cpp`
   - Implement MuSig2 key aggregation
   - Implement DLEQ proof generation/verification
   - Implement adaptor signature creation/extraction

2. **Integrate SP1 zkVM for HEAT**
   - Link against `fuego-prover` Rust library
   - Implement block range fetching
   - Implement HEAT commitment scanning
   - Implement Merkle proof generation

3. **Complete Node Integration**
   - Implement RPC node connection
   - Implement embedded node (optional)
   - Add sync status monitoring

4. **Complete CD Implementation**
   - Integrate with WalletGreen
   - Implement deposit creation
   - Implement redemption logic

5. **Build for All Platforms**
   - Linux x64
   - Windows x64
   - Android ARM64
   - iOS ARM64

---

## References

- **Adaptor Signatures:** `src/crypto/adaptor.h`, `src/SwapDaemon/AdaptorSwap.h`
- **MuSig2:** `src/crypto/musig2.h`
- **DLEQ Proofs:** `src/crypto/dleq.h`
- **HEAT Proofs:** `fuego-prover/fuego-circuit/`, `fuego-prover/fuego-core/`
- **Merkle Proofs:** `src/SwapDaemon/PoolAttestation.h`
- **Swap Protocol:** `docs/`, `swapxfg/README.md`
