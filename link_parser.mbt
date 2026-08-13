// link_parser.mbt — RFC 8288 `Link` header field parser.
//
// Grammar (RFC 8288 Section 3):
//
//     Link       = #link-value
//     link-value = "<" URI-Reference ">" *( OWS ";" OWS link-param )
//     link-param = token BWS [ "=" BWS ( token / quoted-string ) ]
//
// The `#link-value` rule is the RFC 7230 list rule: empty elements are
// allowed and ignored. Duplicate occurrences of the single-occurrence
// parameters (`rel`, `anchor`, `media`, `title`, `title*`, `type`) are
// ignored after the first per RFC 8288 Sections 3.2-3.4, but their names
// are recorded in `LinkHeaderParse::duplicates()` so that the audit layer
// can flag them.
//
// Targets may be IRIs (RFC 8288 Section 3.1 permits a target IRI that is
// converted to a URI); pure-ASCII targets are validated strictly as RFC 3986
// URI-references.
//
// Every public entry point returns `Result[T, LinkError]`; internal
// functions raise and the boundary converts to `Result`.

///|
/// The result of parsing a full `Link` header field value.
pub struct LinkHeaderParse {
  links : Array[WebLink]
  duplicates : Array[String]
}

///|
/// The parsed links, in input order.
pub fn LinkHeaderParse::links(self : LinkHeaderParse) -> Array[WebLink] {
  self.links
}

///|
/// The names of the single-occurrence parameters that appeared more than
/// once and whose later occurrences were ignored, in first-seen order.
pub fn LinkHeaderParse::duplicates(self : LinkHeaderParse) -> Array[String] {
  self.duplicates
}

///|
/// Parses a `Link` header field value into an array of links.
///
/// Errors: `Input::EmptyInput` (no link present), `Input::LimitExceeded`
/// (input larger than `max_input_bytes`), `Limit::LimitExceeded`, plus the
/// `Target`, `Parameter`, `Relation`, `QuotedString`, `ExtendedValue`,
/// `UriReference` and `Header` errors raised while parsing a link.
pub fn parse_link_header(
  input : String,
  limits : Limits,
) -> Result[Array[WebLink], LinkError] {
  match parse_link_header_detailed(input, limits) {
    Ok(p) => Ok(p.links)
    Err(e) => Err(e)
  }
}

///|
/// Parses a `Link` header field value, also returning the names of ignored
/// duplicate parameters (see `LinkHeaderParse`).
pub fn parse_link_header_detailed(
  input : String,
  limits : Limits,
) -> Result[LinkHeaderParse, LinkError] {
  let input_bytes = @utf8.encode(input)
  if input_bytes.length() > limits.max_input_bytes() {
    return Err(
      link_error(Input, LimitExceeded, "input exceeds max_input_bytes"),
    )
  }
  Ok(parse_links_from_cursor(Scanner::new(input), limits)) catch {
    e => Err(unwrap_link_error(e))
  }
}

///|
/// Parses a run of link-values from an already-created cursor. Shared by the
/// `Link` header parser (SP / HTAB separators only) and the
/// `application/linkset` text parser (newlines also allowed, RFC 9264
/// Section 4.1).
fn parse_links_from_cursor(
  cursor : Scanner,
  limits : Limits,
) -> LinkHeaderParse raise {
  cursor.skip_ows()
  if cursor.eof() {
    raise link_error(Input, EmptyInput, "empty link collection")
  }

  let links = Array::new()
  let duplicates = Array::new()

  // Skip leading empty list elements ("#link-value" allows them). A header
  // that is only empty elements carries no link at all.
  while cursor.consume_char(44) {
    cursor.skip_ows()
  }
  if cursor.eof() {
    raise link_error(Input, EmptyInput, "empty link collection")
  }

  let mut done = false
  while !done {
    let link = parse_link_value(cursor, limits, duplicates)
    links.push(link)
    if links.length() > limits.max_links() {
      raise link_error(
        Limit,
        LimitExceeded,
        "too many links (exceeds max_links)",
      )
    }
    cursor.skip_ows()
    if cursor.eof() {
      done = true
    } else if cursor.consume_char(44) {
      cursor.skip_ows()
      // Skip empty elements between links.
      while cursor.consume_char(44) {
        cursor.skip_ows()
      }
      if cursor.eof() {
        done = true
      }
    } else {
      raise link_error_at(
        Header,
        TrailingInput,
        cursor.position(),
        cursor.context_string(),
      )
    }
  }

  if links.is_empty() {
    raise link_error(Input, EmptyInput, "link collection contains no links")
  }
  { links, duplicates }
}

///|
/// Parses a single link-value starting at `<`, consuming the target and
/// all parameters. The cursor is left just after the last parameter.
fn parse_link_value(
  cursor : Scanner,
  limits : Limits,
  duplicates : Array[String],
) -> WebLink raise {
  // --- target ---------------------------------------------------------
  if !cursor.consume_char(60) {
    raise link_error_at(
      Target,
      ExpectedAngleBracket,
      cursor.position(),
      cursor.context_string(),
    )
  }
  let target_start = cursor.position()
  let mut done = false
  while !done {
    match cursor.peek_byte() {
      Some(62) => done = true
      Some(b) => {
        if b == 60 || b == 34 || b == 32 || is_bad_control(b) {
          raise link_error_at(
            Target,
            InvalidTarget,
            cursor.position(),
            "character not allowed in link target",
          )
        }
        cursor.pos = cursor.pos + 1
      }
      None =>
        raise link_error_at(
          Target,
          UnterminatedTarget,
          target_start,
          cursor.context_string(),
        )
    }
    if cursor.position() - target_start > limits.max_target_bytes() {
      raise link_error_at(
        Limit,
        LimitExceeded,
        target_start,
        "target exceeds max_target_bytes",
      )
    }
  }
  let target = cursor.take_string(target_start, cursor.position())
  cursor.pos = cursor.pos + 1 // consume ">"
  if !valid_target_string(target) {
    raise link_error_at(
      Target,
      InvalidTarget,
      target_start,
      cursor.context_string(),
    )
  }

  // --- parameters ------------------------------------------------------
  let mut relations : Array[RelationType] = Array::new()
  let mut anchor : String? = None
  let mut anchor_seen = false
  let hreflang : Array[String] = Array::new()
  let mut media : String? = None
  let mut media_seen = false
  let mut title : String? = None
  let mut title_seen = false
  let mut title_star : ExtendedValue? = None
  let mut title_star_seen = false
  let mut media_type : String? = None
  let mut type_seen = false
  let extensions : Array[LinkParameter] = Array::new()
  let mut rel_seen = false
  let mut param_count = 0

  let mut params_done = false
  while !params_done {
    cursor.skip_ows()
    if !cursor.consume_char(59) {
      params_done = true
    } else {
      cursor.skip_ows()
      if param_count >= limits.max_params_per_link() {
        raise link_error_at(
          Limit,
          LimitExceeded,
          cursor.position(),
          "too many parameters per link (exceeds max_params_per_link)",
        )
      }
      param_count = param_count + 1
      let param = match parse_link_param(cursor, limits) {
        Ok(p) => p
        Err(e) => raise e
      }
      // Dispatch on the parameter name. RFC 8288's grammar inherits ABNF
      // (RFC 5234), whose string literals are case-insensitive, so `REL`,
      // `Anchor`, `TITLE*` etc. are recognized here case-insensitively.
      // Extension parameter names keep their original case in the model.
      // Single-occurrence parameters keep their first value; later
      // occurrences are ignored and their names recorded in `duplicates`.
      // Unknown parameters are preserved as extension parameters.
      match ascii_lowercase(param.name) {
        "rel" =>
          if rel_seen {
            mark_duplicate(duplicates, "rel")
          } else {
            rel_seen = true
            let value = require_value(param, "rel")
            let rels = match parse_relation_list(value, limits) {
              Ok(x) => x
              Err(e) => raise e
            }
            relations = rels
          }
        "anchor" =>
          if anchor_seen {
            mark_duplicate(duplicates, "anchor")
          } else {
            anchor_seen = true
            let value = require_value(param, "anchor")
            if !valid_target_string(value) {
              raise link_error_at(
                Parameter,
                InvalidContextValue,
                param.value_start,
                "anchor is not a valid URI-reference",
              )
            }
            anchor = Some(value)
          }
        "hreflang" => {
          let value = require_value(param, "hreflang")
          if !valid_language_tag(value) {
            raise link_error_at(
              Parameter,
              InvalidLanguageTag,
              param.value_start,
              "hreflang is not a valid Language-Tag",
            )
          }
          hreflang.push(value)
        }
        "media" =>
          if media_seen {
            mark_duplicate(duplicates, "media")
          } else {
            media_seen = true
            media = Some(require_value(param, "media"))
          }
        "title" =>
          if title_seen {
            mark_duplicate(duplicates, "title")
          } else {
            title_seen = true
            title = Some(require_value(param, "title"))
          }
        "title*" =>
          if title_star_seen {
            mark_duplicate(duplicates, "title*")
          } else {
            title_star_seen = true
            match param.value {
              Extended(ev) => title_star = Some(ev)
              _ =>
                raise link_error_at(
                  Parameter,
                  InvalidParameter,
                  param.value_start,
                  "title* must carry an extended value",
                )
            }
          }
        "type" =>
          if type_seen {
            mark_duplicate(duplicates, "type")
          } else {
            type_seen = true
            let value = require_value(param, "type")
            if !validate_media_type(value, limits) {
              raise link_error_at(
                Parameter,
                InvalidMediaType,
                param.value_start,
                "type is not a valid media type",
              )
            }
            media_type = Some(value)
          }
        "rev" => {
          // Deprecated by RFC 8288 Section 3.3. The value has the same ABNF
          // as `rel`; it is validated and preserved as an extension
          // parameter so the audit layer can flag it.
          let value = require_value(param, "rev")
          match parse_relation_list(value, limits) {
            Ok(_) => ()
            Err(e) => raise e
          }
          extensions.push({
            name: "rev",
            value: Some(value),
            quoted: was_quoted(param.value),
          })
        }
        _ => extensions.push(extension_parameter(param))
      }
    }
  }

  if relations.is_empty() {
    raise link_error_at(
      LinkValue,
      InvalidRelation,
      target_start,
      "link-value is missing the required rel parameter",
    )
  }

  {
    target,
    relations,
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
/// The value of a parameter as a plain string, or an error when the
/// parameter is a flag (`; foo`) or an extended value.
fn require_value(p : ParsedParameter, name : String) -> String raise {
  match p.value {
    Empty =>
      raise link_error_at(
        Parameter,
        InvalidParameter,
        p.value_start,
        "\{name} requires a value",
      )
    Token(v) => v
    Quoted(v) => v
    Extended(_) =>
      raise link_error_at(
        Parameter,
        InvalidParameter,
        p.value_start,
        "\{name} must not be an extended value",
      )
  }
}

///|
/// Converts a parsed parameter to a preserved extension parameter.
fn extension_parameter(p : ParsedParameter) -> LinkParameter {
  match p.value {
    Empty => { name: p.name, value: None, quoted: false }
    Token(v) => { name: p.name, value: Some(v), quoted: false }
    Quoted(v) => { name: p.name, value: Some(v), quoted: true }
    Extended(ev) =>
      { name: p.name, value: Some(serialize_extended_value(ev)), quoted: false }
  }
}

///|
/// Whether a raw value came from the quoted-string form.
fn was_quoted(v : RawParamValue) -> Bool {
  match v {
    Quoted(_) => true
    _ => false
  }
}

///|
/// Records a duplicate parameter name once.
fn mark_duplicate(duplicates : Array[String], name : String) -> Unit {
  let mut present = false
  for d in duplicates {
    if d == name {
      present = true
    }
  }
  if !present {
    duplicates.push(name)
  }
}

///|
/// Whether a string is acceptable as a link target or anchor value.
///
/// Pure-ASCII targets must parse strictly as RFC 3986 URI-references.
/// Targets containing non-ASCII bytes are treated as IRIs (RFC 8288
/// Section 3.1): every byte must be a valid UTF-8 continuation of the
/// string, ASCII bytes must be URI characters, and `%` must be followed by
/// two hex digits.
fn valid_target_string(target : String) -> Bool {
  let bytes = @utf8.encode(target)
  let mut non_ascii = false
  let mut i = 0
  while i < bytes.length() {
    let b = bytes[i]
    if b.to_int() >= 128 {
      non_ascii = true
      i = i + 1
      while i < bytes.length() &&
            bytes[i].to_int() >= 128 &&
            bytes[i].to_int() <= 191 {
        i = i + 1
      }
    } else if b == 37 {
      let h1 = if i + 1 < bytes.length() { bytes[i + 1] } else { 0 }
      let h2 = if i + 2 < bytes.length() { bytes[i + 2] } else { 0 }
      if !(is_hexdigit(h1) && is_hexdigit(h2)) {
        return false
      }
      i = i + 3
    } else if uri_pchar(b) || b == 47 || b == 63 || b == 35 {
      i = i + 1
    } else {
      return false
    }
  }
  if non_ascii {
    true
  } else {
    match parse_uri_reference(target) {
      Ok(_) => true
      Err(_) => false
    }
  }
}

///|
/// Whether a string is a valid media type (`type-name "/" subtype-name`
/// with optional RFC 7231 parameters).
fn validate_media_type(value : String, limits : Limits) -> Bool {
  let bytes = @utf8.encode(value)
  let len = bytes.length()
  let mut i = 0
  // type-name = 1*tchar
  let type_start = i
  while i < len && token_char(bytes[i]) {
    i = i + 1
  }
  if i == type_start || i >= len || bytes[i] != 47 {
    return false
  }
  i = i + 1
  // subtype-name = 1*tchar
  let sub_start = i
  while i < len && token_char(bytes[i]) {
    i = i + 1
  }
  if i == sub_start {
    return false
  }
  // optional parameters: *( OWS ";" OWS parameter )
  //   parameter = token "=" ( token / quoted-string )
  while i < len {
    if bytes[i] == 32 || bytes[i] == 9 {
      i = i + 1
    } else if bytes[i] == 59 {
      i = i + 1
      while i < len && (bytes[i] == 32 || bytes[i] == 9) {
        i = i + 1
      }
      let name_start = i
      while i < len && token_char(bytes[i]) {
        i = i + 1
      }
      if i == name_start {
        return false
      }
      while i < len && (bytes[i] == 32 || bytes[i] == 9) {
        i = i + 1
      }
      if i >= len || bytes[i] != 61 {
        return false
      }
      i = i + 1
      while i < len && (bytes[i] == 32 || bytes[i] == 9) {
        i = i + 1
      }
      if i < len && bytes[i] == 34 {
        // quoted-string value
        let sc = Scanner::new(value)
        sc.seek(i)
        let ok = try {
          let _q = parse_quoted_string(sc, limits)
          true
        } catch {
          _ => false
        }
        if !ok {
          return false
        }
        i = sc.position()
      } else {
        let val_start = i
        while i < len && token_char(bytes[i]) {
          i = i + 1
        }
        if i == val_start {
          return false
        }
      }
    } else {
      return false
    }
  }
  true
}
