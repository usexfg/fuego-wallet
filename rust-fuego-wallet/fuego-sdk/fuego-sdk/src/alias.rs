use crate::types::Address;
use fuego_crypto::PublicKey;

pub const TX_EXTRA_TAG_ALIAS_INFO: u8 = 0xbf;

#[derive(Debug, Clone)]
pub struct AliasInfo {
    pub alias: String,
    pub address: Address,
    pub view_key: PublicKey,
}

/// Serialize alias info into tx_extra bytes.
///
/// Wire format (matching simplewallet/C++ daemon parser):
///   [0xbf][alias_len:1][alias:N][addr_len:1][addr:M][view_key:32]
///
/// - alias must be exactly 8 bytes (validated by daemon as [a-z0-9&])
/// - address is a Fuego address string (fire...98 chars)
/// - view_key is the 32-byte Ed25519 public key for the subaddress
pub fn add_alias_info_to_extra(extra: &mut Vec<u8>, alias_info: &AliasInfo) {
    extra.push(TX_EXTRA_TAG_ALIAS_INFO);

    let alias_bytes = alias_info.alias.as_bytes();
    extra.push(alias_bytes.len() as u8);
    extra.extend_from_slice(alias_bytes);

    let addr_bytes = alias_info.address.0.as_bytes();
    extra.push(addr_bytes.len() as u8);
    extra.extend_from_slice(addr_bytes);

    extra.extend_from_slice(&alias_info.view_key.0);
}
