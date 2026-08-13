// rfc8187.mbt — RFC 8187 extended parameter values.
//
// RFC 8187 defines the `ext-value` microsyntax used by the `title*` and
// `name*` parameters of RFC 8288:
//
//     ext-value   = charset  "'" [ language ] "'" value-chars
//     charset     = "UTF-8" / mime-charset
//     language    = <Language-Tag, RFC 5646>
//     value-chars = *( pct-encoded / attr-char )
//     pct-encoded = "%" HEXDIG HEXDIG
//
// RFC 8187 Section 3 requires implementations to support the UTF-8
// charset. This library supports UTF-8 (case-insensitively) and rejects
// every other charset with `UnsupportedCharset` rather than decoding it
// incorrectly. The decoded value is stored as a MoonBit String; the
// charset is always reported as "UTF-8" on serialisation.

///|
/// Parses an extended value starting at the current scanner position.
/// On success the cursor is positioned immediately after the last
/// value-char. The value part must not contain whitespace, `;`, or `,`;
/// those terminate the value.
///
/// Errors: `ExtendedValue::UnexpectedCharacter` (malformed charset or
/// separator), `ExtendedValue::InvalidPercentEncoding`,
/// `ExtendedValue::InvalidUtf8` (percent-decoded bytes are not valid
/// UTF-8), `ExtendedValue::UnsupportedCharset`, and
/// `ExtendedValue::InvalidLanguageTag`.
pub fn parse_extended_value(
  cursor : Scanner,
  limits : Limits,
) -> ExtendedValue raise {
  let start = cursor.position()

  // charset: 1*mime-charsetc
  let (cs_start, cs_end) = cursor.consume_while(fn(b) { mime_charsetc(b) })
  if cs_end == cs_start {
    raise link_error_at(
      ExtendedValue,
      UnexpectedCharacter,
      start,
      "expected charset before the first apostrophe",
    )
  }
  if !cursor.consume_char(39) {
    raise link_error_at(
      ExtendedValue,
      UnexpectedCharacter,
      cursor.position(),
      "expected apostrophe after charset",
    )
  }
  let charset = cursor.take_string(cs_start, cs_end)

  // language: [ Language-Tag ]  (may be empty)
  let (lang_start, lang_end) = cursor.consume_while(fn(b) {
    language_subtag_char(b)
  })
  if !cursor.consume_char(39) {
    raise link_error_at(
      ExtendedValue,
      UnexpectedCharacter,
      cursor.position(),
      "expected apostrophe after language",
    )
  }
  let lang_raw = cursor.take_string(lang_start, lang_end)
  let language : String? = if lang_raw == "" {
    None
  } else {
    if !valid_language_tag(lang_raw) {
      raise link_error_at(
        ExtendedValue,
        InvalidLanguageTag,
        lang_start,
        "invalid Language-Tag: \{lang_raw}",
      )
    }
    Some(lang_raw)
  }

  // value-chars: *( pct-encoded / attr-char )
  let value_bytes : Array[Byte] = []
  let mut done = false
  while !done {
    match cursor.peek_byte() {
      Some(b) if attr_char(b) => {
        value_bytes.push(b)
        cursor.pos = cursor.pos + 1
      }
      Some(b) if b == 37 => {
        // percent-encoded octet
        let pct_pos = cursor.position()
        cursor.pos = cursor.pos + 1
        match (cursor.peek_byte(), cursor.peek_at(1)) {
          (Some(h1), Some(h2)) if is_hexdigit(h1) && is_hexdigit(h2) => {
            value_bytes.push((hex_value(h1) * 16 + hex_value(h2)).to_byte())
            cursor.pos = cursor.pos + 2
          }
          _ =>
            raise link_error_at(
              ExtendedValue,
              InvalidPercentEncoding,
              pct_pos,
              "expected '%' followed by two hex digits",
            )
        }
      }
      _ => done = true
    }
    if cursor.position() - start > limits.max_parameter_value_bytes() {
      raise link_error_at(
        Limit,
        LimitExceeded,
        cursor.position(),
        "extended value exceeds max_parameter_value_bytes",
      )
    }
  }

  // charset support check + UTF-8 decode
  if !charset.equal_ignore_ascii_case("UTF-8") {
    raise link_error_at(
      ExtendedValue,
      UnsupportedCharset,
      cs_start,
      "unsupported charset: \{charset} (only UTF-8 is implemented)",
    )
  }
  let encoded = Bytes::from_array(value_bytes)
  let value = @utf8.decode(encoded.view(start=0, end=encoded.length())) catch {
    _ =>
      raise link_error_at(
        ExtendedValue,
        InvalidUtf8,
        start,
        "percent-decoded value is not valid UTF-8",
      )
  }
  { charset: "UTF-8", language, value }
}

///|
/// Parses a complete extended value from a string (the `name*` value,
/// without the name or `=`).
pub fn parse_extended_value_string(
  input : String,
) -> Result[ExtendedValue, LinkError] {
  try {
    let cursor = Scanner::new(input)
    let ev = parse_extended_value(cursor, Limits::default())
    if !cursor.eof() {
      raise link_error_at(
        ExtendedValue,
        TrailingInput,
        cursor.position(),
        "trailing bytes after extended value",
      )
    }
    Ok(ev)
  } catch {
    e => Err(unwrap_link_error(e))
  }
}

///|
/// Serialises an extended value deterministically. The charset is always
/// emitted as `UTF-8`; the language is emitted when present; every value
/// byte outside `attr-char` is percent-encoded with uppercase hex digits.
pub fn serialize_extended_value(ev : ExtendedValue) -> String {
  let sb = StringBuilder()
  sb.write_string("UTF-8")
  sb.write_char('\'')
  match ev.language {
    Some(l) => sb.write_string(l)
    None => ()
  }
  sb.write_char('\'')
  let bytes = @utf8.encode(ev.value)
  for i = 0; i < bytes.length(); i = i + 1 {
    let b = bytes[i]
    if attr_char(b) {
      sb.write_char(b.to_char())
    } else {
      sb.write_char('%')
      sb.write_char(hex_char(b.to_int() >> 4))
      sb.write_char(hex_char(b.to_int() & 0xF))
    }
  }
  sb.to_string()
}

///|
/// RFC 8187 `mime-charsetc`.
fn mime_charsetc(b : Byte) -> Bool {
  is_alpha(b) ||
  is_digit(b) ||
  b == 33 ||
  b == 35 ||
  b == 36 ||
  b == 37 ||
  b == 38 ||
  b == 43 ||
  b == 45 ||
  b == 94 ||
  b == 95 ||
  b == 96 ||
  b == 123 ||
  b == 125 ||
  b == 126
}

///|
/// RFC 8187 `attr-char`: token except `*`, `'`, `%`.
fn attr_char(b : Byte) -> Bool {
  is_alpha(b) ||
  is_digit(b) ||
  b == 33 ||
  b == 35 ||
  b == 36 ||
  b == 38 ||
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
/// Characters permitted inside a language subtag (RFC 5646: ALPHA /
/// DIGIT; we check this per character and validate structure separately).
fn language_subtag_char(b : Byte) -> Bool {
  is_alpha(b) || is_digit(b) || b == 45
}

///|
/// Validates an RFC 5646 Language-Tag. Implements the pragmatic subset:
/// one or more subtags separated by `-`; the primary subtag is 2-8
/// letters (or `x` for private use); each extended subtag is 1-8
/// alphanumeric characters.
pub fn valid_language_tag(tag : String) -> Bool {
  if tag.length() == 0 {
    return false
  }
  let bytes = @utf8.encode(tag)
  // split into subtags
  let subtags : Array[(Int, Int)] = []
  let mut i = 0
  let mut sub_start = 0
  while i <= bytes.length() {
    if i == bytes.length() || bytes[i] == 45 {
      subtags.push((sub_start, i))
      sub_start = i + 1
    }
    i = i + 1
  }
  if subtags.is_empty() {
    return false
  }
  let (fs, fe) = subtags[0]
  let flen = fe - fs
  if flen < 2 || flen > 8 {
    // The only legal one-letter primary subtag is the private-use prefix "x"
    // (RFC 5646 `privateuse`); every other primary subtag is 2-8 letters.
    if flen == 1 && bytes[fs] == 120 {
      ()
    } else {
      return false
    }
  }
  // primary subtag must be all letters, or the single letter "x"
  if !all_alpha(bytes, fs, fe) {
    return false
  }
  for j = 1; j < subtags.length(); j = j + 1 {
    let (s, e) = subtags[j]
    let l = e - s
    if l < 1 || l > 8 {
      return false
    }
    // every extended subtag must be alphanumeric
    for k = s; k < e; k = k + 1 {
      if !(is_alpha(bytes[k]) || is_digit(bytes[k])) {
        return false
      }
    }
  }
  true
}

///|
fn all_alpha(bytes : Bytes, start : Int, end : Int) -> Bool {
  for i = start; i < end; i = i + 1 {
    if !is_alpha(bytes[i]) {
      return false
    }
  }
  true
}

///|
/// Numeric value of a hex digit byte.
fn hex_value(b : Byte) -> Int {
  let v = b.to_int()
  if v >= 48 && v <= 57 {
    v - 48
  } else if v >= 65 && v <= 70 {
    v - 55
  } else if v >= 97 && v <= 102 {
    v - 87
  } else {
    0
  }
}

///|
/// Uppercase hex digit character for a nibble (0-15).
fn hex_char(nibble : Int) -> Char {
  let v = nibble & 0xF
  if v < 10 {
    (48 + v).unsafe_to_char()
  } else {
    (65 + v - 10).unsafe_to_char()
  }
}
