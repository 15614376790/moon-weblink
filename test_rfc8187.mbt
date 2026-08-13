// test_rfc8187.mbt — Tests for RFC 8187 extended parameter values (rfc8187.mbt).

///|
test "parse a basic UTF-8 extended value" {
  let ev = unwrap_ok(parse_extended_value_string("UTF-8'en'hello"))
  assert_str_eq(ev.charset(), "UTF-8")
  match ev.language() {
    Some(l) => assert_str_eq(l, "en")
    None => fail("language missing")
  }
  assert_str_eq(ev.value(), "hello")
}

///|
test "parse an extended value without a language" {
  let ev = unwrap_ok(parse_extended_value_string("UTF-8''hello"))
  assert_true(ev.language() is None)
  assert_str_eq(ev.value(), "hello")
}

///|
test "percent-encoded bytes decode to the underlying UTF-8" {
  let ev = unwrap_ok(parse_extended_value_string("UTF-8''caf%C3%A9"))
  assert_str_eq(ev.value(), "café")
}

///|
test "percent-encoded multi-byte characters decode correctly" {
  let ev = unwrap_ok(parse_extended_value_string("UTF-8''%E2%82%AC"))
  assert_str_eq(ev.value(), "€")
}

///|
test "charset matching is case-insensitive" {
  let ev = unwrap_ok(parse_extended_value_string("utf-8'en'hello"))
  assert_str_eq(ev.charset(), "UTF-8")
}

///|
test "unsupported charset is rejected" {
  expect_err_kind(
    parse_extended_value_string("ISO-8859-1'en'hello"),
    UnsupportedCharset,
  )
}

///|
test "malformed percent-encoding is rejected" {
  expect_err_kind(
    parse_extended_value_string("UTF-8''%ZZ"),
    InvalidPercentEncoding,
  )
  expect_err_kind(
    parse_extended_value_string("UTF-8''%4"),
    InvalidPercentEncoding,
  )
  expect_err_kind(
    parse_extended_value_string("UTF-8''%"),
    InvalidPercentEncoding,
  )
}

///|
test "percent-decoded bytes that are not UTF-8 are rejected" {
  expect_err_kind(parse_extended_value_string("UTF-8''%FF"), InvalidUtf8)
}

///|
test "invalid language tag is rejected" {
  expect_err_kind(
    parse_extended_value_string("UTF-8'e'hello"),
    InvalidLanguageTag,
  )
  expect_err_kind(
    parse_extended_value_string("UTF-8'1en'hello"),
    InvalidLanguageTag,
  )
}

///|
test "missing apostrophe after charset is rejected" {
  expect_err_kind(
    parse_extended_value_string("UTF-8hello"),
    UnexpectedCharacter,
  )
}

///|
test "missing apostrophe after language is rejected" {
  expect_err_kind(
    parse_extended_value_string("UTF-8'enhello"),
    UnexpectedCharacter,
  )
}

///|
test "empty value is allowed" {
  let ev = unwrap_ok(parse_extended_value_string("UTF-8''"))
  assert_str_eq(ev.value(), "")
  assert_true(ev.language() is None)
}

///|
test "trailing bytes after the value are rejected" {
  expect_err_kind(
    parse_extended_value_string("UTF-8''hello extra"),
    TrailingInput,
  )
}

///|
test "serialize_extended_value emits uppercase percent-encoding" {
  let ev = { charset: "UTF-8", language: None, value: "café" }
  assert_str_eq(serialize_extended_value(ev), "UTF-8''caf%C3%A9")
}

///|
test "serialize_extended_value round-trips through the parser" {
  let ev = { charset: "UTF-8", language: Some("en"), value: "a b/c" }
  let s = serialize_extended_value(ev)
  assert_str_eq(s, "UTF-8'en'a%20b%2Fc")
  let parsed = unwrap_ok(parse_extended_value_string(s))
  assert_str_eq(parsed.value(), "a b/c")
  match parsed.language() {
    Some(l) => assert_str_eq(l, "en")
    None => fail("language missing")
  }
}

///|
test "attr-char bytes are emitted unencoded" {
  let ev = { charset: "UTF-8", language: None, value: "hello_world-1.2" }
  assert_str_eq(serialize_extended_value(ev), "UTF-8''hello_world-1.2")
}

///|
test "valid_language_tag accepts well-formed tags" {
  assert_true(valid_language_tag("en"))
  assert_true(valid_language_tag("en-US"))
  assert_true(valid_language_tag("sr-Latn-RS"))
  assert_true(valid_language_tag("zh-Hans-CN"))
  assert_true(valid_language_tag("x-private"))
  assert_true(valid_language_tag("es-419"))
}

///|
test "valid_language_tag rejects malformed tags" {
  assert_false(valid_language_tag(""))
  assert_false(valid_language_tag("e"))
  assert_false(valid_language_tag("123"))
  assert_false(valid_language_tag("en-US-"))
  assert_false(valid_language_tag("en_US"))
  assert_false(valid_language_tag("averylongsubtagthatexceedslength"))
  assert_false(valid_language_tag("en-123456789"))
}

///|
test "ext-value grammar integrates with the link parser" {
  // The value may not contain whitespace, ";" or "," unencoded.
  let links = unwrap_ok(
    parse_link_header(
      "<a>; rel=\"next\"; title*=UTF-8'en'hello%20world",
      Limits::default(),
    ),
  )
  match links[0].title_star() {
    Some(ev) => assert_str_eq(ev.value(), "hello world")
    None => fail("title* missing")
  }
}

///|
test "multiple title* occurrences are first-wins and recorded" {
  let parsed = unwrap_ok(
    parse_link_header_detailed(
      "<a>; rel=\"next\"; title*=UTF-8'en'a; title*=UTF-8'de'b",
      Limits::default(),
    ),
  )
  match parsed.links()[0].title_star() {
    Some(ev) => assert_str_eq(ev.value(), "a")
    None => fail("title* missing")
  }
  assert_str_eq(parsed.duplicates()[0], "title*")
}
