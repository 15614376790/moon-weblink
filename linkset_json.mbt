// linkset_json.mbt — RFC 9264 `application/linkset+json` format.
//
// The JSON format represents the abstract link model (RFC 8288 Section 2)
// as a document whose top-level object has "linkset" as its sole member
// (RFC 9264 Section 4.2.1):
//
//     { "linkset": [ <link context object>, ... ] }
//
// A link context object (Section 4.2.2) groups links with the same context:
// it MAY carry an "anchor" member naming the context, and one additional
// member per distinct relation type — a link target object (Section 4.2.3)
// with an "href" member plus optional target attributes (Section 4.2.4).
//
// Two structural consequences are worth stating explicitly:
//
//   - A model link with several relation types is emitted under each of
//     those relation-type members, so JSON round-trips normalize to one
//     relation per link. This matches the format's member-per-relation
//     design; the text format (RFC 8288 `rel`) is the one that preserves a
//     multi-value relation set in a single link.
//   - A bare extension parameter (no value) cannot be represented as a JSON
//     string member and serializes as the empty string, and back as a
//     parameter with an empty value. Value-less parameters are the only
//     information the JSON format cannot carry, per its own rules.
//
// Determinism: the serializer emits context objects in first-appearance
// order, relation members in sorted name order, and target objects in
// first-appearance order. Extension member names are also sorted. The parser
// sorts relation member names and extension member names the same way, so
// `serialize_linkset_json(parse_linkset_json(j)) == j` is a fixed point for
// every model that came out of the parser.

///|
/// Serializes a `LinkSet` as an `application/linkset+json` document. The
/// output is deterministic (stable member order, UTF-8, escaped strings).
pub fn serialize_linkset_json(linkset : LinkSet) -> String {
  let links = linkset.links()
  let contexts : Array[String?] = Array::new()
  for link in links {
    if !context_seen(contexts, link.anchor()) {
      contexts.push(link.anchor())
    }
  }
  let sb = StringBuilder()
  sb.write_string("{\n")
  sb.write_string("  \"linkset\": [\n")
  for i = 0; i < contexts.length(); i = i + 1 {
    if i > 0 {
      sb.write_string(",\n")
    }
    sb.write_string(emit_context_object(links, contexts[i], 2))
  }
  sb.write_string("\n  ]\n")
  sb.write_string("}")
  sb.to_string()
}

///|
/// Parses an `application/linkset+json` document into a `LinkSet`. Relation
/// members are visited in sorted name order so the result is independent of
/// JSON object key iteration order. Each (relation, target) pair becomes one
/// link carrying a single relation type.
pub fn parse_linkset_json(
  input : String,
  limits : Limits,
) -> Result[LinkSet, LinkError] {
  let input_bytes = @utf8.encode(input)
  if input_bytes.length() > limits.max_json_bytes() {
    return Err(
      link_error(Input, LimitExceeded, "JSON input exceeds max_json_bytes"),
    )
  }
  let root = @json.parse(input) catch {
    e => return Err(link_error(LinksetJson, InvalidJson, "invalid JSON: \{e}"))
  }
  parse_linkset_root(root)
}

///|
fn parse_linkset_root(root : Json) -> Result[LinkSet, LinkError] {
  match json_object(root) {
    None =>
      Err(
        link_error(
          LinksetJson,
          InvalidJsonShape,
          "top-level value is not a JSON object",
        ),
      )
    Some(members) => {
      // RFC 9264 Section 4.2.1: "linkset" must be the sole member.
      let keys = map_keys(members)
      if !array_contains(keys, "linkset") {
        return Err(
          link_error(
            LinksetJson,
            InvalidJsonShape,
            "missing \"linkset\" member",
          ),
        )
      }
      if keys.length() != 1 {
        return Err(
          link_error(
            LinksetJson,
            InvalidJsonShape,
            "\"linkset\" must be the sole top-level member",
          ),
        )
      }
      match members.get("linkset") {
        None =>
          Err(
            link_error(
              LinksetJson,
              InvalidJsonShape,
              "missing \"linkset\" member",
            ),
          )
        Some(arr) =>
          match json_array(arr) {
            None =>
              Err(
                link_error(
                  LinksetJson,
                  InvalidJsonShape,
                  "\"linkset\" value is not an array",
                ),
              )
            Some(contexts) => parse_context_array(contexts)
          }
      }
    }
  }
}

///|
fn parse_context_array(contexts : Array[Json]) -> Result[LinkSet, LinkError] {
  let set = LinkSet::new()
  for ctx in contexts {
    let links = parse_context_object(ctx) catch {
      e => return Err(unwrap_link_error(e))
    }
    for link in links {
      set.add(link)
    }
  }
  Ok(set)
}

///|
/// Parses one link context object. Raises `LinkError` on a structural
/// violation of RFC 9264 Section 4.2.2 / 4.2.3.
fn parse_context_object(ctx : Json) -> Array[WebLink] raise {
  let members = match json_object(ctx) {
    Some(m) => m
    None =>
      raise link_error(
        LinksetJson,
        InvalidJsonShape,
        "link context object is not a JSON object",
      )
  }
  let anchor : String? = match members.get("anchor") {
    None => None
    Some(a) =>
      match json_string(a) {
        Some(s) => Some(s)
        None =>
          raise link_error(
            LinksetJson,
            InvalidJsonShape,
            "\"anchor\" is not a string",
          )
      }
  }

  let keys = map_keys(members)
  let rel_keys : Array[String] = Array::new()
  for key in keys {
    if key != "anchor" {
      rel_keys.push(key)
    }
  }
  rel_keys.sort()

  let out : Array[WebLink] = Array::new()
  for rel in rel_keys {
    match members.get(rel) {
      None => ()
      Some(targets_json) => {
        let targets = match json_array(targets_json) {
          Some(t) => t
          None =>
            raise link_error(
              LinksetJson,
              InvalidJsonShape,
              "relation member \"\{rel}\" is not an array",
            )
        }
        for target_json in targets {
          out.push(parse_target_object(target_json, rel, anchor))
        }
      }
    }
  }
  out
}

///|
/// Parses one link target object into a single-relation `WebLink`.
fn parse_target_object(
  target_json : Json,
  relation : String,
  anchor : String?,
) -> WebLink raise {
  let members = match json_object(target_json) {
    Some(m) => m
    None =>
      raise link_error(
        LinksetJson,
        InvalidJsonShape,
        "link target object is not a JSON object",
      )
  }

  // RFC 9264 Section 4.2.3: "href" is mandatory.
  let href = match members.get("href") {
    Some(h) =>
      match json_string(h) {
        Some(s) => s
        None =>
          raise link_error(
            LinksetJson,
            InvalidJsonShape,
            "\"href\" is not a string",
          )
      }
    None =>
      raise link_error(
        LinksetJson,
        InvalidJsonShape,
        "link target object is missing \"href\"",
      )
  }

  let hreflang : Array[String] = Array::new()
  match members.get("hreflang") {
    None => ()
    Some(v) =>
      match json_array(v) {
        None =>
          raise link_error(
            LinksetJson,
            InvalidJsonShape,
            "\"hreflang\" is not an array",
          )
        Some(arr) =>
          for item in arr {
            match json_string(item) {
              Some(s) => hreflang.push(s)
              None =>
                raise link_error(
                  LinksetJson,
                  InvalidJsonShape,
                  "\"hreflang\" value is not a string",
                )
            }
          }
      }
  }

  let media : String? = opt_string(members, "media")
  let title : String? = opt_string(members, "title")
  let media_type : String? = opt_string(members, "type")

  let title_star : ExtendedValue? = match members.get("title*") {
    None => None
    Some(v) => Some(parse_intl_array(v, "title*"))
  }

  // Every remaining member is an extension target attribute (repeatable).
  let extensions : Array[LinkParameter] = Array::new()
  let keys = map_keys(members)
  keys.sort()
  for key in keys {
    if key == "href" ||
      key == "hreflang" ||
      key == "media" ||
      key == "title" ||
      key == "title*" ||
      key == "type" {
      continue
    }
    let value_json = match members.get(key) {
      Some(v) => v
      None => continue
    }
    let arr = match json_array(value_json) {
      Some(a) => a
      None =>
        raise link_error(
          LinksetJson,
          InvalidJsonShape,
          "extension attribute \"\{key}\" is not an array",
        )
    }
    if is_ext_value_name(key) {
      for item in arr {
        let ev = parse_intl_array_item(item, key)
        extensions.push({
          name: key,
          value: Some(serialize_extended_value(ev)),
          quoted: false,
        })
      }
    } else {
      for item in arr {
        let s = match json_string(item) {
          Some(s) => s
          None =>
            raise link_error(
              LinksetJson,
              InvalidJsonShape,
              "extension attribute \"\{key}\" value is not a string",
            )
        }
        extensions.push({ name: key, value: Some(s), quoted: false })
      }
    }
  }

  {
    target: href,
    relations: [make_relation(relation)],
    anchor,
    hreflang,
    media,
    title,
    title_star,
    media_type,
    extensions,
  }
}

///|
/// Reads an optional string member, raising on a non-string value.
fn opt_string(members : Map[String, Json], key : String) -> String? raise {
  match members.get(key) {
    None => None
    Some(v) =>
      match json_string(v) {
        Some(s) => Some(s)
        None =>
          raise link_error(
            LinksetJson,
            InvalidJsonShape,
            "\"\{key}\" is not a string",
          )
      }
  }
}

///|
/// Parses an internationalized attribute value array (Section 4.2.4.2):
/// one or more objects with "value" and optional "language".
fn parse_intl_array(v : Json, key : String) -> ExtendedValue raise {
  let arr = match json_array(v) {
    Some(a) => a
    None =>
      raise link_error(
        LinksetJson,
        InvalidJsonShape,
        "\"\{key}\" is not an array",
      )
  }
  if arr.is_empty() {
    raise link_error(
      LinksetJson,
      InvalidJsonShape,
      "\"\{key}\" must contain at least one value",
    )
  }
  if arr.length() > 1 {
    raise link_error(
      LinksetJson,
      InvalidJsonShape,
      "\"\{key}\" (a non-repeatable attribute) has more than one value",
    )
  }
  parse_intl_array_item(arr[0], key)
}

///|
fn parse_intl_array_item(item : Json, key : String) -> ExtendedValue raise {
  let members = match json_object(item) {
    Some(m) => m
    None =>
      raise link_error(
        LinksetJson,
        InvalidJsonShape,
        "\"\{key}\" element is not an object",
      )
  }
  let value = match members.get("value") {
    Some(v) =>
      match json_string(v) {
        Some(s) => s
        None =>
          raise link_error(
            LinksetJson,
            InvalidJsonShape,
            "\"\{key}\" element is missing a string \"value\"",
          )
      }
    None =>
      raise link_error(
        LinksetJson,
        InvalidJsonShape,
        "\"\{key}\" element is missing \"value\"",
      )
  }
  let language : String? = match members.get("language") {
    None => None
    Some(v) =>
      match json_string(v) {
        Some(s) => Some(s)
        None =>
          raise link_error(
            LinksetJson,
            InvalidJsonShape,
            "\"\{key}\" element has a non-string \"language\"",
          )
      }
  }
  // The JSON format does not carry the charset; it is always UTF-8.
  { charset: "UTF-8", language, value }
}

///|
/// Builds a relation type from a JSON member name: an absolute URI is an
/// extension relation type, everything else is a registered name.
fn make_relation(name : String) -> RelationType {
  if is_absolute_uri_reference(name) {
    Extension(name)
  } else {
    Registered(name)
  }
}

///|
/// The keys of a JSON object, in map iteration order (sorted by callers).
fn map_keys(members : Map[String, Json]) -> Array[String] {
  let out : Array[String] = Array::new()
  for k in members.keys() {
    out.push(k)
  }
  out
}

///|
/// Non-deprecated alternatives to `Json::as_*` (which the core library marks
/// deprecated). Pattern matching on the `Json` enum directly.
fn json_string(j : Json) -> String? {
  match j {
    String(s) => Some(s)
    _ => None
  }
}

///|
fn json_array(j : Json) -> Array[Json]? {
  match j {
    Array(a) => Some(a)
    _ => None
  }
}

///|
fn json_object(j : Json) -> Map[String, Json]? {
  match j {
    Object(m) => Some(m)
    _ => None
  }
}

// ---------------------------------------------------------------------------
// Serialization helpers
// ---------------------------------------------------------------------------

///|
fn emit_context_object(
  links : Array[WebLink],
  context : String?,
  depth : Int,
) -> String {
  let sb = StringBuilder()
  sb.write_string(indent_str(depth))
  sb.write_string("{\n")

  let members : Array[String] = Array::new()
  match context {
    Some(a) => members.push("\"anchor\": \{json_quote(a)}")
    None => ()
  }

  let rels : Array[String] = Array::new()
  for link in links {
    if contexts_equal(link.anchor(), context) {
      for rt in link.relations() {
        let text = relation_text(rt)
        if !array_contains(rels, text) {
          rels.push(text)
        }
      }
    }
  }
  rels.sort()
  for rel in rels {
    members.push(emit_rel_member(links, context, rel, depth + 1))
  }

  for i = 0; i < members.length(); i = i + 1 {
    if i > 0 {
      sb.write_string(",\n")
    }
    sb.write_string(indent_str(depth + 1))
    sb.write_string(members[i])
  }
  sb.write_string("\n")
  sb.write_string(indent_str(depth))
  sb.write_string("}")
  sb.to_string()
}

///|
fn emit_rel_member(
  links : Array[WebLink],
  context : String?,
  rel : String,
  depth : Int,
) -> String {
  let sb = StringBuilder()
  sb.write_string("\"")
  sb.write_string(json_escape(rel))
  sb.write_string("\": [\n")
  let mut first_target = true
  for link in links {
    if contexts_equal(link.anchor(), context) && link.has_relation(rel) {
      if !first_target {
        sb.write_string(",\n")
      }
      first_target = false
      sb.write_string(indent_str(depth + 1))
      sb.write_string(emit_target_object(link, depth + 1))
    }
  }
  sb.write_string("\n")
  sb.write_string(indent_str(depth))
  sb.write_string("]")
  sb.to_string()
}

///|
fn emit_target_object(link : WebLink, depth : Int) -> String {
  let sb = StringBuilder()
  sb.write_string("{\n")
  let members : Array[String] = Array::new()
  members.push("\"href\": \{json_quote(link.target())}")

  if !link.hreflang().is_empty() {
    let vals : Array[String] = Array::new()
    for h in link.hreflang() {
      vals.push(json_quote(h))
    }
    members.push("\"hreflang\": [\{join_strings(vals, ", ")}]")
  }
  match link.media() {
    Some(m) => members.push("\"media\": \{json_quote(m)}")
    None => ()
  }
  match link.title() {
    Some(t) => members.push("\"title\": \{json_quote(t)}")
    None => ()
  }
  match link.title_star() {
    Some(ev) => members.push("\"title*\": [\{emit_intl_object(ev)}]")
    None => ()
  }
  match link.media_type() {
    Some(t) => members.push("\"type\": \{json_quote(t)}")
    None => ()
  }
  for member in extension_members(link) {
    members.push(member)
  }

  for i = 0; i < members.length(); i = i + 1 {
    if i > 0 {
      sb.write_string(",\n")
    }
    sb.write_string(indent_str(depth + 1))
    sb.write_string(members[i])
  }
  sb.write_string("\n")
  sb.write_string(indent_str(depth))
  sb.write_string("}")
  sb.to_string()
}

///|
/// Builds one JSON member per distinct extension parameter name, with the
/// parameter values in an array (RFC 9264 Section 4.2.4.3). Parameters with
/// a trailing `*` follow the internationalized form. Member names are sorted
/// so the emitted object does not depend on model extension order.
fn extension_members(link : WebLink) -> Array[String] {
  let names : Array[String] = Array::new()
  for p in link.extensions() {
    if !array_contains(names, p.name()) {
      names.push(p.name())
    }
  }
  names.sort()
  let members : Array[String] = Array::new()
  for name in names {
    let vals : Array[String] = Array::new()
    for p in link.extensions() {
      if p.name() == name {
        vals.push(extension_value_json(name, p.value()))
      }
    }
    members.push("\"\{json_escape(name)}\": [\{join_strings(vals, ", ")}]")
  }
  members
}

///|
fn extension_value_json(name : String, value : String?) -> String {
  if is_ext_value_name(name) {
    match value {
      Some(raw) =>
        match parse_extended_value_string(raw) {
          Ok(ev) => emit_intl_object(ev)
          Err(_) => json_quote("")
        }
      None => json_quote("")
    }
  } else {
    match value {
      Some(v) => json_quote(v)
      None => json_quote("")
    }
  }
}

///|
fn emit_intl_object(ev : ExtendedValue) -> String {
  let sb = StringBuilder()
  sb.write_string("{ \"value\": \{json_quote(ev.value())}")
  match ev.language() {
    Some(l) => sb.write_string(", \"language\": \{json_quote(l)}")
    None => ()
  }
  sb.write_string(" }")
  sb.to_string()
}

// ---------------------------------------------------------------------------
// Small utilities
// ---------------------------------------------------------------------------

///|
fn relation_text(rt : RelationType) -> String {
  match rt {
    Registered(name) => name
    Extension(uri) => uri
  }
}

///|
fn context_seen(contexts : Array[String?], key : String?) -> Bool {
  for c in contexts {
    if contexts_equal(c, key) {
      return true
    }
  }
  false
}

///|
fn contexts_equal(a : String?, b : String?) -> Bool {
  match (a, b) {
    (Some(x), Some(y)) => x == y
    (None, None) => true
    _ => false
  }
}

///|
fn array_contains(arr : Array[String], value : String) -> Bool {
  for s in arr {
    if s == value {
      return true
    }
  }
  false
}

///|
fn join_strings(arr : Array[String], sep : String) -> String {
  let sb = StringBuilder()
  for i = 0; i < arr.length(); i = i + 1 {
    if i > 0 {
      sb.write_string(sep)
    }
    sb.write_string(arr[i])
  }
  sb.to_string()
}

///|
fn indent_str(depth : Int) -> String {
  let sb = StringBuilder()
  for _i = 0; _i < depth * 2; _i = _i + 1 {
    sb.write_char(' ')
  }
  sb.to_string()
}

///|
/// Wraps a string in JSON quotes with proper escaping.
fn json_quote(s : String) -> String {
  let sb = StringBuilder()
  sb.write_char('"')
  sb.write_string(json_escape(s))
  sb.write_char('"')
  sb.to_string()
}

///|
/// Escapes a string for inclusion in JSON: `"` and `\` are escaped, control
/// characters below 0x20 become `\u00XX`, everything else (including
/// non-ASCII) is emitted as UTF-8.
fn json_escape(s : String) -> String {
  let sb = StringBuilder()
  for c in s.iter() {
    let v = c.to_int()
    if v == 34 {
      sb.write_string("\\\"")
    } else if v == 92 {
      sb.write_string("\\\\")
    } else if v < 32 {
      sb.write_string("\\u00")
      sb.write_char(hex_digit(v / 16))
      sb.write_char(hex_digit(v % 16))
    } else {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
fn hex_digit(v : Int) -> Char {
  if v < 10 {
    (48 + v).unsafe_to_char()
  } else {
    (65 + v - 10).unsafe_to_char()
  }
}
