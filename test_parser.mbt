// test_parser.mbt — Tests for the RFC 8288 `Link` header parser (link_parser.mbt).

///|
let dflt : Limits = Limits::default()

///|
test "parse a single basic link" {
  let links = unwrap_ok(
    parse_link_header("<https://example.com/>; rel=\"next\"", dflt),
  )
  assert_true(links.length() == 1)
  assert_str_eq(links[0].target(), "https://example.com/")
  assert_true(links[0].has_relation("next"))
  assert_true(links[0].anchor() is None)
  assert_true(links[0].extensions().is_empty())
}

///|
test "parse multiple links separated by comma" {
  let links = unwrap_ok(
    parse_link_header(
      "<a>; rel=\"next\", <b>; rel=\"prev\", <c>; rel=\"canonical\"", dflt,
    ),
  )
  assert_true(links.length() == 3)
  assert_str_eq(links[0].target(), "a")
  assert_str_eq(links[1].target(), "b")
  assert_str_eq(links[2].target(), "c")
  assert_true(links[0].has_relation("next"))
  assert_true(links[1].has_relation("prev"))
  assert_true(links[2].has_relation("canonical"))
}

///|
test "parse every serialization-defined parameter, names case-insensitive" {
  // Parameter names use the mixed case. RFC 8288's grammar inherits ABNF
  // string literals (RFC 5234), which match case-insensitively: REL, ANCHOR,
  // HREFLANG, MEDIA, TITLE and TYPE are all recognized, and the canonical
  // serialization lowercases them.
  let links = unwrap_ok(
    parse_link_header(
      "<https://example.com/doc>; REL=\"alternate\"; ANCHOR=\"https://example.com/\"; HREFLANG=\"en\"; MEDIA=\"print\"; TITLE=\"The Doc\"; TYPE=\"text/html\"",
      dflt,
    ),
  )
  assert_true(links.length() == 1)
  let link = links[0]
  assert_str_eq(link.target(), "https://example.com/doc")
  assert_true(link.has_relation("alternate"))
  match link.anchor() {
    Some(a) => assert_str_eq(a, "https://example.com/")
    None => fail("anchor missing")
  }
  assert_true(link.hreflang().length() == 1)
  assert_str_eq(link.hreflang()[0], "en")
  match link.media() {
    Some(m) => assert_str_eq(m, "print")
    None => fail("media missing")
  }
  match link.title() {
    Some(t) => assert_str_eq(t, "The Doc")
    None => fail("title missing")
  }
  match link.media_type() {
    Some(t) => assert_str_eq(t, "text/html")
    None => fail("type missing")
  }
  assert_str_eq(
    serialize_link_header(links),
    "<https://example.com/doc>; rel=\"alternate\"; anchor=\"https://example.com/\"; hreflang=\"en\"; media=\"print\"; title=\"The Doc\"; type=\"text/html\"",
  )
}

///|
test "parse title* as an RFC 8187 extended value" {
  let links = unwrap_ok(
    parse_link_header("<a>; rel=\"next\"; title*=UTF-8'en'%E2%82%AC", dflt),
  )
  assert_true(links.length() == 1)
  match links[0].title_star() {
    Some(ev) => {
      assert_str_eq(ev.charset(), "UTF-8")
      match ev.language() {
        Some(l) => assert_str_eq(l, "en")
        None => fail("language missing")
      }
      assert_str_eq(ev.value(), "€")
    }
    None => fail("title* missing")
  }
}

///|
test "rel value with multiple relation types" {
  let links = unwrap_ok(parse_link_header("<a>; rel=\"next prev last\"", dflt))
  assert_true(links.length() == 1)
  let names = links[0].relation_names()
  assert_true(names.length() == 3)
  assert_str_eq(names[0], "next")
  assert_str_eq(names[1], "prev")
  assert_str_eq(names[2], "last")
}

///|
test "rel is case-preserved but matched case-insensitively" {
  let links = unwrap_ok(parse_link_header("<a>; rel=\"NEXT\"", dflt))
  assert_str_eq(links[0].relation_names()[0], "NEXT")
  assert_true(links[0].has_relation("next"))
  assert_true(links[0].has_relation("NEXT"))
}

///|
test "unquoted rel token form is accepted" {
  let links = unwrap_ok(parse_link_header("<a>; rel=next", dflt))
  assert_true(links[0].has_relation("next"))
}

///|
test "extension relation type is an absolute URI" {
  let links = unwrap_ok(
    parse_link_header("<a>; rel=\"https://example.com/rel\"", dflt),
  )
  assert_true(links.length() == 1)
  assert_true(links[0].relations()[0].is_extension())
  assert_true(links[0].has_relation("https://example.com/rel"))
}

///|
test "hreflang is repeatable and preserved in order" {
  let links = unwrap_ok(
    parse_link_header(
      "<a>; rel=\"alternate\"; hreflang=\"en\"; hreflang=\"de\"", dflt,
    ),
  )
  assert_true(links[0].hreflang().length() == 2)
  assert_str_eq(links[0].hreflang()[0], "en")
  assert_str_eq(links[0].hreflang()[1], "de")
}

///|
test "extension parameters are preserved with name and value" {
  let links = unwrap_ok(
    parse_link_header(
      "<a>; rel=\"next\"; x-foo=bar; x-baz=\"quoted value\"", dflt,
    ),
  )
  assert_true(links[0].extensions().length() == 2)
  let ext = links[0].extensions()
  assert_str_eq(ext[0].name(), "x-foo")
  match ext[0].value() {
    Some(v) => assert_str_eq(v, "bar")
    None => fail("x-foo value missing")
  }
  assert_false(ext[0].quoted())
  assert_str_eq(ext[1].name(), "x-baz")
  match ext[1].value() {
    Some(v) => assert_str_eq(v, "quoted value")
    None => fail("x-baz value missing")
  }
  assert_true(ext[1].quoted())
}

///|
test "flag extension parameter (no value) is preserved" {
  let links = unwrap_ok(parse_link_header("<a>; rel=\"next\"; x-flag", dflt))
  assert_true(links[0].extensions().length() == 1)
  assert_str_eq(links[0].extensions()[0].name(), "x-flag")
  assert_true(links[0].extensions()[0].value() is None)
}

///|
test "deprecated rev is preserved as an extension parameter" {
  let links = unwrap_ok(
    parse_link_header("<a>; rel=\"next\"; rev=\"previous\"", dflt),
  )
  assert_true(links[0].extensions().length() == 1)
  assert_str_eq(links[0].extensions()[0].name(), "rev")
  match links[0].extensions()[0].value() {
    Some(v) => assert_str_eq(v, "previous")
    None => fail("rev value missing")
  }
}

///|
test "single-occurrence parameters are first-wins and recorded as duplicates" {
  let parsed = unwrap_ok(
    parse_link_header_detailed(
      "<a>; rel=\"next\"; title=\"first\"; title=\"second\"", dflt,
    ),
  )
  match parsed.links()[0].title() {
    Some(t) => assert_str_eq(t, "first")
    None => fail("title missing")
  }
  assert_true(parsed.duplicates().length() == 1)
  assert_str_eq(parsed.duplicates()[0], "title")
}

///|
test "duplicate rel is first-wins and recorded" {
  let parsed = unwrap_ok(
    parse_link_header_detailed("<a>; rel=\"next\"; rel=\"prev\"", dflt),
  )
  assert_true(parsed.links()[0].has_relation("next"))
  assert_false(parsed.links()[0].has_relation("prev"))
  assert_str_eq(parsed.duplicates()[0], "rel")
}

///|
test "duplicate names are recorded only once" {
  let parsed = unwrap_ok(
    parse_link_header_detailed(
      "<a>; rel=\"next\"; title=\"1\"; title=\"2\"; title=\"3\"", dflt,
    ),
  )
  assert_true(parsed.duplicates().length() == 1)
}

///|
test "empty list elements are allowed and ignored" {
  let links = unwrap_ok(parse_link_header(", <a>; rel=\"next\", ,", dflt))
  assert_true(links.length() == 1)
  assert_str_eq(links[0].target(), "a")
}

///|
test "leading and trailing whitespace is tolerated" {
  let links = unwrap_ok(parse_link_header("  <a>; rel=\"next\"  ", dflt))
  assert_true(links.length() == 1)
}

///|
test "whitespace around the semicolon and equals is tolerated" {
  let links = unwrap_ok(
    parse_link_header("<a> ; rel = \"next\" ; title = \"T\"", dflt),
  )
  assert_true(links.length() == 1)
  assert_true(links[0].has_relation("next"))
}

///|
test "empty input raises EmptyInput" {
  expect_err_kind(parse_link_header("", dflt), EmptyInput)
  expect_err_kind(parse_link_header("   ", dflt), EmptyInput)
  expect_err_kind(parse_link_header(", ,", dflt), EmptyInput)
}

///|
test "missing rel parameter raises an error" {
  assert_true(err_stage(parse_link_header("<a>", dflt)) == LinkValue)
  assert_true(err_kind(parse_link_header("<a>", dflt)) == InvalidRelation)
}

///|
test "unterminated target raises UnterminatedTarget" {
  expect_err_kind(
    parse_link_header("<https://example.com", dflt),
    UnterminatedTarget,
  )
}

///|
test "expected angle bracket raises ExpectedAngleBracket" {
  expect_err_kind(
    parse_link_header("https://example.com>; rel=\"next\"", dflt),
    ExpectedAngleBracket,
  )
}

///|
test "space inside the target is rejected" {
  // The space is the 13th byte of the input (0-based offset 12).
  assert_true(
    err_offset(parse_link_header("<https://exa mple.com/>; rel=\"next\"", dflt)) ==
    12,
  )
}

///|
test "trailing garbage after a link raises TrailingInput" {
  expect_err_kind(
    parse_link_header("<a>; rel=\"next\" xyz", dflt),
    TrailingInput,
  )
}

///|
test "empty rel value raises InvalidRelation" {
  expect_err_kind(parse_link_header("<a>; rel=\"\"", dflt), InvalidRelation)
}

///|
test "rel containing invalid token characters is rejected" {
  expect_err_kind(
    parse_link_header("<a>; rel=\"bad[rel\"", dflt),
    InvalidRelation,
  )
}

///|
test "hreflang with invalid language tag is rejected" {
  expect_err_kind(
    parse_link_header("<a>; rel=\"next\"; hreflang=\"e\"", dflt),
    InvalidLanguageTag,
  )
}

///|
test "anchor with invalid URI-reference is rejected" {
  expect_err_kind(
    parse_link_header("<a>; rel=\"next\"; anchor=\"has space\"", dflt),
    InvalidContextValue,
  )
}

///|
test "invalid media type in type parameter is rejected" {
  expect_err_kind(
    parse_link_header("<a>; rel=\"next\"; type=\"not a type\"", dflt),
    InvalidMediaType,
  )
}

///|
test "title* with non-extended value is rejected" {
  // A `name*` parameter is always parsed as an RFC 8187 ext-value, so a
  // quoted-string value there is a malformed ext-value.
  expect_err_kind(
    parse_link_header("<a>; rel=\"next\"; title*=\"plain\"", dflt),
    UnexpectedCharacter,
  )
  assert_true(
    err_stage(parse_link_header("<a>; rel=\"next\"; title*=\"plain\"", dflt)) ==
    ExtendedValue,
  )
}

///|
test "target may be an IRI (non-ASCII bytes)" {
  let links = unwrap_ok(
    parse_link_header("<https://example.com/αβγ>; rel=\"next\"", dflt),
  )
  assert_str_eq(links[0].target(), "https://example.com/αβγ")
}

///|
test "error context is bounded to max_context_bytes" {
  let long = "<" + rng_long_target()
  assert_true(
    err_context(parse_link_header(long, dflt)).length() <= max_context_bytes(),
  )
}

///|
test "error display is a single line with stage, kind, offset" {
  expect_err_kind(parse_link_header("", dflt), EmptyInput)
  let d = err_display(parse_link_header("", dflt))
  assert_true(d.contains("Input"))
  assert_true(d.contains("EmptyInput"))
  assert_true(d.contains("byte 0"))
}

///|
test "quoted-string contents can contain commas and semicolons" {
  let links = unwrap_ok(
    parse_link_header("<a>; rel=\"next\"; title=\"a, b; c\"", dflt),
  )
  match links[0].title() {
    Some(t) => assert_str_eq(t, "a, b; c")
    None => fail("title missing")
  }
}

///|
test "quoted-pair escapes resolve inside quoted strings" {
  let links = unwrap_ok(
    parse_link_header(
      "<a>; rel=\"next\"; title=\"say \\\"hi\\\" and \\\\\"", dflt,
    ),
  )
  match links[0].title() {
    Some(t) => assert_str_eq(t, "say \"hi\" and \\")
    None => fail("title missing")
  }
}

///|
test "type parameter may carry media-type parameters" {
  let links = unwrap_ok(
    parse_link_header(
      "<a>; rel=\"next\"; type=\"text/html; charset=utf-8\"", dflt,
    ),
  )
  match links[0].media_type() {
    Some(t) => assert_str_eq(t, "text/html; charset=utf-8")
    None => fail("type missing")
  }
}

///|
test "parse result of RFC 8288 example header" {
  // The example from RFC 8288 Section 3.1.
  let links = unwrap_ok(
    parse_link_header(
      "</>; rel=\"http://example.net/foo\"; anchor=\"http://example.net/\"", dflt,
    ),
  )
  assert_true(links.length() == 1)
  assert_str_eq(links[0].target(), "/")
  assert_true(links[0].has_relation("http://example.net/foo"))
  match links[0].anchor() {
    Some(a) => assert_str_eq(a, "http://example.net/")
    None => fail("anchor missing")
  }
}

///|
/// A target string long enough to trigger context truncation.
fn rng_long_target() -> String {
  let sb = StringBuilder()
  for i = 0; i < 500; i = i + 1 {
    sb.write_char('x')
  }
  sb.write_char('>')
  sb.to_string()
}
