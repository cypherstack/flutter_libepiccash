use colored::*;
use std::fmt::{Display, Formatter, Result};

#[derive(Clone, Eq, PartialEq, Serialize, Deserialize, Debug)]
pub enum EpicboxError {
    UnknownError,
    InvalidRequest,
    InvalidSignature,
    InvalidChallenge,
    TooManySubscriptions,
}

impl Display for EpicboxError {
    fn fmt(&self, f: &mut Formatter) -> Result {
        match *self {
            EpicboxError::UnknownError => write!(f, "{}", "unknown error!"),
            EpicboxError::InvalidRequest => write!(f, "{}", "invalid request!"),
            EpicboxError::InvalidSignature => write!(f, "{}", "invalid signature!"),
            EpicboxError::InvalidChallenge => write!(f, "{}", "invalid challenge!"),
            EpicboxError::TooManySubscriptions => write!(f, "{}", "too many subscriptions!"),
        }
    }
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(tag = "type")]
pub enum EpicboxResponse {
    Ok,
    Error {
        kind: EpicboxError,
        description: String,
    },
    Challenge {
        str: String,
    },
    Slate {
        from: String,
        str: String,
        signature: String,
        challenge: String,
    },
}

impl Display for EpicboxResponse {
    fn fmt(&self, f: &mut Formatter) -> Result {
        match *self {
            EpicboxResponse::Ok => write!(f, "{}", "Ok".cyan()),
            EpicboxResponse::Error {
                ref kind,
                description: _,
            } => write!(f, "{}: {}", "error".bright_red(), kind),
            EpicboxResponse::Challenge { ref str } => {
                write!(f, "{} {}", "Challenge".cyan(), str.bright_green())
            }
            EpicboxResponse::Slate {
                ref from,
                str: _,
                signature: _,
                challenge: _,
            } => write!(f, "{} from {}", "Slate".cyan(), from.bright_green()),
        }
    }
}
