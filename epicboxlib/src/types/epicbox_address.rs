use regex::Regex;
use std::fmt::{self, Display};

use crate::error::{ErrorKind, Result};
use crate::utils::crypto::Base58;
use crate::utils::is_mainnet;
use crate::utils::secp::PublicKey;

pub const EPICBOX_ADDRESS_REGEX: &str = r"^(epicbox://)?(?P<public_key>[123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]{52})(@(?P<domain>[a-zA-Z0-9\.]+)(:(?P<port>[0-9]*))?)?$";
pub const EPICBOX_ADDRESS_VERSION_MAINNET: [u8; 2] = [1, 0];
pub const EPICBOX_ADDRESS_VERSION_TESTNET: [u8; 2] = [1, 136];
pub const DEFAULT_EPICBOX_DOMAIN: &str = "127.0.0.1";
pub const DEFAULT_EPICBOX_PORT: u16 = 443;

pub fn version_bytes() -> Vec<u8> {
    if is_mainnet() {
        EPICBOX_ADDRESS_VERSION_MAINNET.to_vec()
    } else {
        EPICBOX_ADDRESS_VERSION_TESTNET.to_vec()
    }
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
pub struct EpicboxAddress {
    pub public_key: String,
    pub domain: String,
    pub port: u16
}

impl EpicboxAddress {
    pub fn new(public_key: PublicKey, domain: Option<String>, port: Option<u16>) -> Self {
        Self {
            public_key: public_key.to_base58_check(version_bytes()),
            domain: domain.unwrap_or(DEFAULT_EPICBOX_DOMAIN.to_string()),
            port: port.unwrap_or(DEFAULT_EPICBOX_PORT)
        }
    }

    pub fn new_raw(
        public_key: PublicKey,
        domain: Option<String>,
        port: Option<u16>,
        version_bytes: Vec<u8>,
    ) -> Self {
        Self {
            public_key: public_key.to_base58_check(version_bytes.clone()),
            domain: domain.unwrap_or(DEFAULT_EPICBOX_DOMAIN.to_string()),
            port: port.unwrap_or(DEFAULT_EPICBOX_PORT),
        }
    }

    pub fn from_str(s: &str) -> Result<Self> {
        let re = Regex::new(EPICBOX_ADDRESS_REGEX).unwrap();
        let captures = re.captures(s);
        if captures.is_none() {
            Err(ErrorKind::EpicboxAddressParsingError(s.to_string()))?;
        }

        let captures = captures.unwrap();
        let public_key = captures.name("public_key").unwrap().as_str().to_string();
        let domain = captures.name("domain").map(|m| m.as_str().to_string());
        let port = captures
            .name("port")
            .map(|m| u16::from_str_radix(m.as_str(), 10).unwrap());

        let public_key = PublicKey::from_base58_check(&public_key, version_bytes())?;

        Ok(EpicboxAddress::new(public_key, domain, port))
    }

    pub fn from_str_raw(s: &str) -> Result<Self> {
        let re = Regex::new(EPICBOX_ADDRESS_REGEX).unwrap();
        let captures = re.captures(s);
        if captures.is_none() {
            Err(ErrorKind::EpicboxAddressParsingError(s.to_string()))?;
        }

        let captures = captures.unwrap();
        let public_key = captures.name("public_key").unwrap().as_str().to_string();
        let domain = captures.name("domain").map(|m| m.as_str().to_string());
        let port = captures
            .name("port")
            .map(|m| u16::from_str_radix(m.as_str(), 10).unwrap());

        let (public_key, version_bytes) = PublicKey::from_base58_check_raw(&public_key, 2)?;

        Ok(EpicboxAddress::new_raw(
            public_key,
            domain,
            port,
            version_bytes,
        ))
    }

    pub fn public_key(&self) -> Result<PublicKey> {
        PublicKey::from_base58_check(&self.public_key, version_bytes())
    }

    pub fn stripped(&self) -> String {
        format!("{}", self)[10..].to_string()
    }
}

impl Display for EpicboxAddress {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "epicbox://{}", self.public_key)?;
        if self.domain != DEFAULT_EPICBOX_DOMAIN || self.port != DEFAULT_EPICBOX_PORT {
            write!(f, "@{}", self.domain)?;
            if self.port != DEFAULT_EPICBOX_PORT {
                write!(f, ":{}", self.port)?;
            }
        }
        Ok(())
    }
}
