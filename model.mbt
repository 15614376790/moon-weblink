// model.mbt — Core data model for moon-weblink.
//
// The model follows the abstract Web Linking model of RFC 8288 Section 2:
// a link has a context, a target (URI-reference), a relation type set, and
// optional target attributes. In the HTTP serialisation the context is the
// `anchor` parameter (defaulting to the current representation), the target
// is the URI-reference inside the angle brackets, and the target attributes
// are `hreflang`, `media`, `title`, `title*` and `type` plus arbitrary
// extension attributes.
//
// Design notes:
//   - A link can carry several relation types (RFC 8288 Section 3.3: the
//     `rel` value is a space separated list); establishing a separate link
//     per relation is left to consumers and to the JSON conversion.
//   - `RelationType::Registered` is the token form (RFC 8288 Section 3.3
//     `reg-rel-type`). Its string is stored exactly as parsed (including
//     case) so that parsing and serialising round-trips byte-for-byte;
//     comparison is case-insensitive per RFC 8288 Section 2.1.1.
//   - `RelationType::Extension` is an absolute URI (RFC 8288 `ext-rel-type`).
//   - `title_star` carries the RFC 8187 extended value. RFC 8288 says that
//     when both `title` and `title*` are present, applications SHOULD use
//     the `title*` value; the model preserves both.
//   - The deprecated `rev` parameter is preserved as an ordinary extension
//     parameter so no information is lost; the audit layer flags it.
//   - `extensions` keeps every parameter that is not a serialisation-defined
//     attribute, including duplicates, in input order.

///|
/// The relation type of a link. `Registered` is the token form; `Extension`
/// is an absolute URI.
pub enum RelationType {
  Registered(String)
  Extension(String)
}

///|
/// An RFC 8187 extended value (used by `title*` and `name*` parameters):
/// a charset, an optional language tag, and the decoded value.
pub struct ExtendedValue {
  charset : String
  language : String?
  value : String
}

///|
/// A single link parameter. `value` is the unquoted content; `quoted`
/// records whether the original serialisation used the quoted-string form
/// (used to preserve round-trip fidelity for extension parameters).
pub struct LinkParameter {
  name : String
  value : String?
  quoted : Bool
}

///|
/// One parsed link. `target` is the URI-reference inside the angle
/// brackets; `relations` the relation types of the `rel` parameter;
/// `anchor` the optional overriding context; `hreflang` the repeatable
/// language hint; `media`, `title`, `title_star` and `media_type` the
/// serialisation-defined target attributes; `extensions` every other
/// parameter in input order.
pub struct WebLink {
  target : String
  relations : Array[RelationType]
  anchor : String?
  hreflang : Array[String]
  media : String?
  title : String?
  title_star : ExtendedValue?
  media_type : String?
  extensions : Array[LinkParameter]
}

///|
/// A set of links. This is the model shared by the HTTP `Link` header
/// field, the `application/linkset` text format and the
/// `application/linkset+json` format.
pub struct LinkSet {
  links : Array[WebLink]
}

///|
/// Constructs an empty `LinkSet`.
pub fn LinkSet::new() -> LinkSet {
  { links: Array::new() }
}

///|
/// Constructs a `LinkSet` holding the given links, in order.
pub fn LinkSet::from_links(links : Array[WebLink]) -> LinkSet {
  { links, }
}

///|
/// Constructs a `WebLink` with the given target and no parameters.
pub fn web_link(target : String) -> WebLink {
  {
    target,
    relations: Array::new(),
    anchor: None,
    hreflang: Array::new(),
    media: None,
    title: None,
    title_star: None,
    media_type: None,
    extensions: Array::new(),
  }
}

///|
/// The links in this set, in order.
pub fn LinkSet::links(self : LinkSet) -> Array[WebLink] {
  self.links
}

///|
/// The number of links in this set.
pub fn LinkSet::link_count(self : LinkSet) -> Int {
  self.links.length()
}

///|
/// Whether the set contains no links.
pub fn LinkSet::is_empty(self : LinkSet) -> Bool {
  self.links.is_empty()
}

///|
/// Appends a link to the set.
pub fn LinkSet::add(self : LinkSet, link : WebLink) -> Unit {
  self.links.push(link)
}

///|
/// The link target (URI-reference).
pub fn WebLink::target(self : WebLink) -> String {
  self.target
}

///|
/// The relation types of this link.
pub fn WebLink::relations(self : WebLink) -> Array[RelationType] {
  self.relations
}

///|
/// The optional overriding link context.
pub fn WebLink::anchor(self : WebLink) -> String? {
  self.anchor
}

///|
/// The repeatable `hreflang` values.
pub fn WebLink::hreflang(self : WebLink) -> Array[String] {
  self.hreflang
}

///|
/// The `media` target attribute, if present.
pub fn WebLink::media(self : WebLink) -> String? {
  self.media
}

///|
/// The `title` target attribute, if present.
pub fn WebLink::title(self : WebLink) -> String? {
  self.title
}

///|
/// The `title*` target attribute, if present.
pub fn WebLink::title_star(self : WebLink) -> ExtendedValue? {
  self.title_star
}

///|
/// The `type` target attribute, if present.
pub fn WebLink::media_type(self : WebLink) -> String? {
  self.media_type
}

///|
/// The extension parameters, in input order.
pub fn WebLink::extensions(self : WebLink) -> Array[LinkParameter] {
  self.extensions
}

///|
/// The charset of this extended value.
pub fn ExtendedValue::charset(self : ExtendedValue) -> String {
  self.charset
}

///|
/// The optional language tag of this extended value.
pub fn ExtendedValue::language(self : ExtendedValue) -> String? {
  self.language
}

///|
/// The decoded value of this extended value.
pub fn ExtendedValue::value(self : ExtendedValue) -> String {
  self.value
}

///|
/// The parameter name.
pub fn LinkParameter::name(self : LinkParameter) -> String {
  self.name
}

///|
/// The parameter value (unquoted), if present.
pub fn LinkParameter::value(self : LinkParameter) -> String? {
  self.value
}

///|
/// Whether the original serialisation used the quoted-string form.
pub fn LinkParameter::quoted(self : LinkParameter) -> Bool {
  self.quoted
}

///|
/// The relation name of a registered (token) relation type.
pub fn RelationType::name(self : RelationType) -> String? {
  match self {
    Registered(name) => Some(name)
    Extension(_) => None
  }
}

///|
/// The extension URI of an extension relation type.
pub fn RelationType::extension_uri(self : RelationType) -> String? {
  match self {
    Registered(_) => None
    Extension(uri) => Some(uri)
  }
}

///|
/// Whether this is the registered (token) form.
pub fn RelationType::is_registered(self : RelationType) -> Bool {
  match self {
    Registered(_) => true
    Extension(_) => false
  }
}

///|
/// Whether this is the extension (absolute URI) form.
pub fn RelationType::is_extension(self : RelationType) -> Bool {
  match self {
    Registered(_) => false
    Extension(_) => true
  }
}

///|
/// Whether this relation type matches the given name or URI.
///
/// Registered relation types are compared case-insensitively
/// (RFC 8288 Section 2.1.1); extension relation types are compared as
/// exact strings (RFC 8288 Section 2.1.2).
pub fn RelationType::matches(self : RelationType, name : String) -> Bool {
  match self {
    Registered(n) => n.equal_ignore_ascii_case(name)
    Extension(uri) => uri == name
  }
}

///|
/// Whether any relation of this link matches the given name or URI.
pub fn WebLink::has_relation(self : WebLink, name : String) -> Bool {
  self.relations.any(fn(rt) { rt.matches(name) })
}

///|
/// The relation names/URIs of this link as plain strings, in order.
pub fn WebLink::relation_names(self : WebLink) -> Array[String] {
  let out = Array::new()
  for rt in self.relations {
    match rt {
      Registered(name) => out.push(name)
      Extension(uri) => out.push(uri)
    }
  }
  out
}
