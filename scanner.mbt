// scanner.mbt — Byte-oriented cursor for RFC 8288 / RFC 9264 parsing.
//
// Link headers and Linkset documents cannot be parsed with `split(",")` or
// `split(";")`: a comma or semicolon inside a quoted-string (or inside a
// URI-reference target, or inside an RFC 8187 extended value) is not a
// structural separator. This module provides a single, bounds-checked
// cursor over the UTF-8 bytes of the input. Every operation is safe at any
// position; nothing here can index out of bounds or loop forever.
//
// Positions are UTF-8 byte offsets into the original input string.

///|
/// A bounds-checked byte cursor over an input string.
pub struct Scanner {
  bytes : Bytes
  len : Int
  mut pos : Int
  allow_newline : Bool
}

///|
/// Creates a scanner for the RFC 8288 `Link` header field grammar.
/// Optional whitespace is SP / HTAB only.
pub fn Scanner::new(input : String) -> Scanner {
  let bytes = @utf8.encode(input)
  { bytes, len: bytes.length(), pos: 0, allow_newline: false }
}

///|
/// Creates a scanner for the `application/linkset` text grammar, where
/// newline characters are also permitted as whitespace around the comma
/// separators (RFC 9264 Section 4.1). The input is scanned as raw bytes;
/// non-ASCII bytes are rejected by the linkset parser, not by the scanner.
pub fn Scanner::new_linkset(input : String) -> Scanner {
  let bytes = @utf8.encode(input)
  { bytes, len: bytes.length(), pos: 0, allow_newline: true }
}

///|
/// The current position, as a UTF-8 byte offset.
pub fn Scanner::position(self : Scanner) -> Int {
  self.pos
}

///|
/// Whether the cursor is at (or past) the end of the input.
pub fn Scanner::eof(self : Scanner) -> Bool {
  self.pos >= self.len
}

///|
/// The number of bytes remaining from the current position.
pub fn Scanner::remaining(self : Scanner) -> Int {
  if self.len > self.pos {
    self.len - self.pos
  } else {
    0
  }
}

///|
/// The total length of the input in bytes.
pub fn Scanner::total_bytes(self : Scanner) -> Int {
  self.len
}

///|
/// The byte at the current position, or `None` at end of input.
pub fn Scanner::peek_byte(self : Scanner) -> Byte? {
  if self.pos >= self.len {
    None
  } else {
    Some(self.bytes[self.pos])
  }
}

///|
/// The byte at `pos + rel`, or `None` when out of bounds. `rel` may be
/// negative to look behind the current position.
pub fn Scanner::peek_at(self : Scanner, rel : Int) -> Byte? {
  let idx = self.pos + rel
  if idx < 0 || idx >= self.len {
    None
  } else {
    Some(self.bytes[idx])
  }
}

///|
/// The byte at an absolute offset, or `None` when out of bounds.
pub fn Scanner::byte_at(self : Scanner, idx : Int) -> Byte? {
  if idx < 0 || idx >= self.len {
    None
  } else {
    Some(self.bytes[idx])
  }
}

///|
/// Returns the current byte and advances the cursor by one. Returns
/// `None` at end of input (and does not advance).
pub fn Scanner::next_byte(self : Scanner) -> Byte? {
  if self.pos >= self.len {
    None
  } else {
    let b = self.bytes[self.pos]
    self.pos = self.pos + 1
    Some(b)
  }
}

///|
/// Skips optional whitespace (OWS). For the default grammar this is
/// SP (0x20) and HTAB (0x09); for the linkset grammar CR and LF are also
/// treated as whitespace (RFC 9264 Section 4.1).
pub fn Scanner::skip_ows(self : Scanner) -> Unit {
  let mut done = false
  while !done {
    match self.peek_byte() {
      Some(b) if b == 32 ||
        b == 9 ||
        (self.allow_newline && (b == 13 || b == 10)) => self.pos = self.pos + 1
      _ => done = true
    }
  }
}

///|
/// Whether the current byte is optional whitespace under this scanner's
/// grammar.
pub fn Scanner::is_ows(self : Scanner) -> Bool {
  match self.peek_byte() {
    Some(b) => b == 32 || b == 9 || (self.allow_newline && (b == 13 || b == 10))
    None => false
  }
}

///|
/// Moves the cursor to an absolute byte offset, clamping out-of-range
/// positions to the ends of the input. Used when a sub-parser must start
/// at a known offset (for example media-type parameters).
pub fn Scanner::seek(self : Scanner, pos : Int) -> Unit {
  if pos < 0 {
    self.pos = 0
  } else if pos > self.len {
    self.pos = self.len
  } else {
    self.pos = pos
  }
}

///|
/// If the current byte equals `b`, advances and returns `true`.
pub fn Scanner::consume_char(self : Scanner, b : Byte) -> Bool {
  match self.peek_byte() {
    Some(c) if c == b => {
      self.pos = self.pos + 1
      true
    }
    _ => false
  }
}

///|
/// Consumes a run of bytes satisfying `pred` and returns the `(start, end)`
/// byte range of the run. The run may be empty.
pub fn Scanner::consume_while(
  self : Scanner,
  pred : (Byte) -> Bool,
) -> (Int, Int) {
  let start = self.pos
  let mut done = false
  while !done {
    match self.peek_byte() {
      Some(b) if pred(b) => self.pos = self.pos + 1
      _ => done = true
    }
  }
  (start, self.pos)
}

///|
/// Consumes a run of token characters (RFC 7230 `tchar`) and returns the
/// `(start, end)` byte range. The run may be empty.
pub fn Scanner::consume_token(self : Scanner) -> (Int, Int) {
  self.consume_while(fn(b) { token_char(b) })
}

///|
/// Consumes a run of parameter characters (RFC 8288 `parmchar`) and
/// returns the `(start, end)` byte range. The run may be empty.
pub fn Scanner::consume_param_name(self : Scanner) -> (Int, Int) {
  self.consume_while(fn(b) { parmchar(b) })
}

///|
/// The index of the next occurrence of byte `b` at or after the current
/// position, or `None`.
pub fn Scanner::find_byte(self : Scanner, b : Byte) -> Int? {
  let mut i = self.pos
  while i < self.len {
    if self.bytes[i] == b {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// Consumes bytes until (and including) the first occurrence of byte `b`.
/// Returns the `(start, end)` range of the consumed bytes *before* `b`
/// (i.e. end is the position of `b`), or `None` when `b` is not found.
pub fn Scanner::consume_until(self : Scanner, b : Byte) -> (Int, Int)? {
  let start = self.pos
  match self.find_byte(b) {
    Some(idx) => {
      self.pos = idx
      Some((start, idx))
    }
    None => None
  }
}

///|
/// Decodes a `Bytes` view as UTF-8. Byte slices derived from a MoonBit
/// `String` (the input to every public entry point) are valid UTF-8 by
/// construction, so a decode failure here would be an internal bug and is
/// reported loudly instead of silently corrupting data.
fn decode_utf8(bytes : BytesView) -> String {
  @utf8.decode(bytes) catch {
    _ => abort("internal error: invalid UTF-8 in derived byte slice")
  }
}

///|
/// Decodes the byte range `[start, end)` back into a String. Valid UTF-8
/// is decoded normally; a range that is not valid UTF-8 (for example an
/// HTTP obs-text byte inside a quoted-string) is preserved byte-for-byte
/// so round-tripping never loses data.
pub fn Scanner::take_string(self : Scanner, start : Int, end : Int) -> String {
  let hi = if end > self.len { self.len } else { end }
  let lo = if start < 0 { 0 } else { start }
  if hi <= lo {
    return ""
  }
  @utf8.decode(self.bytes.view(start=lo, end=hi)) catch {
    _ => self.bytes.view(start=lo, end=hi).to_owned().to_unchecked_string()
  }
}

///|
/// A short, bounded excerpt of the input around the current position, for
/// use in error context strings. Never longer than `max_context_bytes()`.
pub fn Scanner::context_string(self : Scanner) -> String {
  let window = max_context_bytes()
  let mut start = self.pos - 24
  if start < 0 {
    start = 0
  }
  let mut take = window - 8
  if take > self.len - start {
    take = self.len - start
  }
  if take < 0 {
    take = 0
  }
  let excerpt = self.take_string(start, start + take)
  let prefix = if start > 0 { "..." } else { "" }
  let suffix = if start + take < self.len { "..." } else { "" }
  prefix + excerpt + suffix
}
