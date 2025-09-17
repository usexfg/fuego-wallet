#!/usr/bin/env python3
"""
Burn Transaction Detector for Fuego Wallet
Detects burn transactions using tx_extra 0x08 (TX_EXTRA_HEAT_COMMITMENT) tags
"""

import struct
import hashlib
from typing import Optional, Dict, Any

class BurnTransactionDetector:
    """Detects and parses burn transactions with HEAT commitments"""
    
    # TX_EXTRA tag constants
    TX_EXTRA_HEAT_COMMITMENT = 0x08
    
    def __init__(self):
        pass
    
    def is_burn_transaction(self, tx_extra: bytes) -> bool:
        """
        Check if transaction contains a HEAT commitment (burn transaction)
        
        Args:
            tx_extra: Raw transaction extra data bytes
            
        Returns:
            bool: True if this is a burn transaction
        """
        if not tx_extra:
            return False
            
        try:
            # Parse tx_extra to look for 0x08 tag
            return self._parse_tx_extra_for_heat_commitment(tx_extra) is not None
        except Exception:
            return False
    
    def parse_burn_transaction(self, tx_extra: bytes) -> Optional[Dict[str, Any]]:
        """
        Parse burn transaction data from tx_extra
        
        Args:
            tx_extra: Raw transaction extra data bytes
            
        Returns:
            Dict with burn transaction data or None if not a burn
        """
        if not tx_extra:
            return None
            
        try:
            return self._parse_tx_extra_for_heat_commitment(tx_extra)
        except Exception:
            return None
    
    def _parse_tx_extra_for_heat_commitment(self, tx_extra: bytes) -> Optional[Dict[str, Any]]:
        """
        Parse tx_extra data to extract HEAT commitment information
        
        Args:
            tx_extra: Raw transaction extra data bytes
            
        Returns:
            Dict with commitment data or None if not found
        """
        if not tx_extra:
            return None
            
        pos = 0
        while pos < len(tx_extra):
            if pos >= len(tx_extra):
                break
                
            # Read tag
            tag = tx_extra[pos]
            pos += 1
            
            if tag == self.TX_EXTRA_HEAT_COMMITMENT:
                # Found HEAT commitment tag (0x08)
                return self._parse_heat_commitment(tx_extra, pos)
            elif tag == 0x00:  # TX_EXTRA_TAG_PADDING
                # Skip padding
                padding_size = 1
                while pos < len(tx_extra) and padding_size <= 255:
                    if tx_extra[pos] != 0:
                        break
                    pos += 1
                    padding_size += 1
            else:
                # Skip other tags - read varint size
                if pos >= len(tx_extra):
                    break
                    
                # Read varint size
                size = 0
                shift = 0
                while pos < len(tx_extra):
                    byte = tx_extra[pos]
                    pos += 1
                    size |= (byte & 0x7F) << shift
                    if (byte & 0x80) == 0:
                        break
                    shift += 7
                    if shift >= 32:  # Prevent infinite loop
                        break
                
                # Skip the data
                pos += size
                
        return None
    
    def _parse_heat_commitment(self, tx_extra: bytes, pos: int) -> Optional[Dict[str, Any]]:
        """
        Parse HEAT commitment data from tx_extra
        
        Args:
            tx_extra: Raw transaction extra data bytes
            pos: Position after the 0x08 tag
            
        Returns:
            Dict with commitment data or None if parsing fails
        """
        try:
            # Read commitment hash (32 bytes)
            if pos + 32 > len(tx_extra):
                return None
                
            commitment_hash = tx_extra[pos:pos + 32]
            pos += 32
            
            # Read amount (8 bytes, little-endian)
            if pos + 8 > len(tx_extra):
                return None
                
            amount = struct.unpack('<Q', tx_extra[pos:pos + 8])[0]
            pos += 8
            
            # Read metadata size (1 byte)
            if pos >= len(tx_extra):
                return None
                
            metadata_size = tx_extra[pos]
            pos += 1
            
            # Read metadata
            metadata = b''
            if metadata_size > 0:
                if pos + metadata_size > len(tx_extra):
                    return None
                metadata = tx_extra[pos:pos + metadata_size]
            
            return {
                'type': 'heat_commitment',
                'commitment_hash': commitment_hash.hex(),
                'amount': amount,
                'metadata': metadata.hex() if metadata else '',
                'metadata_size': metadata_size,
                'is_burn': True
            }
            
        except (struct.error, IndexError):
            return None
    
    def extract_ethereum_address_from_metadata(self, metadata_hex: str) -> Optional[str]:
        """
        Extract Ethereum address from metadata if present
        
        Args:
            metadata_hex: Hex string of metadata
            
        Returns:
            Ethereum address string or None if not found
        """
        if not metadata_hex:
            return None
            
        try:
            metadata = bytes.fromhex(metadata_hex)
            
            # Look for Ethereum address pattern (0x followed by 40 hex chars)
            # This is a simple heuristic - in practice, the address might be
            # encoded differently in the metadata
            metadata_str = metadata.decode('utf-8', errors='ignore')
            
            # Look for 0x pattern
            import re
            eth_address_pattern = r'0x[a-fA-F0-9]{40}'
            matches = re.findall(eth_address_pattern, metadata_str)
            
            if matches:
                return matches[0]
                
            return None
            
        except Exception:
            return None

def main():
    """Test the burn transaction detector"""
    detector = BurnTransactionDetector()
    
    # Example tx_extra with HEAT commitment (0x08)
    # This would be generated by the wallet when creating a burn transaction
    example_tx_extra = bytes([
        0x08,  # TX_EXTRA_HEAT_COMMITMENT tag
        # 32-byte commitment hash (example)
        0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0,
        0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0,
        0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0,
        0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0,
        # 8-byte amount (little-endian) - 1000000000000 atomic units
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xe8,  # 1000000000000
        # 1-byte metadata size
        0x00,  # No metadata
    ])
    
    print("Testing Burn Transaction Detector")
    print("=" * 50)
    
    # Test detection
    is_burn = detector.is_burn_transaction(example_tx_extra)
    print(f"Is burn transaction: {is_burn}")
    
    # Test parsing
    burn_data = detector.parse_burn_transaction(example_tx_extra)
    if burn_data:
        print(f"Burn data: {burn_data}")
        print(f"Amount: {burn_data['amount']} atomic units")
        print(f"Commitment hash: {burn_data['commitment_hash']}")
    else:
        print("Failed to parse burn transaction")

if __name__ == "__main__":
    main()
