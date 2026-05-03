#ifndef FUEGO_SDK_H
#define FUEGO_SDK_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32) || defined(__CYGWIN__)
  #ifdef FUEGO_SDK_EXPORTS
    #define FUEGO_API __declspec(dllexport)
  #else
    #define FUEGO_API __declspec(dllimport)
  #endif
#else
  #define FUEGO_API __attribute__((visibility("default")))
#endif

/* ============================================================================
   Error Codes
   ============================================================================ */
typedef enum {
  FUEGO_OK = 0,
  FUEGO_ERROR_INTERNAL = 1,
  FUEGO_ERROR_INVALID_PARAM = 2,
  FUEGO_ERROR_NETWORK = 3,
  FUEGO_ERROR_WALLET = 4,
  FUEGO_ERROR_NODE = 5,
  FUEGO_ERROR_MINING = 6,
  FUEGO_ERROR_CD = 7,
  FUEGO_ERROR_SWAP = 8,
  FUEGO_ERROR_HEAT = 9,
  FUEGO_ERROR_ALIAS = 10,
  FUEGO_ERROR_MEMORY = 11,
  FUEGO_ERROR_NOT_INITIALIZED = 12
} FuegoError;

/* ============================================================================
   Initialization & Cleanup
   ============================================================================ */
FUEGO_API FuegoError fuego_sdk_init(const char* data_dir, bool testnet);
FUEGO_API void fuego_sdk_cleanup(void);
FUEGO_API const char* fuego_sdk_version(void);

/* ============================================================================
   Node Management (Embedded or Remote)
   ============================================================================ */
typedef enum {
  FUEGO_NODE_EMBEDDED,
  FUEGO_NODE_REMOTE
} FuegoNodeMode;

FUEGO_API FuegoError fuego_node_start(FuegoNodeMode mode, const char* remote_host, uint16_t remote_port);
FUEGO_API FuegoError fuego_node_stop(void);
FUEGO_API bool fuego_node_is_running(void);
FUEGO_API FuegoError fuego_node_get_peer_count(uint32_t* count);
FUEGO_API FuegoError fuego_node_get_block_height(uint32_t* height);
FUEGO_API FuegoError fuego_node_get_sync_status(bool* synchronized);

/* ============================================================================
   Mining
   ============================================================================ */
FUEGO_API FuegoError fuego_mining_start(const char* wallet_address);
FUEGO_API FuegoError fuego_mining_stop(void);
FUEGO_API bool fuego_mining_is_running(void);
FUEGO_API FuegoError fuego_mining_get_hashrate(double* hashrate);

/* ============================================================================
   Certificates of Deposit (CD)
   ============================================================================ */
typedef struct {
  uint64_t amount;
  uint64_t interest;
  uint64_t unlock_time;
  char tx_hash[65];
} FuegoCDInfo;

FUEGO_API FuegoError fuego_cd_create(uint64_t amount, uint64_t lock_time, const char* wallet_file, const char* wallet_password, FuegoCDInfo* cd_info);
FUEGO_API FuegoError fuego_cd_redeem(const char* tx_hash, const char* wallet_file, const char* wallet_password, uint64_t* redeemed_amount);
FUEGO_API FuegoError fuego_cd_get_info(const char* tx_hash, FuegoCDInfo* cd_info);

/* ============================================================================
   Atomic Swaps (Adaptor Signatures)
   ============================================================================ */
typedef enum {
  FUEGO_SWAP_INITIATED,
  FUEGO_SWAP_PARTICIPANT_JOINED,
  FUEGO_SWAP_FUNDS_LOCKED,
  FUEGO_SWAP_COMPLETED,
  FUEGO_SWAP_REFUNDED,
  FUEGO_SWAP_FAILED
} FuegoSwapState;

typedef struct {
  char swap_id[65];
  FuegoSwapState state;
  char counterparty_address[128];
  uint64_t xfg_amount;
  uint64_t counterparty_amount;
  char counterparty_chain[32];
  char escrow_pubkey[65];
  char adaptor_point[65];
  char tx_hash[65];
} FuegoSwapInfo;

FUEGO_API FuegoError fuego_swap_initiate(const char* counterparty_address, uint64_t xfg_amount, uint64_t counterparty_amount, const char* counterparty_chain, const char* wallet_file, const char* wallet_password, FuegoSwapInfo* swap_info);
FUEGO_API FuegoError fuego_swap_join(const char* swap_id, const char* wallet_file, const char* wallet_password, FuegoSwapInfo* swap_info);
FUEGO_API FuegoError fuego_swap_lock_funds(const char* swap_id, const char* wallet_file, const char* wallet_password);
FUEGO_API FuegoError fuego_swap_lock_counterparty_funds(const char* swap_id, const char* counterparty_tx_hash);
FUEGO_API FuegoError fuego_swap_complete(const char* swap_id, const char* wallet_file, const char* wallet_password);
FUEGO_API FuegoError fuego_swap_refund(const char* swap_id, const char* wallet_file, const char* wallet_password);
FUEGO_API FuegoError fuego_swap_get_info(const char* swap_id, FuegoSwapInfo* swap_info);
FUEGO_API FuegoError fuego_swap_extract_secret(const char* swap_id, const uint8_t* pre_signature, const uint8_t* final_signature, uint8_t* adaptor_secret);

/* ============================================================================
   HEAT (Hybrid Efficient Anonymous Transfer) / zk-STARK Proofs
   ============================================================================ */
typedef struct {
  char proof_data[4096];
  size_t proof_size;
  char verification_result[32];
} FuegoHEATProof;

FUEGO_API FuegoError fuego_heat_generate_proof(uint32_t block_start, uint32_t block_end, const char* wallet_file, const char* wallet_password, FuegoHEATProof* proof);
FUEGO_API FuegoError fuego_heat_verify_proof(const FuegoHEATProof* proof, bool* valid);

/* ============================================================================
   Alias Registration
   ============================================================================ */
FUEGO_API FuegoError fuego_alias_register(const char* alias, const char* wallet_address, const char* wallet_file, const char* wallet_password, char* tx_hash, size_t tx_hash_size);
FUEGO_API FuegoError fuego_alias_resolve(const char* alias, char* wallet_address, size_t address_size);
FUEGO_API FuegoError fuego_alias_get_owned(const char* wallet_address, char** aliases, size_t* count);

/* ============================================================================
   Memory Management
   ============================================================================ */
FUEGO_API void fuego_free_string(char* str);
FUEGO_API void fuego_free_pointer_array(char** ptrs, size_t count);

#ifdef __cplusplus
}
#endif

#endif /* FUEGO_SDK_H */
