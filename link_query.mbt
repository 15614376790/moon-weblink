// link_query.mbt — Convenience query API over link collections.
//
// These helpers answer the questions Web Linking exists for: which links
// carry a relation, what their targets are, which links match a media type
// or language, and where `next` / `prev` / `canonical` / `alternate`
// point. They are pure functions over `Array[WebLink]`; they never fetch,
// never follow targets, and never require a network.
//
// Relation comparison follows `RelationType::matches`: registered relation
// types match case-insensitively, extension relation URIs exactly.

///|
/// The first link carrying the given relation, or `None`.
pub fn find_by_relation(links : Array[WebLink], relation : String) -> WebLink? {
  for l in links {
    if l.has_relation(relation) {
      return Some(l)
    }
  }
  None
}

///|
/// All links carrying the given relation, in order.
pub fn filter_by_relation(
  links : Array[WebLink],
  relation : String,
) -> Array[WebLink] {
  let out = Array::new()
  for l in links {
    if l.has_relation(relation) {
      out.push(l)
    }
  }
  out
}

///|
/// The targets of all links carrying the given relation, in order.
pub fn targets_for_relation(
  links : Array[WebLink],
  relation : String,
) -> Array[String] {
  let out = Array::new()
  for l in filter_by_relation(links, relation) {
    out.push(l.target())
  }
  out
}

///|
/// All links whose `type` target attribute equals `media_type`
/// (case-insensitive per RFC 6838 Section 4.2).
pub fn filter_by_type(
  links : Array[WebLink],
  media_type : String,
) -> Array[WebLink] {
  let out = Array::new()
  for l in links {
    match l.media_type() {
      Some(t) => if t.equal_ignore_ascii_case(media_type) { out.push(l) }
      None => ()
    }
  }
  out
}

///|
/// All links whose `hreflang` values include `lang` (case-insensitive
/// per RFC 5646 Section 2.1.1).
pub fn filter_by_hreflang(
  links : Array[WebLink],
  lang : String,
) -> Array[WebLink] {
  let out = Array::new()
  for l in links {
    if l.hreflang().any(fn(h) { h.equal_ignore_ascii_case(lang) }) {
      out.push(l)
    }
  }
  out
}

///|
/// The first link with relation `next`, or `None`.
pub fn find_next(links : Array[WebLink]) -> WebLink? {
  find_by_relation(links, "next")
}

///|
/// The first link with relation `prev`, or `None`.
pub fn find_prev(links : Array[WebLink]) -> WebLink? {
  find_by_relation(links, "prev")
}

///|
/// The first link with relation `canonical`, or `None`.
pub fn find_canonical(links : Array[WebLink]) -> WebLink? {
  find_by_relation(links, "canonical")
}

///|
/// All links with relation `alternate`, in order.
pub fn find_alternate(links : Array[WebLink]) -> Array[WebLink] {
  filter_by_relation(links, "alternate")
}
