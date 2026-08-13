// test_conversion.mbt — Tests for the cross-representation conversions
// (conversion.mbt).

///|
test "header, text and JSON all convert to and from the shared model" {
  let dflt = Limits::default()

  // Header -> model -> header is identity.
  let header = "<https://e.example/a>; rel=\"next\", <https://e.example/b>; rel=\"prev\""
  let set = unwrap_ok(link_header_to_linkset(header, dflt))
  assert_true(set.link_count() == 2)
  assert_str_eq(linkset_to_link_header(set), header)

  // Text document -> canonical header.
  assert_str_eq(
    unwrap_ok(
      linkset_text_to_link_header("<a>; rel=\"next\",\n<b>; rel=\"prev\"", dflt),
    ),
    "<a>; rel=\"next\", <b>; rel=\"prev\"",
  )

  // JSON document -> canonical header.
  assert_str_eq(
    unwrap_ok(
      linkset_json_to_link_header(
        "{\"linkset\": [{\"next\": [{\"href\": \"/a\"}]}]}", dflt,
      ),
    ),
    "</a>; rel=\"next\"",
  )

  // canonical_link_header is the same pipeline.
  assert_str_eq(
    unwrap_ok(canonical_link_header("<a>;rel=\"next\" , <b> ; rel=prev")),
    "<a>; rel=\"next\", <b>; rel=\"prev\"",
  )
}

///|
test "header and linkset convert to JSON and back; errors propagate" {
  let dflt = Limits::default()

  // Header -> JSON: the JSON document parses back to the same model for
  // single-relation links.
  let header = "<https://e.example/a>; rel=\"next\""
  let json = unwrap_ok(link_header_to_linkset_json(header, dflt))
  assert_true(json.contains("\"linkset\""))
  let from_json = unwrap_ok(linkset_json_to_link_header(json, dflt))
  assert_str_eq(from_json, header)

  // Text -> JSON and back to text.
  let text = "<a>; rel=\"next\", <b>; rel=\"prev\""
  let json2 = unwrap_ok(linkset_text_to_linkset_json(text, dflt))
  let text2 = unwrap_ok(linkset_json_to_linkset_text(json2, dflt))
  assert_str_eq(text2, text)

  // Every converter reports parse errors unchanged, with the same kind.
  expect_err_kind(
    link_header_to_linkset("not a link", dflt),
    ExpectedAngleBracket,
  )
  expect_err_kind(
    linkset_text_to_link_header("café", dflt),
    UnexpectedCharacter,
  )
  match linkset_json_to_link_header("{\"linkset\": [", dflt) {
    Ok(_) => fail("expected InvalidJson")
    Err(e) => assert_true(e.kind() == InvalidJson)
  }
  match link_header_to_linkset_json("{", dflt) {
    Ok(_) => fail("expected ExpectedAngleBracket")
    Err(e) => assert_true(e.kind() == ExpectedAngleBracket)
  }
}
