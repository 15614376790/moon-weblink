// test_linkset_text.mbt — Tests for the RFC 9264 `application/linkset`
// text format (linkset_text.mbt).

///|
/// A `Limits` identical to `default()` except `max_input_bytes`.
fn tiny_text_limits() -> Limits {
  {
    max_input_bytes: 8,
    max_links: 1024,
    max_params_per_link: 256,
    max_relations_per_link: 64,
    max_target_bytes: 8192,
    max_parameter_name_bytes: 256,
    max_parameter_value_bytes: 8192,
    max_quoted_string_bytes: 16384,
    max_linkset_links: 8192,
    max_json_bytes: 4 << 20,
  }
}

///|
test "parse_linkset_text parses link-values and rejects non-ASCII" {
  // A single link-value parses to a one-link set.
  let set = unwrap_ok(
    parse_linkset_text(
      "<https://e.example/page>; rel=\"next\"",
      Limits::default(),
    ),
  )
  assert_true(set.link_count() == 1)
  assert_str_eq(set.links()[0].target(), "https://e.example/page")
  assert_true(set.links()[0].has_relation("next"))

  // Multiple link-values separated by SP.
  let two = unwrap_ok(
    parse_linkset_text(
      "<a>; rel=\"next\", <b>; rel=\"prev\"",
      Limits::default(),
    ),
  )
  assert_true(two.link_count() == 2)
  assert_str_eq(two.links()[1].target(), "b")

  // RFC 9264 Section 4.1 forbids non-ASCII bytes.
  expect_err_kind(
    parse_linkset_text("<a>; title=\"café\"", Limits::default()),
    UnexpectedCharacter,
  )

  // The error is attributed to the LinksetText stage.
  let r = parse_linkset_text("<a>; title=\"café\"", Limits::default())
  match r {
    Ok(_) => fail("expected error for non-ASCII byte")
    Err(e) => assert_true(e.stage() == LinksetText)
  }

  // Empty input is an EmptyInput error, not a panic.
  expect_err_kind(parse_linkset_text("", Limits::default()), EmptyInput)
  expect_err_kind(parse_linkset_text("   ", Limits::default()), EmptyInput)
}

///|
test "newlines separate link-values and serialization is deterministic" {
  // RFC 9264 Section 4.1 permits CR and LF as whitespace around the
  // comma that separates link-values (the RFC 8288 Section 3 grammar is
  // otherwise unchanged).
  let input = "<a>; rel=\"next\",\n  <b>; rel=\"prev\",\n<https://e.example/x>; rel=\"canonical\""
  let set = unwrap_ok(parse_linkset_text(input, Limits::default()))
  assert_true(set.link_count() == 3)
  assert_str_eq(set.links()[0].target(), "a")
  assert_str_eq(set.links()[2].target(), "https://e.example/x")

  // The single-line form is identical to a Link header field value and the
  // multiline form carries one link-value per line.
  assert_str_eq(
    serialize_linkset_text(set),
    "<a>; rel=\"next\", <b>; rel=\"prev\", <https://e.example/x>; rel=\"canonical\"",
  )
  let multiline = serialize_linkset_text_multiline(set)
  assert_str_eq(
    multiline, "<a>; rel=\"next\",\n<b>; rel=\"prev\",\n<https://e.example/x>; rel=\"canonical\"",
  )

  // Both serialized forms parse back to the same model.
  let back = unwrap_ok(parse_linkset_text(multiline, Limits::default()))
  assert_links_eq(back.links(), set.links())

  // The single-line output is a valid Link header field value too.
  let as_header = unwrap_ok(
    parse_link_header(serialize_linkset_text(set), Limits::default()),
  )
  assert_true(as_header.length() == 3)

  // The input-size bound applies to the text parser.
  expect_err_kind(
    parse_linkset_text("<a>; rel=\"next\"", tiny_text_limits()),
    LimitExceeded,
  )
}
