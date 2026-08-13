// conversion.mbt — Conversions between the three link set representations.
//
// moon-weblink works on one model (`LinkSet` / `WebLink`) and three
// serializations: the HTTP `Link` header field value (RFC 8288 Section 3),
// the `application/linkset` text document (RFC 9264 Section 4.1), and the
// `application/linkset+json` document (RFC 9264 Section 4.2). This module
// is the bridge: every function goes through the shared model, so any pair
// of representations can be converted losslessly at the model level.
//
// The only intentional asymmetry is documented in linkset_json.mbt: the
// JSON format normalizes a multi-relation link to one link per relation
// type, because its structure is member-per-relation.
//
// All conversions are offline and deterministic.

///|
/// Parses a `Link` header field value and wraps the result as a `LinkSet`.
pub fn link_header_to_linkset(
  input : String,
  limits : Limits,
) -> Result[LinkSet, LinkError] {
  match parse_link_header(input, limits) {
    Ok(links) => Ok(LinkSet::from_links(links))
    Err(e) => Err(e)
  }
}

///|
/// Serializes a `LinkSet` as a `Link` header field value (RFC 8288).
/// This is the canonical, deterministic serialization shared by
/// `canonicalize_link_header` and the CLI `format` subcommand.
pub fn linkset_to_link_header(linkset : LinkSet) -> String {
  serialize_link_header(linkset.links())
}

///|
/// Parses an `application/linkset` document and returns its canonical
/// `Link` header field value.
pub fn linkset_text_to_link_header(
  input : String,
  limits : Limits,
) -> Result[String, LinkError] {
  match parse_linkset_text(input, limits) {
    Ok(set) => Ok(serialize_link_header(set.links()))
    Err(e) => Err(e)
  }
}

///|
/// Serializes a `LinkSet` as an `application/linkset` document.
pub fn linkset_to_linkset_text(linkset : LinkSet) -> String {
  serialize_linkset_text(linkset)
}

///|
/// Parses an `application/linkset+json` document and returns its canonical
/// `Link` header field value.
pub fn linkset_json_to_link_header(
  input : String,
  limits : Limits,
) -> Result[String, LinkError] {
  match parse_linkset_json(input, limits) {
    Ok(set) => Ok(serialize_link_header(set.links()))
    Err(e) => Err(e)
  }
}

///|
/// Parses a `Link` header field value and returns it as an
/// `application/linkset+json` document.
pub fn link_header_to_linkset_json(
  input : String,
  limits : Limits,
) -> Result[String, LinkError] {
  match parse_link_header(input, limits) {
    Ok(links) => Ok(serialize_linkset_json(LinkSet::from_links(links)))
    Err(e) => Err(e)
  }
}

///|
/// Parses an `application/linkset` document and returns it as an
/// `application/linkset+json` document.
pub fn linkset_text_to_linkset_json(
  input : String,
  limits : Limits,
) -> Result[String, LinkError] {
  match parse_linkset_text(input, limits) {
    Ok(set) => Ok(serialize_linkset_json(set))
    Err(e) => Err(e)
  }
}

///|
/// Parses an `application/linkset+json` document and returns it as an
/// `application/linkset` document.
pub fn linkset_json_to_linkset_text(
  input : String,
  limits : Limits,
) -> Result[String, LinkError] {
  match parse_linkset_json(input, limits) {
    Ok(set) => Ok(serialize_linkset_text(set))
    Err(e) => Err(e)
  }
}

///|
/// Canonicalizes a `Link` header field value via the model and re-serializes
/// it. Equivalent to `canonicalize_link_header`; kept here so all
/// conversions live in one module.
pub fn canonical_link_header(input : String) -> Result[String, LinkError] {
  canonicalize_link_header(input)
}
