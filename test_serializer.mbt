// test_serializer.mbt — Tests for the deterministic serializer (link_serializer.mbt)
// and canonicalization (canonicalize.mbt).

///|
test "serialize_link emits target then rel first" {
  let link = web_link("/page")
  link.relations.push(Registered("next"))
  assert_str_eq(serialize_link(link), "</page>; rel=\"next\"")
}

///|
test "serialize_link_header joins links with comma-space" {
  let links : Array[WebLink] = []
  let a = web_link("/a")
  a.relations.push(Registered("next"))
  let b = web_link("/b")
  b.relations.push(Registered("prev"))
  links.push(a)
  links.push(b)
  assert_str_eq(
    serialize_link_header(links),
    "</a>; rel=\"next\", </b>; rel=\"prev\"",
  )
}

///|
test "serialize_link_header of an empty array is empty" {
  assert_str_eq(serialize_link_header([]), "")
}

///|
test "serialize every target attribute in deterministic order" {
  let link : WebLink = {
    target: "https://example.com/doc",
    relations: [Registered("alternate")],
    anchor: Some("https://example.com/"),
    hreflang: ["en", "de"],
    media: Some("print"),
    title: Some("The Doc"),
    title_star: None,
    media_type: Some("text/html"),
    extensions: [{ name: "x-tag", value: Some("v1"), quoted: false }],
  }
  assert_str_eq(
    serialize_link(link),
    "<https://example.com/doc>; rel=\"alternate\"; anchor=\"https://example.com/\"; hreflang=\"en\"; hreflang=\"de\"; media=\"print\"; title=\"The Doc\"; type=\"text/html\"; x-tag=v1",
  )
}

///|
test "extension parameter value uses token form when possible" {
  let link : WebLink = {
    target: "a",
    relations: [Registered("next")],
    anchor: None,
    hreflang: [],
    media: None,
    title: None,
    title_star: None,
    media_type: None,
    extensions: [{ name: "x-note", value: Some("plain"), quoted: false }],
  }
  assert_str_eq(serialize_link(link), "<a>; rel=\"next\"; x-note=plain")
}

///|
test "extension parameter value is quoted when it cannot be a token" {
  let link : WebLink = {
    target: "a",
    relations: [Registered("next")],
    anchor: None,
    hreflang: [],
    media: None,
    title: None,
    title_star: None,
    media_type: None,
    extensions: [{ name: "x-note", value: Some("hello world"), quoted: false }],
  }
  assert_str_eq(
    serialize_link(link),
    "<a>; rel=\"next\"; x-note=\"hello world\"",
  )
}

///|
test "flag extension parameter serializes without a value" {
  let link : WebLink = {
    target: "a",
    relations: [Registered("next")],
    anchor: None,
    hreflang: [],
    media: None,
    title: None,
    title_star: None,
    media_type: None,
    extensions: [{ name: "x-flag", value: None, quoted: false }],
  }
  assert_str_eq(serialize_link(link), "<a>; rel=\"next\"; x-flag")
}

///|
test "title* serializes as an RFC 8187 extended value" {
  let link : WebLink = {
    target: "a",
    relations: [Registered("next")],
    anchor: None,
    hreflang: [],
    media: None,
    title: None,
    title_star: Some({ charset: "UTF-8", language: Some("en"), value: "hello" }),
    media_type: None,
    extensions: [],
  }
  assert_str_eq(
    serialize_link(link),
    "<a>; rel=\"next\"; title*=UTF-8'en'hello",
  )
}

///|
test "title* with percent-encoding of non-ASCII value" {
  let link : WebLink = {
    target: "a",
    relations: [Registered("next")],
    anchor: None,
    hreflang: [],
    media: None,
    title: None,
    title_star: Some({ charset: "UTF-8", language: None, value: "café" }),
    media_type: None,
    extensions: [],
  }
  assert_str_eq(
    serialize_link(link),
    "<a>; rel=\"next\"; title*=UTF-8''caf%C3%A9",
  )
}

///|
test "name* extension parameter serializes as an unquoted ext-value" {
  let link : WebLink = {
    target: "a",
    relations: [Registered("next")],
    anchor: None,
    hreflang: [],
    media: None,
    title: None,
    title_star: None,
    media_type: None,
    extensions: [
      { name: "x-enc*", value: Some("UTF-8'en'caf%C3%A9"), quoted: false },
    ],
  }
  assert_str_eq(
    serialize_link(link),
    "<a>; rel=\"next\"; x-enc*=UTF-8'en'caf%C3%A9",
  )
}

///|
test "serialize_quoted_string escapes quotes and backslashes" {
  assert_str_eq(serialize_quoted_string("plain"), "\"plain\"")
  assert_str_eq(serialize_quoted_string("a \"b\" \\c"), "\"a \\\"b\\\" \\\\c\"")
  assert_str_eq(serialize_quoted_string(""), "\"\"")
}

///|
test "can_be_token decides between token and quoted forms" {
  assert_true(can_be_token("abc"))
  assert_true(can_be_token("a-b_c.d"))
  assert_false(can_be_token("a/b")) // "/" is a separator, not a tchar
  assert_false(can_be_token("has space"))
  assert_false(can_be_token(""))
}

///|
test "canonicalize_link_header normalizes whitespace and quoting" {
  let canonical = unwrap_ok(
    canonicalize_link_header("<a>;rel=\"next\", <b>; rel = \"prev\""),
  )
  assert_str_eq(canonical, "<a>; rel=\"next\", <b>; rel=\"prev\"")
}

///|
test "canonicalize_link_header drops empty list elements" {
  let canonical = unwrap_ok(canonicalize_link_header(", <a>; rel=\"next\", ,"))
  assert_str_eq(canonical, "<a>; rel=\"next\"")
}

///|
test "canonicalize_link_header is idempotent" {
  let x = "<a>;rel=\"next\";title=\"T\" , <b> ; rel=prev"
  let once = unwrap_ok(canonicalize_link_header(x))
  let twice = unwrap_ok(canonicalize_link_header(once))
  assert_str_eq(once, twice)
}

///|
test "canonicalize_link_value canonicalizes a single link-value" {
  let canonical = unwrap_ok(canonicalize_link_value("<a>;rel=\"next\"  "))
  assert_str_eq(canonical, "<a>; rel=\"next\"")
}

///|
test "canonicalize_link_header returns parse errors unchanged" {
  expect_err_kind(canonicalize_link_header("not a link"), ExpectedAngleBracket)
}

///|
test "serialize then parse round-trips a full-featured link" {
  let link : WebLink = {
    target: "https://example.com/doc",
    relations: [Registered("alternate"), Extension("https://e.test/rel")],
    anchor: Some("https://example.com/"),
    hreflang: ["en", "de"],
    media: Some("print"),
    title: Some("The Doc"),
    title_star: Some({
      charset: "UTF-8",
      language: Some("en"),
      value: "héllo wörld",
    }),
    media_type: Some("text/html"),
    extensions: [
      { name: "x-tag", value: Some("v1"), quoted: false },
      { name: "x-note", value: Some("a value"), quoted: true },
    ],
  }
  let header = serialize_link(link)
  let links = unwrap_ok(parse_link_header(header, Limits::default()))
  assert_true(links.length() == 1)
  assert_links_eq(links, [link])
}
