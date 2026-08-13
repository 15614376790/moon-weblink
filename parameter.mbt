// parameter.mbt — RFC 8288 link-parameter parsing.
//
// RFC 8288 Section 3:
//
//     link-param = token BWS [ "=" BWS ( token / quoted-string ) ]
//
// Design decisions:
//
//   - Parameter *names* are strict RFC 7230 tokens (`tchar`), matching the
//     final RFC 8288 grammar exactly.
//
//   - Unquoted parameter *values* accept the broader `ptokenchar` set so
//     that common real-world values parse. The RFC's own `type` ABNF
//     (`type-name "/" subtype-name`) contains a `/` that the `token` rule
//     cannot express, so a strict `token`-only value parser would reject
//     `type=text/html`, which the RFC itself implies must work. The
//     accepted set is still bounded: it excludes SP, HTAB, DQUOTE, `;`,
//     `,`, and all control and non-ASCII bytes.
//
//   - A parameter whose name ends in `*` (for example `title*`) carries an
//     RFC 8187 extended value, parsed by `parse_extended_value`.
//
//   - Everything is a single pass over the byte cursor; no lookahead beyond
//     the current parameter.

///|
/// The raw form of a parsed parameter value, before it is dispatched to a
/// field of the link model.
pub enum RawParamValue {
  /// The parameter has no `=` and no value (`; foo`).
  Empty
  /// The value was the unquoted token form.
  Token(String)
  /// The value was the quoted-string form; the string is already unquoted.
  Quoted(String)
  /// The value of a `name*` parameter, decoded per RFC 8187.
  Extended(ExtendedValue)
}

///|
/// One parsed link-parameter: its name, the value form, and the byte offset
/// of the first byte of the value (used for error reporting).
pub struct ParsedParameter {
  name : String
  value_start : Int
  value : RawParamValue
}

///|
/// The parameter name.
pub fn ParsedParameter::name(self : ParsedParameter) -> String {
  self.name
}

///|
/// The byte offset of the first byte of the value.
pub fn ParsedParameter::value_start(self : ParsedParameter) -> Int {
  self.value_start
}

///|
/// The raw value form.
pub fn ParsedParameter::value(self : ParsedParameter) -> RawParamValue {
  self.value
}

///|
/// The value as a plain string: the unquoted content for the token and
/// quoted forms, or `None` for flag parameters and `name*` parameters
/// (which are not plain strings).
pub fn RawParamValue::as_string(self : RawParamValue) -> String? {
  match self {
    Empty => None
    Token(v) => Some(v)
    Quoted(v) => Some(v)
    Extended(_) => None
  }
}

///|
/// Whether the parameter has a value at all.
pub fn RawParamValue::has_value(self : RawParamValue) -> Bool {
  match self {
    Empty => false
    _ => true
  }
}

///|
/// Parses one link-parameter starting at the current scanner position.
/// On success the cursor is positioned immediately after the value (or
/// after the name, for flag parameters), before any following `;` or OWS.
///
/// Errors: `Parameter::MissingParameterName` (no token where a name is
/// required), `Parameter::InvalidParameter` (no value after `=`),
/// `Limit::LimitExceeded`, plus the quoted-string and extended-value
/// errors from `parse_quoted_string` and `parse_extended_value`.
pub fn parse_link_param(
  cursor : Scanner,
  limits : Limits,
) -> Result[ParsedParameter, LinkError] {
  let name_start = cursor.position()
  let (ns, ne) = cursor.consume_token()
  if ne == ns {
    return Err(
      link_error_at(
        Parameter,
        MissingParameterName,
        name_start,
        cursor.context_string(),
      ),
    )
  }
  if ne - ns > limits.max_parameter_name_bytes() {
    return Err(
      link_error_at(
        Limit,
        LimitExceeded,
        ns,
        "parameter name exceeds max_parameter_name_bytes",
      ),
    )
  }
  let name = cursor.take_string(ns, ne)

  // BWS around the "="
  cursor.skip_ows()
  if !cursor.consume_char(61) {
    return Ok({ name, value_start: cursor.position(), value: Empty })
  }
  cursor.skip_ows()
  let value_start = cursor.position()

  if ends_with_star(name) && name.length() > 1 {
    // RFC 8187 extended value
    let ev = parse_extended_value(cursor, limits) catch {
      e => return Err(unwrap_link_error(e))
    }
    if cursor.position() - value_start > limits.max_parameter_value_bytes() {
      return Err(
        link_error_at(
          Limit,
          LimitExceeded,
          value_start,
          "extended value exceeds max_parameter_value_bytes",
        ),
      )
    }
    return Ok({ name, value_start, value: Extended(ev) })
  }

  match cursor.peek_byte() {
    Some(34) => {
      // quoted-string
      let q = parse_quoted_string(cursor, limits) catch {
        e => return Err(unwrap_link_error(e))
      }
      Ok({ name, value_start, value: Quoted(q) })
    }
    _ => {
      // unquoted value: ptokenchar (documented lenient superset of token)
      let (vs, ve) = cursor.consume_while(fn(b) { ptokenchar(b) })
      if ve == vs {
        return Err(
          link_error_at(
            Parameter,
            InvalidParameter,
            value_start,
            cursor.context_string(),
          ),
        )
      }
      if ve - vs > limits.max_parameter_value_bytes() {
        return Err(
          link_error_at(
            Limit,
            LimitExceeded,
            vs,
            "parameter value exceeds max_parameter_value_bytes",
          ),
        )
      }
      Ok({ name, value_start, value: Token(cursor.take_string(vs, ve)) })
    }
  }
}

///|
/// Whether the given parameter name is an RFC 8187 `name*` form.
pub fn is_ext_value_name(name : String) -> Bool {
  name.length() > 1 && ends_with_star(name)
}

///|
fn ends_with_star(name : String) -> Bool {
  let bytes = @utf8.encode(name)
  if bytes.length() == 0 {
    return false
  }
  bytes[bytes.length() - 1] == 42
}
