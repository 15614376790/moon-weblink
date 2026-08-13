// token.mbt — HTTP / RFC 8288 character predicates.
//
// These byte predicates implement the exact ABNF character classes used by
// the RFC 8288 Link grammar (which inherits the RFC 7230 token rules) and
// by the RFC 3986 URI grammar. They are deliberately not "any non-empty
// string is a token": separators, control characters, spaces and non-ASCII
// bytes are classified explicitly so that malformed input is rejected
// instead of being silently accepted.

///|
/// Lowercases the ASCII letters of a string, leaving every other byte
/// unchanged. Used to dispatch on RFC 8288 parameter names, whose ABNF
/// string literals (RFC 5234) are case-insensitive; the names are ASCII
/// tokens, so a byte-wise ASCII fold is exact.
fn ascii_lowercase(s : String) -> String {
  let bytes = @utf8.encode(s)
  let sb = StringBuilder()
  for b in bytes {
    let v = b.to_int()
    if v >= 65 && v <= 90 {
      sb.write_char((v + 32).unsafe_to_char())
    } else {
      sb.write_char(b.to_char())
    }
  }
  sb.to_string()
}

///|
/// `ALPHA` — ASCII letters.
pub fn is_alpha(b : Byte) -> Bool {
  let v = b.to_int()
  (v >= 65 && v <= 90) || (v >= 97 && v <= 122)
}

///|
/// `DIGIT` — ASCII digits.
pub fn is_digit(b : Byte) -> Bool {
  let v = b.to_int()
  v >= 48 && v <= 57
}

///|
/// `HEXDIG` — ASCII hex digits.
pub fn is_hexdigit(b : Byte) -> Bool {
  is_digit(b) ||
  ({
    let v = b.to_int()
    (v >= 65 && v <= 70) || (v >= 97 && v <= 102)
  })
}

///|
/// RFC 7230 `tchar` — allowed token characters.
pub fn token_char(b : Byte) -> Bool {
  let v = b.to_int()
  (v >= 48 && v <= 57) || // DIGIT
  (v >= 65 && v <= 90) || // ALPHA upper
  (v >= 97 && v <= 122) || // ALPHA lower
  b == 33 ||
  b == 35 ||
  b == 36 ||
  b == 37 ||
  b == 38 ||
  b == 39 ||
  b == 42 ||
  b == 43 ||
  b == 45 ||
  b == 46 ||
  b == 94 ||
  b == 95 ||
  b == 96 ||
  b == 124 ||
  b == 126
}

///|
/// RFC 8288 `parmchar` — allowed parameter-name characters.
pub fn parmchar(b : Byte) -> Bool {
  token_char(b) || b == 58 || b == 91 || b == 93 || b == 123 || b == 125
}

///|
/// RFC 8288 `ptokenchar` — allowed unquoted parameter-value characters.
pub fn ptokenchar(b : Byte) -> Bool {
  let v = b.to_int()
  (v >= 48 && v <= 57) ||
  (v >= 65 && v <= 90) ||
  (v >= 97 && v <= 122) ||
  b == 33 ||
  b == 35 ||
  b == 36 ||
  b == 37 ||
  b == 38 ||
  b == 39 ||
  b == 40 ||
  b == 41 ||
  b == 42 ||
  b == 43 ||
  b == 45 ||
  b == 46 ||
  b == 47 ||
  b == 58 ||
  b == 60 ||
  b == 61 ||
  b == 62 ||
  b == 63 ||
  b == 64 ||
  b == 91 ||
  b == 93 ||
  b == 94 ||
  b == 95 ||
  b == 96 ||
  b == 123 ||
  b == 124 ||
  b == 125 ||
  b == 126
}

///|
/// Whether a byte is a vertical-tab or bare CR or LF (control characters
/// that must never appear unquoted).
pub fn is_bad_control(b : Byte) -> Bool {
  b == 0 || b == 10 || b == 13
}

///|
/// HTTP obs-text: bytes 0x80-0xFF. Allowed inside quoted-strings and
/// quoted-pairs per RFC 7230, but rejected by the `application/linkset`
/// text format (RFC 9264 Section 4.1).
pub fn is_obs_text(b : Byte) -> Bool {
  b.to_int() >= 128
}

///|
/// RFC 7230 `qdtext`: HTAB / SP / `!` / `#`-`[` / `]`-`~` / obs-text.
/// Notably excludes `"` and `\` and control characters.
pub fn qdtext_char(b : Byte) -> Bool {
  let v = b.to_int()
  b == 9 ||
  b == 32 ||
  v == 33 ||
  (v >= 35 && v <= 91) ||
  (v >= 93 && v <= 126) ||
  is_obs_text(b)
}

///|
/// A valid quoted-pair second byte: `\` followed by HTAB / SP / VCHAR /
/// obs-text (RFC 7230).
pub fn quoted_pair_ok(b : Byte) -> Bool {
  let v = b.to_int()
  b == 9 || b == 32 || (v >= 33 && v <= 126) || is_obs_text(b)
}

///|
/// RFC 3986 `unreserved`: ALPHA / DIGIT / "-" / "." / "_" / "~".
pub fn uri_unreserved(b : Byte) -> Bool {
  is_alpha(b) || is_digit(b) || b == 45 || b == 46 || b == 95 || b == 126
}

///|
/// RFC 3986 `sub-delims`: "!" / "$" / "&" / "'" / "(" / ")" / "*" / "+" /
/// "," / ";" / "=".
pub fn uri_sub_delim(b : Byte) -> Bool {
  b == 33 ||
  b == 36 ||
  b == 38 ||
  b == 39 ||
  b == 40 ||
  b == 41 ||
  b == 42 ||
  b == 43 ||
  b == 44 ||
  b == 59 ||
  b == 61
}

///|
/// RFC 3986 `gen-delims`: ":" / "/" / "?" / "#" / "[" / "]" / "@".
pub fn uri_gen_delim(b : Byte) -> Bool {
  b == 58 || b == 47 || b == 63 || b == 35 || b == 91 || b == 93 || b == 64
}

///|
/// RFC 3986 `pchar`: unreserved / pct-encoded / sub-delims / ":" / "@".
/// (Percent signs are handled separately by the URI parser.)
pub fn uri_pchar(b : Byte) -> Bool {
  uri_unreserved(b) || uri_sub_delim(b) || b == 58 || b == 64
}

///|
/// Whether a byte may appear in a media type token (RFC 6838 / RFC 7230
/// token). Same as `token_char`; kept as a named alias for readability.
pub fn media_type_token_char(b : Byte) -> Bool {
  token_char(b)
}
