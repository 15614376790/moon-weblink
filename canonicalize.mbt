// canonicalize.mbt — Canonical `Link` header serialization.
//
// `canonicalize_link_header` parses an input `Link` header field value with
// the strict parser and re-serializes it with the deterministic serializer.
// Two inputs that carry the same link semantics therefore produce the same
// canonical output, and canonicalization is idempotent:
//
//     canonicalize(canonicalize(x)) == canonicalize(x)
//
// Canonicalization only normalizes the *syntax* (whitespace, quoting,
// list-element skipping, empty elements). It never changes the target, the
// relation set, the target attributes, or the relative order of repeatable
// and extension parameters, so it does not alter link semantics.

///|
/// Parses `input` with the default limits and returns its canonical
/// `Link` header serialization.
pub fn canonicalize_link_header(input : String) -> Result[String, LinkError] {
  canonicalize_link_header_with_limits(input, Limits::default())
}

///|
/// Parses `input` with the given limits and returns its canonical `Link`
/// header serialization. Any parse error is returned unchanged.
pub fn canonicalize_link_header_with_limits(
  input : String,
  limits : Limits,
) -> Result[String, LinkError] {
  match parse_link_header_detailed(input, limits) {
    Ok(parsed) => Ok(serialize_link_header(parsed.links()))
    Err(e) => Err(e)
  }
}

///|
/// Canonicalizes a single link-value string.
pub fn canonicalize_link_value(input : String) -> Result[String, LinkError] {
  match parse_link_header(input, Limits::default()) {
    Ok(links) => Ok(serialize_link_header(links))
    Err(e) => Err(e)
  }
}
