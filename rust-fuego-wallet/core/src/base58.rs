const ALPHABET: &[u8; 58] = b"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
const FULL_BLOCK_SIZE: usize = 8;
const FULL_ENCODED_BLOCK_SIZE: usize = 11;
const ENCODED_BLOCK_SIZES: [usize; 9] = [0, 2, 3, 5, 6, 7, 9, 10, 11];

fn decoded_block_size(enc_size: usize) -> isize {
    match enc_size {
        0 => 0, 2 => 1, 3 => 2, 5 => 3, 6 => 4,
        7 => 5, 9 => 6, 10 => 7, 11 => 8,
        _ => -1,
    }
}

fn build_rev() -> [i8; 128] {
    let mut rev = [-1i8; 128];
    for (i, &c) in ALPHABET.iter().enumerate() {
        rev[c as usize] = i as i8;
    }
    rev
}

fn reverse_alphabet(letter: u8) -> isize {
    static REV: std::sync::LazyLock<[i8; 128]> = std::sync::LazyLock::new(build_rev);
    if letter >= 128 { return -1; }
    REV[letter as usize] as isize
}

fn uint_8be_to_64(data: &[u8], size: usize) -> u64 {
    let mut res: u64 = 0;
    for i in 0..size {
        res = (res << 8) | data[i] as u64;
    }
    res
}

fn encode_block(block: &[u8], size: usize, res: &mut [u8]) {
    let num = uint_8be_to_64(block, size);
    let mut n = num;
    let enc_size = ENCODED_BLOCK_SIZES[size];
    for i in (0..enc_size).rev() {
        let rem = (n % 58) as usize;
        n /= 58;
        res[i] = ALPHABET[rem];
    }
}

fn mul128(a: u64, b: u64, hi: &mut u64) -> u64 {
    let product = (a as u128) * (b as u128);
    *hi = (product >> 64) as u64;
    product as u64
}

fn decode_block(enc: &[u8], size: usize, res: &mut [u8]) -> bool {
    let dec_sz = decoded_block_size(size);
    if dec_sz <= 0 { return false; }
    let dec_sz = dec_sz as usize;

    let mut res_num: u64 = 0;
    let mut order: u64 = 1;
    for i in (0..size).rev() {
        let digit = reverse_alphabet(enc[i]);
        if digit < 0 { return false; }
        let digit = digit as u64;

        let mut product_hi: u64 = 0;
        let product_lo = mul128(order, digit, &mut product_hi);

        let (tmp, overflow) = res_num.overflowing_add(product_lo);
        if overflow || product_hi != 0 {
            return false;
        }
        res_num = tmp;
        order = order.wrapping_mul(58);
    }

    if dec_sz < FULL_BLOCK_SIZE && (1u64 << (8 * dec_sz)) <= res_num {
        return false;
    }

    for i in 0..dec_sz {
        res[i] = ((res_num >> (8 * (dec_sz - 1 - i))) & 0xFF) as u8;
    }
    true
}

pub fn encode(data: &[u8]) -> String {
    if data.is_empty() { return String::new(); }

    let full_cnt = data.len() / FULL_BLOCK_SIZE;
    let last_sz = data.len() % FULL_BLOCK_SIZE;
    let res_sz = full_cnt * FULL_ENCODED_BLOCK_SIZE
        + if last_sz > 0 { ENCODED_BLOCK_SIZES[last_sz] } else { 0 };

    let mut res = vec![ALPHABET[0]; res_sz];

    for i in 0..full_cnt {
        encode_block(
            &data[i * FULL_BLOCK_SIZE..(i + 1) * FULL_BLOCK_SIZE],
            FULL_BLOCK_SIZE,
            &mut res[i * FULL_ENCODED_BLOCK_SIZE..(i + 1) * FULL_ENCODED_BLOCK_SIZE],
        );
    }
    if last_sz > 0 {
        encode_block(
            &data[full_cnt * FULL_BLOCK_SIZE..],
            last_sz,
            &mut res[full_cnt * FULL_ENCODED_BLOCK_SIZE..],
        );
    }

    String::from_utf8(res).unwrap()
}

pub fn decode(enc: &str) -> Option<Vec<u8>> {
    if enc.is_empty() { return Some(Vec::new()); }

    let bytes = enc.as_bytes();
    let full_cnt = bytes.len() / FULL_ENCODED_BLOCK_SIZE;
    let last_sz = bytes.len() % FULL_ENCODED_BLOCK_SIZE;
    let last_dec = decoded_block_size(last_sz);
    if last_dec < 0 { return None; }
    let data_sz = full_cnt * FULL_BLOCK_SIZE + last_dec as usize;

    let mut data = vec![0u8; data_sz];

    for i in 0..full_cnt {
        if !decode_block(
            &bytes[i * FULL_ENCODED_BLOCK_SIZE..(i + 1) * FULL_ENCODED_BLOCK_SIZE],
            FULL_ENCODED_BLOCK_SIZE,
            &mut data[i * FULL_BLOCK_SIZE..(i + 1) * FULL_BLOCK_SIZE],
        ) {
            return None;
        }
    }
    if last_sz > 0 {
        if !decode_block(
            &bytes[full_cnt * FULL_ENCODED_BLOCK_SIZE..],
            last_sz,
            &mut data[full_cnt * FULL_BLOCK_SIZE..],
        ) {
            return None;
        }
    }

    Some(data)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_roundtrip_8bytes() {
        let data: Vec<u8> = vec![0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77];
        let enc = encode(&data);
        assert_eq!(enc.len(), 11);
        let dec = decode(&enc).unwrap();
        assert_eq!(dec, data);
    }

    #[test]
    fn test_roundtrip_3bytes() {
        let data: Vec<u8> = vec![0xab, 0xcd, 0xef];
        let enc = encode(&data);
        assert_eq!(enc.len(), 5);
        let dec = decode(&enc).unwrap();
        assert_eq!(dec, data);
    }

    #[test]
    fn test_roundtrip_71bytes() {
        let data: Vec<u8> = (0..71).map(|i| i as u8).collect();
        let enc = encode(&data);
        let dec = decode(&enc).unwrap();
        assert_eq!(dec, data);
    }

    #[test]
    fn test_roundtrip_address_format() {
        use crate::crypto::cn_fast_hash;
        let mut data = Vec::new();
        let tag = 1753191u64;
        let mut v = tag;
        while v >= 0x80 { data.push(((v & 0x7f) as u8) | 0x80); v >>= 7; }
        data.push(v as u8);
        for i in 0u8..64u8 { data.push(i); }
        let hash = cn_fast_hash(&data);
        data.extend_from_slice(&hash[..4]);
        assert_eq!(data.len(), 71);
        let enc = encode(&data);
        assert_eq!(enc.len(), 98);
        let dec = decode(&enc).unwrap();
        assert_eq!(dec, data);
    }
}
