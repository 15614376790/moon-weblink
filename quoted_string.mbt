// quoted_string.mbt — RFC 7230 quoted-string parsing and serialisation.
//
// The RFC 8288 link grammar uses RFC 7230 quoted-strings for parameter
// values such as `rel="next prev"`, `title="..."`, and `anchor="..."`.
// A quoted-string is a byte sequence delimited by DQUOTE that may contain
// any `qdtext` byte and any `quoted-pair` (`\` followed by a valid byte).
// Commas and semicolons inside a quoted-string are data, not delimiters —
// which is exactly why the scanner is a cursor and not `split`.

///|
/// Parses a quoted-string starting at the current scanner position (which
/// must be the opening DQUOTE). On success the cursor is positioned after
/// the closing DQUOTE. The returned string is the unquoted content with
/// quoted-pairs resolved (`\"` becomes `"`, `\\` becomes `\`).
///
/// Errors: `UnterminatedQuotedString` (no closing DQUOTE), `InvalidQuotedPair`
/// (backslash not followed by a valid quoted-pair byte), `UnexpectedCharacter`
/// (a control character that is not HTAB inside the string),
/// `LimitExceeded` (the string is longer than `max_quoted_string_bytes`).
pub fn parse_quoted_string(cursor : Scanner, limits : Limits) -> String raise {
  if !cursor.consume_char(34) {
    raise link_error_at(
      QuotedString,
      ExpectedAngleBracket,
      cursor.position(),
      "expected opening DQUOTE",
    )
  }
  let start = cursor.position()
  let sb = StringBuilder()
  let mut done = false
  while !done {
    if cursor.eof() {
      raise link_error_at(
        QuotedString,
        UnterminatedQuotedString,
        start,
        cursor.context_string(),
      )
    }
    let b = cursor.peek_byte().unwrap()
    if b == 34 {
      cursor.pos = cursor.pos + 1
      done = true
    } else if b == 92 {
      // backslash: quoted-pair
      let pair_pos = cursor.position()
      cursor.pos = cursor.pos + 1
      if cursor.eof() {
        raise link_error_at(
          QuotedString,
          UnterminatedQuotedString,
          pair_pos,
          cursor.context_string(),
        )
      }
      let next = cursor.next_byte().unwrap()
      if !quoted_pair_ok(next) {
        raise link_error_at(
          QuotedString,
          InvalidQuotedPair,
          pair_pos,
          cursor.context_string(),
        )
      }
      sb.write_char(next.to_char())
    } else if qdtext_char(b) {
      sb.write_char(b.to_char())
      cursor.pos = cursor.pos + 1
    } else {
      raise link_error_at(
        QuotedString,
        UnexpectedCharacter,
        cursor.position(),
        cursor.context_string(),
      )
    }
    if cursor.position() - start > limits.max_quoted_string_bytes() {
      raise link_error_at(
        Limit,
        LimitExceeded,
        cursor.position(),
        "quoted-string exceeds max_quoted_string_bytes",
      )
    }
  }
  sb.to_string()
}

///|
/// Serialises a string as a quoted-string, deterministically. Only `"` and
/// `\` are escaped (with a backslash); every other byte is emitted as-is.
/// The result always starts and ends with DQUOTE.
pub fn serialize_quoted_string(value : String) -> String {
  let sb = StringBuilder()
  sb.write_char('"')
  for ch in value {
    if ch == '"' || ch == '\\' {
      sb.write_char('\\')
    }
    sb.write_char(ch)
  }
  sb.write_char('"')
  sb.to_string()
}

///|
/// Whether a string can be emitted as an unquoted token (all bytes are
/// `tchar` and the string is non-empty). Used by the serializer to decide
/// between the token and quoted forms.
pub fn can_be_token(value : String) -> Bool {
  if value.length() == 0 {
    return false
  }
  let bytes = @utf8.encode(value)
  let mut ok = true
  for i = 0; i < bytes.length(); i = i + 1 {
    if !token_char(bytes[i]) {
      ok = false
    }
  }
  ok
}
