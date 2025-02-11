
use stack_epic_keychain::mnemonic;
use rand::thread_rng;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use rand::Rng;

pub fn mnemonic() -> Result<String, mnemonic::Error> {
    let seed = create_seed(32);
    match mnemonic::from_entropy(&seed) {
        Ok(mnemonic_str) => {
            Ok(mnemonic_str)
        }, Err(e) => {
            return  Err(e);
        }
    }
}

pub fn create_seed(seed_length: u64) -> Vec<u8> {
    let mut seed: Vec<u8> = vec![];
    let mut rng = thread_rng();
    for _ in 0..seed_length {
        seed.push(rng.gen());
    }
    seed
}

pub fn _get_mnemonic() -> Result<*const c_char, mnemonic::Error> {
    let mut wallet_phrase = "".to_string();
    match mnemonic() {
        Ok(phrase) => {
            wallet_phrase.push_str(&phrase);
        },Err(e) => {
            return Err(e);
        }
    }
    let s = CString::new(wallet_phrase).unwrap();
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    Ok(p)
}

#[cfg(test)]
mod mnemonic_tests {
    use super::*;
    use std::collections::HashSet;

    // Test the create_seed function.
    #[test]
    fn test_create_seed() {
        // Test with different seed lengths.
        let lengths = [16, 24, 32];

        for &length in lengths.iter() {
            let seed = create_seed(length);

            // Verify seed length.
            assert_eq!(seed.len(), length as usize, "Seed length should match requested length");

            // Verify seed contains random values (not all zeros).
            let unique_bytes: HashSet<_> = seed.iter().collect();
            assert!(unique_bytes.len() > 1, "Seed should contain random values");

            println!("Successfully generated seed of length {}: {:?}", length, seed);
        }
    }

    // Test the mnemonic() function.
    #[test]
    fn test_mnemonic_generation() {
        match mnemonic() {
            Ok(phrase) => {
                // Verify the mnemonic is not empty.
                assert!(!phrase.is_empty(), "Mnemonic phrase should not be empty");

                // Split into words and verify word count (should be 24 words for 32 bytes entropy).
                let words: Vec<&str> = phrase.split_whitespace().collect();
                assert_eq!(words.len(), 24, "Mnemonic should contain 24 words");

                // Verify all words are lowercase and contain only letters.
                for word in &words {
                    assert!(word.chars().all(|c| c.is_ascii_lowercase()),
                            "Words should only contain lowercase letters");
                }

                println!("Successfully generated mnemonic phrase: {}", phrase);
            },
            Err(e) => {
                panic!("Failed to generate mnemonic: {:?}", e);
            }
        }
    }

    // Test the _get_mnemonic FFI function.
    #[test]
    fn test_get_mnemonic_ffi() {
        unsafe {
            match _get_mnemonic() {
                Ok(c_str_ptr) => {
                    // Convert C string pointer back to Rust string.
                    let c_str = CStr::from_ptr(c_str_ptr);
                    let phrase = c_str.to_str().expect("Invalid UTF-8 in mnemonic");

                    // Verify the mnemonic is valid.
                    assert!(!phrase.is_empty(), "Mnemonic phrase should not be empty");

                    let words: Vec<&str> = phrase.split_whitespace().collect();
                    assert_eq!(words.len(), 24, "Mnemonic should contain 24 words");

                    println!("Successfully generated FFI mnemonic: {}", phrase);

                    // Clean up the C string (since we're in a test).
                    let _ = CString::from_raw(c_str_ptr as *mut i8);
                },
                Err(e) => {
                    panic!("Failed to generate FFI mnemonic: {:?}", e);
                }
            }
        }
    }

    // Test multiple mnemonic generations to ensure uniqueness.
    #[test]
    fn test_mnemonic_uniqueness() {
        let mut phrases = HashSet::new();

        // Generate multiple phrases and check that they're unique.
        for i in 0..5 {
            match mnemonic() {
                Ok(phrase) => {
                    assert!(!phrases.contains(&phrase),
                            "Generated duplicate mnemonic on iteration {}", i);
                    phrases.insert(phrase.clone());
                    println!("Generated unique mnemonic {}: {}", i + 1, phrase);
                },
                Err(e) => {
                    panic!("Failed to generate mnemonic on iteration {}: {:?}", i, e);
                }
            }
        }
    }

    // Test that generated mnemonics can be parsed back into valid seeds.
    #[test]
    fn test_mnemonic_reversibility() {
        use stack_epic_keychain::mnemonic::to_entropy;

        match mnemonic() {
            Ok(phrase) => {
                // Try to convert mnemonic back to entropy.
                match to_entropy(&phrase) {
                    Ok(entropy) => {
                        assert_eq!(entropy.len(), 32,
                                   "Entropy from mnemonic should be 32 bytes");
                        println!("Successfully verified mnemonic reversibility for: {}", phrase);
                    },
                    Err(e) => {
                        panic!("Failed to convert mnemonic back to entropy: {:?}", e);
                    }
                }
            },
            Err(e) => {
                panic!("Failed to generate mnemonic: {:?}", e);
            }
        }
    }
    #[test]
    fn test_mnemonic_vector() {
        use stack_epic_keychain::mnemonic::to_entropy;

        let mnemonic = "march journey switch frame cloud since course twice cement pen random snow volume warrior film traffic loan tomorrow speed surprise thought remember ill whip";
        // Alternate vector used elsewhere in tests or otherwise committed:
        // let mnemonic = "give tube absurd fossil bike nurse huge neither equip claim tattoo fly stool gauge convince ask cat short bind original mule bundle feature tonight";

        // Known correct values:
        let expected_bytes: [u8; 32] = [
            135, 207, 15, 112, 174, 66, 191, 146,
            76, 87, 90, 37, 52, 78, 198, 230,
            207, 93, 238, 149, 151, 54, 131, 28,
            135, 68, 109, 62, 15, 107, 92, 63
        ];
        let expected_hex = "87cf0f70ae42bf924c575a25344ec6e6cf5dee959736831c87446d3e0f6b5c3f";

        match to_entropy(mnemonic) {
            Ok(entropy) => {
                println!("Testing mnemonic entropy matches expected values:");
                println!("Mnemonic: {}", mnemonic);
                println!("Entropy (bytes): {:?}", entropy);
                println!("Entropy (hex): {}", hex::encode(&entropy));

                // Verify exact byte values match
                assert_eq!(
                    entropy.as_slice(),
                    expected_bytes.as_slice(),
                    "Entropy bytes don't match expected values"
                );

                // Verify hex representation matches
                assert_eq!(
                    hex::encode(&entropy),
                    expected_hex,
                    "Hex representation doesn't match expected value"
                );

                println!("\nEntropy verification passed! ✓");
            },
            Err(e) => {
                panic!("Failed to convert specific mnemonic to entropy: {:?}", e);
            }
        }
    }
}
