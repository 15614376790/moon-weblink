// linkset_text.mbt — RFC 9264 `application/linkset` text format.
//
// The text format is "nearly identical" to the field value of the HTTP
// `Link` header field (RFC 8288 Section 3): the same link-value grammar, in
// which link-values are separated by commas. RFC 9264 Section 4.1 makes it
// differ in exactly two ways:
//
//   - newline characters (CR and LF) are also permitted as whitespace around
//     the separators, alongside SP and HTAB, to improve readability;
//   - non-ASCII characters are not allowed.
//
// The parser therefore reuses the RFC 8288 link-value grammar through a
// newline-enabled scanner (see `parse_links_from_cursor` in link_parser.mbt)
// and rejects any byte >= 0x80. The serializer emits the RFC 8288 form with
// single SP / HTAB separators, which is valid both as an `application/linkset`
// document and, unchanged, as a `Link` header field value (RFC 9264 requires
// newlines to be removed when converting the other way).

///|
/// Parses an `application/linkset` document into a `LinkSet`. Newlines are
/// accepted as separators; non-ASCII bytes are rejected (RFC 9264
/// Section 4.1).
pub fn parse_linkset_text(
  input : String,
  limits : Limits,
) -> Result[LinkSet, LinkError] {
  let input_bytes = @utf8.encode(input)
  if input_bytes.length() > limits.max_input_bytes() {
    return Err(
      link_error(Input, LimitExceeded, "input exceeds max_input_bytes"),
    )
  }
  for i = 0; i < input_bytes.length(); i = i + 1 {
    if input_bytes[i].to_int() >= 128 {
      return Err(
        link_error_at(
          LinksetText,
          UnexpectedCharacter,
          i,
          "non-ASCII byte is not allowed in application/linkset",
        ),
      )
    }
  }
  try {
    let parsed = parse_links_from_cursor(Scanner::new_linkset(input), limits)
    Ok(LinkSet::from_links(parsed.links()))
  } catch {
    e => Err(unwrap_link_error(e))
  }
}

///|
/// Serializes a `LinkSet` as an `application/linkset` document using the
/// RFC 8288 field-value form (SP / HTAB separators, no newlines). The output
/// is also a valid `Link` header field value.
pub fn serialize_linkset_text(linkset : LinkSet) -> String {
  serialize_link_header(linkset.links())
}

///|
/// Serializes a `LinkSet` as an `application/linkset` document with one
/// link-value per line (newline separators, RFC 9264 Section 4.1). This is
/// the readable form for a standalone document; when embedding the result in
/// an HTTP header, replace the newlines with SP first.
pub fn serialize_linkset_text_multiline(linkset : LinkSet) -> String {
  let sb = StringBuilder()
  let links = linkset.links()
  for i = 0; i < links.length(); i = i + 1 {
    if i > 0 {
      sb.write_string(",\n")
    }
    sb.write_string(serialize_link(links[i]))
  }
  sb.to_string()
}
