// link_serializer.mbt — Deterministic RFC 8288 `Link` header serialization.
//
// The serializer is the inverse of `link_parser.mbt`. Its output is fully
// deterministic so that `canonicalize_link_header` (in canonicalize.mbt) is
// a well-defined idempotent function:
//
//   - the target is always the first element, in `<...>`,
//   - `rel` is always present and always quoted (RFC 8288 examples use the
//     quoted form), with relation types joined by a single SP,
//   - the single-occurrence target attributes `anchor`, `media`, `title`
//     and `type` are always quoted,
//   - `hreflang` is emitted once per value, always quoted, in input order,
//   - `title*` is emitted as an RFC 8187 extended value (never quoted,
//     because the parser treats a `name*` value as an ext-value),
//   - extension parameters are emitted in input order; their values use the
//     token form when every byte is a `tchar` and the quoted-string form
//     otherwise, and a `name*` extension parameter is emitted as an
//     unquoted ext-value.
//
// Round-trip guarantee: `parse_link_header(serialize_link_header(links))`
// is semantically equivalent to `links` for any model that came from the
// parser (quoting differences on extension parameters are not semantic).

///|
/// Serializes one link as a single `link-value`.
pub fn serialize_link(link : WebLink) -> String {
  let sb = StringBuilder()
  emit_link_value(sb, link)
  sb.to_string()
}

///|
/// Serializes a list of links as a `Link` header field value (a
/// comma-space separated list of link-values).
pub fn serialize_link_header(links : Array[WebLink]) -> String {
  let sb = StringBuilder()
  for i = 0; i < links.length(); i = i + 1 {
    if i > 0 {
      sb.write_string(", ")
    }
    emit_link_value(sb, links[i])
  }
  sb.to_string()
}

///|
/// Serializes a `LinkSet` as a `Link` header field value.
pub fn serialize_link_header_from_linkset(linkset : LinkSet) -> String {
  serialize_link_header(linkset.links())
}

///|
fn emit_link_value(sb : StringBuilder, link : WebLink) -> Unit {
  sb.write_char('<')
  sb.write_string(link.target())
  sb.write_char('>')

  // rel: always quoted, relation types joined by a single SP.
  sb.write_string("; rel=")
  emit_quoted(sb, relation_list_text(link.relations()))

  match link.anchor() {
    Some(a) => emit_quoted_param(sb, "anchor", a)
    None => ()
  }
  for hl in link.hreflang() {
    emit_quoted_param(sb, "hreflang", hl)
  }
  match link.media() {
    Some(m) => emit_quoted_param(sb, "media", m)
    None => ()
  }
  match link.title() {
    Some(t) => emit_quoted_param(sb, "title", t)
    None => ()
  }
  match link.title_star() {
    Some(ev) => {
      sb.write_string("; title*=")
      sb.write_string(serialize_extended_value(ev))
    }
    None => ()
  }
  match link.media_type() {
    Some(t) => emit_quoted_param(sb, "type", t)
    None => ()
  }
  for p in link.extensions() {
    emit_extension_param(sb, p)
  }
}

///|
fn relation_list_text(relations : Array[RelationType]) -> String {
  let sb = StringBuilder()
  for i = 0; i < relations.length(); i = i + 1 {
    if i > 0 {
      sb.write_char(' ')
    }
    match relations[i] {
      Registered(name) => sb.write_string(name)
      Extension(uri) => sb.write_string(uri)
    }
  }
  sb.to_string()
}

///|
/// Emits `; name="value"` with the value always quoted.
fn emit_quoted_param(sb : StringBuilder, name : String, value : String) -> Unit {
  sb.write_string("; ")
  sb.write_string(name)
  sb.write_char('=')
  emit_quoted(sb, value)
}

///|
fn emit_quoted(sb : StringBuilder, value : String) -> Unit {
  sb.write_string(serialize_quoted_string(value))
}

///|
/// Emits one extension parameter in a form the parser accepts. A `name*`
/// parameter is an RFC 8187 extended value and must be emitted unquoted
/// (its serialized value uses only ext-value bytes). Other values use the
/// token form when possible and the quoted-string form otherwise.
fn emit_extension_param(sb : StringBuilder, p : LinkParameter) -> Unit {
  sb.write_string("; ")
  sb.write_string(p.name())
  if is_ext_value_name(p.name()) {
    match p.value() {
      Some(v) => {
        sb.write_char('=')
        sb.write_string(v)
      }
      None => ()
    }
  } else {
    match p.value() {
      Some(v) => {
        sb.write_char('=')
        if can_be_token(v) {
          sb.write_string(v)
        } else {
          emit_quoted(sb, v)
        }
      }
      None => ()
    }
  }
}
