// test_invalid.mbt — Malformed input handling. Nothing ever panics, and
// every malformed input surfaces as a structured `LinkError` (never a raw
// exception, never a silent accept).

///|
/// Whether a result is an `Err`.
fn[T] is_err(r : Result[T, LinkError]) -> Bool {
  match r {
    Ok(_) => false
    Err(_) => true
  }
}

///|
/// Evaluates a result, discarding it (used to force parser execution).
fn[T] swallow(r : Result[T, LinkError]) -> Unit {
  match r {
    Ok(_) => ()
    Err(_) => ()
  }
}

///|
test "garbage and truncated inputs never panic" {
  let dflt = Limits::default()
  let garbage : Array[String] = [
    "", "   ", "\"", ">", "<>", "<>;", "<a>;", "<a>; rel", "<a>; rel=", "<a>; rel=\"",
    "<a>; rel=\"next", "<a>; rel=\"next\";", "<a>; rel=\"next\"; title=\"", "rel=\"next\"",
    "<a>; rel=\"next\" x", "a", "ab", "1a:b", "<a>; x=\"\\", "<a>; x='v'", "<a>; =v",
    "<a b>", "<http://", "<http://exa mple>", "<http://ex%GG>", "http://", "[]",
    "{}", "true", "null", "NaN", "{\"linkset\":", "{\"linkset\": [}", "{\"linkset\": 5}",
    "not json", "<a>; title*=UTF-8'", "<a>; title*=UTF-8''%", "<a>; hreflang=\"1e\"",
    "<a>; type=\"", "\u{1}\u{2}", "\u{7f}", "café", "\u{ff}",
  ]
  assert_true(garbage.length() >= 40)

  // Every parser runs on every garbage input and never panics.
  let mut link_rejected = 0
  for g in garbage {
    if is_err(parse_link_header(g, dflt)) {
      link_rejected = link_rejected + 1
    }
    swallow(parse_linkset_text(g, dflt))
    swallow(parse_linkset_json(g, dflt))
    swallow(parse_uri_reference(g))
    swallow(parse_relation_type(g))
    swallow(parse_extended_value_string(g))
    swallow(canonicalize_link_header(g))
  }
  // Almost all of these are rejected by the link-header parser. (A couple of
  // entries such as IRI targets are accepted by design.)
  assert_true(link_rejected >= garbage.length() - 4)
}

///|
test "malformed constructs map to the documented error kinds" {
  let dflt = Limits::default()
  // Missing angle bracket.
  expect_err_kind(parse_link_header("a", dflt), ExpectedAngleBracket)
  // Unterminated target.
  expect_err_kind(parse_link_header("<http://x", dflt), UnterminatedTarget)
  // Space in the target is rejected at the offending byte.
  expect_err_kind(parse_link_header("<a b>", dflt), InvalidTarget)
  // Control characters in the target are rejected.
  expect_err_kind(parse_link_header("<a\u{1}>", dflt), InvalidTarget)
  // A parameter with no name.
  expect_err_kind(parse_link_header("<a>; =v", dflt), MissingParameterName)
  // An unterminated quoted-string value.
  expect_err_kind(
    parse_link_header("<a>; x=\"oops", dflt),
    UnterminatedQuotedString,
  )
  // A relation value that is not a valid relation type.
  expect_err_kind(parse_link_header("<a>; rel=\"a/b\"", dflt), InvalidRelation)
  // Trailing bytes after the last link-value.
  expect_err_kind(parse_link_header("<a>; rel=\"next\" x", dflt), TrailingInput)
  // Malformed extended values.
  expect_err_kind(
    parse_link_header("<a>; title*=UTF-8'", dflt),
    UnexpectedCharacter,
  )
  expect_err_kind(
    parse_link_header("<a>; title*=UTF-8''%ZZ", dflt),
    InvalidPercentEncoding,
  )
  // URI parser rejects non-ASCII and malformed percent-encoding.
  expect_err_kind(parse_uri_reference("café"), InvalidToken)
  expect_err_kind(parse_uri_reference("<a>"), InvalidToken)
  expect_err_kind(parse_uri_reference("%GG"), InvalidPercentEncoding)

  // Non-ASCII bytes are legal in a link target (IRI, RFC 8288 Section 3.1)
  // but forbidden in the application/linkset text format.
  let iri = unwrap_ok(parse_link_header("<café>; rel=\"next\"", dflt))
  assert_str_eq(iri[0].target(), "café")
  expect_err_kind(parse_linkset_text("<café>", dflt), UnexpectedCharacter)
}
