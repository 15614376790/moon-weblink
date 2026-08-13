// relation.mbt — Link relation types (RFC 8288 Section 3.3).
//
// A relation type is either:
//   - registered: the token form (`reg-rel-type`), stored case-preserved
//     but compared case-insensitively, and
//   - extension: an absolute URI (`ext-rel-type`).
//
// The distinction is purely syntactic. Whether a registered-form name is
// actually present in the IANA registry is a separate question answered by
// the offline registry in `relation_registry.mbt`; an extension relation
// type is never rejected because it is missing from the registry.

///|
/// Parses a single relation type from a non-empty token string.
///
/// If the string is a valid absolute URI it is classified as an extension
/// relation type; otherwise it must be a valid token (RFC 7230 `tchar`) and
/// is classified as a registered relation type.
///
/// Errors: `Relation::InvalidRelation` and `Relation::InvalidExtensionRelation`.
pub fn parse_relation_type(token : String) -> Result[RelationType, LinkError] {
  if token.length() == 0 {
    return Err(link_error(Relation, InvalidRelation, "empty relation type"))
  }
  match parse_uri_reference(token) {
    Ok(uri) if uri.scheme() is Some(_) => Ok(Extension(token))
    Ok(_) =>
      if relation_token_valid(token) {
        Ok(Registered(token))
      } else {
        Err(
          link_error(
            Relation,
            InvalidRelation,
            "invalid registered relation type: \{token}",
          ),
        )
      }
    Err(_) =>
      if relation_token_valid(token) {
        Ok(Registered(token))
      } else {
        Err(
          link_error(
            Relation,
            InvalidRelation,
            "invalid relation type: \{token}",
          ),
        )
      }
  }
}

///|
/// Parses a `rel` value (a space separated list of relation types) into an
/// ordered array. Runs of SP are treated as a single separator, matching
/// the `1*SP` rule.
///
/// Errors: `Relation::InvalidRelation` and `Limit::LimitExceeded`.
pub fn parse_relation_list(
  value : String,
  limits : Limits,
) -> Result[Array[RelationType], LinkError] {
  let relations = Array::new()
  for part in split_on_spaces(value) {
    match parse_relation_type(part) {
      Ok(rt) => relations.push(rt)
      Err(e) => return Err(e)
    }
    if relations.length() > limits.max_relations_per_link() {
      return Err(
        link_error(
          Limit,
          LimitExceeded,
          "rel value exceeds max_relations_per_link",
        ),
      )
    }
  }
  if relations.is_empty() {
    return Err(
      link_error(
        Relation,
        InvalidRelation,
        "rel value contains no relation types",
      ),
    )
  }
  Ok(relations)
}

///|
/// Splits a string on runs of SP (0x20). Consecutive SP bytes collapse into
/// one separator; empty input yields an empty list.
pub fn split_on_spaces(value : String) -> Array[String] {
  let bytes = @utf8.encode(value)
  let out = Array::new()
  let mut i = 0
  while i < bytes.length() {
    if bytes[i] == 32 {
      i = i + 1
      continue
    }
    let start = i
    while i < bytes.length() && bytes[i] != 32 {
      i = i + 1
    }
    out.push(decode_utf8(bytes.view(start~, end=i)))
  }
  out
}

///|
/// Whether a string is a non-empty RFC 7230 token (all `tchar` bytes).
fn relation_token_valid(token : String) -> Bool {
  if token.length() == 0 {
    return false
  }
  let bytes = @utf8.encode(token)
  for i = 0; i < bytes.length(); i = i + 1 {
    if !token_char(bytes[i]) {
      return false
    }
  }
  true
}

///|
/// Whether a relation type is in the registered (token) form.
pub fn relation_type_is_registered(rt : RelationType) -> Bool {
  rt.is_registered()
}

///|
/// Whether a relation type is in the extension (absolute URI) form.
pub fn relation_type_is_extension(rt : RelationType) -> Bool {
  rt.is_extension()
}
