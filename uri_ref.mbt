// uri_ref.mbt — Minimal RFC 3986 URI-reference support.
//
// RFC 8288 requires the link target, the `anchor` value, and extension
// relation types to be URI-references, and relative references are to be
// resolved per RFC 3986 Section 5. This module implements exactly the
// subset of RFC 3986 that Web Linking needs:
//
//   - strict validation of a URI-reference (character classes and
//     percent-encoding),
//   - decomposition into scheme / authority / path / query / fragment,
//   - `remove_dot_segments` (RFC 3986 Section 5.2.4),
//   - reference resolution (RFC 3986 Section 5.2.2) with the official
//     test vectors from RFC 3986 Section 5.4.
//
// It deliberately does not implement IDNA, DNS, URL fetching, browser
// normalisation, or internationalised URIs (IRIs). URI text is ASCII only.

///|
/// A decomposed URI-reference.
pub struct UriReference {
  scheme : String?
  authority : String?
  path : String
  query : String?
  fragment : String?
}

///|
/// An empty URI-reference (`""`).
pub fn UriReference::empty() -> UriReference {
  { scheme: None, authority: None, path: "", query: None, fragment: None }
}

///|
/// The scheme component, if present.
pub fn UriReference::scheme(self : UriReference) -> String? {
  self.scheme
}

///|
/// The authority component, if present.
pub fn UriReference::authority(self : UriReference) -> String? {
  self.authority
}

///|
/// The path component (possibly empty).
pub fn UriReference::path(self : UriReference) -> String {
  self.path
}

///|
/// The query component (without the leading `?`), if present.
pub fn UriReference::query(self : UriReference) -> String? {
  self.query
}

///|
/// The fragment component (without the leading `#`), if present.
pub fn UriReference::fragment(self : UriReference) -> String? {
  self.fragment
}

///|
/// Recomposes the URI-reference from its components.
pub fn UriReference::to_string(self : UriReference) -> String {
  let sb = StringBuilder()
  match self.scheme {
    Some(s) => {
      sb.write_string(s)
      sb.write_char(':')
    }
    None => ()
  }
  match self.authority {
    Some(a) => {
      sb.write_string("//")
      sb.write_string(a)
    }
    None => ()
  }
  sb.write_string(self.path)
  match self.query {
    Some(q) => {
      sb.write_char('?')
      sb.write_string(q)
    }
    None => ()
  }
  match self.fragment {
    Some(f) => {
      sb.write_char('#')
      sb.write_string(f)
    }
    None => ()
  }
  sb.to_string()
}

///|
/// Parses and strictly validates a URI-reference.
///
/// Errors: `UriReference::InvalidToken` (character not allowed), and
/// `UriReference::InvalidPercentEncoding` (a `%` not followed by two hex
/// digits).
pub fn parse_uri_reference(input : String) -> Result[UriReference, LinkError] {
  Ok(parse_uri_impl(input)) catch {
    e => Err(unwrap_link_error(e))
  }
}

///|
fn parse_uri_impl(input : String) -> UriReference raise {
  let cursor = Scanner::new(input)
  let mut scheme : String? = None
  let mut authority : String? = None

  // Scheme detection: ALPHA *( ALPHA / DIGIT / "+" / "-" / "." ) ":"
  let scheme_start = cursor.position()
  let mut scheme_end = scheme_start
  match cursor.peek_byte() {
    Some(b) if is_alpha(b) => {
      // scan scheme chars
      let mut done = false
      while !done {
        match cursor.peek_byte() {
          Some(b) if is_alpha(b) || is_digit(b) || b == 43 || b == 45 || b == 46 => {
            cursor.pos = cursor.pos + 1
            scheme_end = scheme_end + 1
          }
          _ => done = true
        }
      }
    }
    _ => ()
  }
  // check for ":"
  if cursor.peek_byte() == Some(58) {
    cursor.pos = cursor.pos + 1
    scheme = Some(cursor.take_string(scheme_start, scheme_end))
  } else {
    // no scheme: reset cursor to start
    cursor.pos = scheme_start
  }

  // Authority: "//"
  if cursor.peek_byte() == Some(47) && cursor.peek_at(1) == Some(47) {
    cursor.pos = cursor.pos + 2
    let auth_start = cursor.position()
    // authority ends at "/", "?", "#", or end
    let mut done = false
    while !done {
      match cursor.peek_byte() {
        Some(b) if b == 47 || b == 63 || b == 35 => done = true
        Some(b) if b == 37 => consume_pct_encoded(cursor)
        Some(b) => {
          if !uri_authority_char(b) {
            raise link_error_at(
              UriReference,
              InvalidToken,
              cursor.position(),
              "character not allowed in authority",
            )
          }
          cursor.pos = cursor.pos + 1
        }
        None => done = true
      }
    }
    authority = Some(cursor.take_string(auth_start, cursor.position()))
  }

  // Path: pchar / "/"
  let path_start = cursor.position()
  let mut in_first_segment = scheme == None && authority == None
  let mut done = false
  while !done {
    match cursor.peek_byte() {
      Some(b) if b == 63 || b == 35 => done = true
      Some(b) if b == 47 => {
        in_first_segment = false
        cursor.pos = cursor.pos + 1
      }
      Some(b) if b == 58 && in_first_segment =>
        // In a scheme-less, authority-less reference, a ":" in the first
        // path segment is ambiguous with a scheme separator; RFC 3986
        // path-noscheme forbids it.
        raise link_error_at(
          UriReference,
          InvalidToken,
          cursor.position(),
          "':' in first path segment without a scheme is ambiguous",
        )
      Some(b) if uri_pchar(b) => cursor.pos = cursor.pos + 1
      Some(b) if b == 37 => consume_pct_encoded(cursor)
      Some(b) if is_obs_text(b) || b.to_int() < 32 =>
        raise link_error_at(
          UriReference,
          InvalidToken,
          cursor.position(),
          "non-ASCII or control character in URI-reference",
        )
      Some(_) =>
        raise link_error_at(
          UriReference,
          InvalidToken,
          cursor.position(),
          "character not allowed in path",
        )
      None => done = true
    }
  }
  let path = cursor.take_string(path_start, cursor.position())

  // Query: pchar / "/" / "?"
  let mut query : String? = None
  if cursor.consume_char(63) {
    let q_start = cursor.position()
    let mut qdone = false
    while !qdone {
      match cursor.peek_byte() {
        Some(b) if b == 35 => qdone = true
        Some(b) if uri_pchar(b) || b == 47 || b == 63 =>
          cursor.pos = cursor.pos + 1
        Some(b) if b == 37 => consume_pct_encoded(cursor)
        Some(_) =>
          raise link_error_at(
            UriReference,
            InvalidToken,
            cursor.position(),
            "character not allowed in query",
          )
        None => qdone = true
      }
    }
    query = Some(cursor.take_string(q_start, cursor.position()))
  }

  // Fragment: pchar / "/" / "?"
  let mut fragment : String? = None
  if cursor.consume_char(35) {
    let f_start = cursor.position()
    let mut fdone = false
    while !fdone {
      match cursor.peek_byte() {
        Some(b) if uri_pchar(b) || b == 47 || b == 63 =>
          cursor.pos = cursor.pos + 1
        Some(b) if b == 37 => consume_pct_encoded(cursor)
        Some(_) =>
          raise link_error_at(
            UriReference,
            InvalidToken,
            cursor.position(),
            "character not allowed in fragment",
          )
        None => fdone = true
      }
    }
    fragment = Some(cursor.take_string(f_start, cursor.position()))
  }

  if !cursor.eof() {
    raise link_error_at(
      UriReference,
      InvalidToken,
      cursor.position(),
      "trailing bytes after URI-reference",
    )
  }

  { scheme, authority, path, query, fragment }
}

///|
/// Consumes a `% HEXDIG HEXDIG` triplet at the current position, raising
/// `InvalidPercentEncoding` otherwise.
fn consume_pct_encoded(cursor : Scanner) -> Unit raise {
  let pos = cursor.position()
  cursor.pos = cursor.pos + 1
  match (cursor.peek_byte(), cursor.peek_at(1)) {
    (Some(h1), Some(h2)) if is_hexdigit(h1) && is_hexdigit(h2) =>
      cursor.pos = cursor.pos + 2
    _ =>
      raise link_error_at(
        UriReference,
        InvalidPercentEncoding,
        pos,
        "expected '%' followed by two hex digits",
      )
  }
}

///|
/// Whether a byte is valid inside an authority component.
fn uri_authority_char(b : Byte) -> Bool {
  uri_unreserved(b) ||
  uri_sub_delim(b) ||
  b == 58 ||
  b == 64 ||
  b == 91 ||
  b == 93
}

///|
/// Implements `remove_dot_segments` (RFC 3986 Section 5.2.4) on a path.
///
/// The algorithm consumes the input path one rule at a time: leading `./`
/// and `../` are dropped; `/./` (or a trailing `/ .`) collapses to `/`;
/// `/../` (or a trailing `/ ..`) collapses to `/` and pops the last output
/// segment; a path that is exactly `.` or `..` is dropped; otherwise the
/// first segment (including any leading `/`) is moved to the output. Every
/// rule advances `i`, so the loop always terminates.
pub fn remove_dot_segments(path : String) -> String {
  let bytes = @utf8.encode(path)
  let out = StringBuilder()
  let mut i = 0
  let len = bytes.length()
  while i < len {
    // Rule A: "./" and "../" prefixes are dropped entirely.
    if i + 1 < len && bytes[i] == 46 && bytes[i + 1] == 47 {
      i = i + 2
      continue
    }
    if i + 2 < len && bytes[i] == 46 && bytes[i + 1] == 46 && bytes[i + 2] == 47 {
      i = i + 3
      continue
    }
    // Rule B: "/./" (or a trailing "/.") collapses to "/".
    if i + 2 < len && bytes[i] == 47 && bytes[i + 1] == 46 && bytes[i + 2] == 47 {
      i = i + 2
      continue
    }
    if i + 2 == len && bytes[i] == 47 && bytes[i + 1] == 46 {
      out.write_char('/')
      i = i + 2
      continue
    }
    // Rule C: "/../" (or a trailing "/..") collapses to "/" and pops the
    // last segment of the output.
    if i + 3 < len &&
      bytes[i] == 47 &&
      bytes[i + 1] == 46 &&
      bytes[i + 2] == 46 &&
      bytes[i + 3] == 47 {
      remove_last_segment(out)
      i = i + 3
      continue
    }
    if i + 3 == len &&
      bytes[i] == 47 &&
      bytes[i + 1] == 46 &&
      bytes[i + 2] == 46 {
      remove_last_segment(out)
      out.write_char('/')
      i = i + 3
      continue
    }
    // Rule D: a path that is exactly "." or ".." is dropped.
    if i == 0 && len == 1 && bytes[0] == 46 {
      i = len
      continue
    }
    if i == 0 && len == 2 && bytes[0] == 46 && bytes[1] == 46 {
      i = len
      continue
    }
    // Rule E: move the first segment, including a leading "/".
    let seg_start = i
    if bytes[i] == 47 {
      i = i + 1
    }
    while i < len && bytes[i] != 47 {
      i = i + 1
    }
    out.write_string(decode_utf8(bytes.view(start=seg_start, end=i)))
  }
  out.to_string()
}

///|
/// Removes the last segment (from the last `/` onward) of the text
/// currently accumulated in `sb`.
fn remove_last_segment(sb : StringBuilder) -> Unit {
  let s = sb.to_string()
  let bytes = @utf8.encode(s)
  let mut idx : Int = -1
  for i = 0; i < bytes.length(); i = i + 1 {
    if bytes[i] == 47 {
      idx = i
    }
  }
  let new = if idx >= 0 {
    decode_utf8(bytes.view(start=0, end=idx))
  } else {
    ""
  }
  sb.reset()
  sb.write_string(new)
}

///|
/// Whether the path starts with the given ASCII prefix.
fn path_starts_with(path : String, prefix : String) -> Bool {
  let p = @utf8.encode(path)
  let q = @utf8.encode(prefix)
  if q.length() > p.length() {
    return false
  }
  let mut ok = true
  for i = 0; i < q.length(); i = i + 1 {
    if p[i] != q[i] {
      ok = false
    }
  }
  ok
}

///|
/// Resolves a reference against a base URI-reference, returning the
/// resolved absolute URI-reference as a string. Implements RFC 3986
/// Section 5.2.2.
pub fn resolve_uri_reference_string(
  base : String,
  reference : String,
) -> Result[String, LinkError] {
  match (parse_uri_reference(base), parse_uri_reference(reference)) {
    (Ok(b), Ok(r)) => Ok(resolve_uri_ref(b, r).to_string())
    (Err(e), _) => Err(e)
    (_, Err(e)) => Err(e)
  }
}

///|
/// Resolves a reference against a base URI-reference, returning the
/// resolved URI-reference model.
pub fn resolve_uri_reference(
  base : UriReference,
  reference : UriReference,
) -> UriReference {
  resolve_uri_ref(base, reference)
}

///|
fn resolve_uri_ref(base : UriReference, r : UriReference) -> UriReference {
  // Reference is an absolute URI: it stands on its own. The path is
  // normalised.
  match r.scheme {
    Some(s) =>
      {
        scheme: Some(s),
        authority: r.authority,
        path: remove_dot_segments(r.path),
        query: r.query,
        fragment: r.fragment,
      }
    None =>
      match r.authority {
        Some(a) =>
          {
            scheme: base.scheme,
            authority: Some(a),
            path: remove_dot_segments(r.path),
            query: r.query,
            fragment: r.fragment,
          }
        None => {
          let (path, query) = if r.path == "" {
            (
              base.path,
              match r.query {
                Some(q) => Some(q)
                None => base.query
              },
            )
          } else {
            let p = if path_starts_with(r.path, "/") {
              remove_dot_segments(r.path)
            } else {
              remove_dot_segments(merge_paths(base, r.path))
            }
            (p, r.query)
          }
          {
            scheme: base.scheme,
            authority: base.authority,
            path,
            query,
            fragment: r.fragment,
          }
        }
      }
  }
}

///|
/// RFC 3986 Section 5.2.3 `merge`.
fn merge_paths(base : UriReference, ref_path : String) -> String {
  if base.authority is Some(_) && base.path == "" {
    return "/" + ref_path
  }
  let p = @utf8.encode(base.path)
  let mut idx : Int = -1
  for i = 0; i < p.length(); i = i + 1 {
    if p[i] == 47 {
      idx = i
    }
  }
  let prefix = if idx >= 0 {
    decode_utf8(p.view(start=0, end=idx + 1))
  } else {
    ""
  }
  prefix + ref_path
}
