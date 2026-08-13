// test_limits.mbt — Tests for the resource limit presets and their
// enforcement (limits.mbt).

///|
/// Repeats `s` `n` times.
fn repeat_str(s : String, n : Int) -> String {
  let sb = StringBuilder()
  for _i = 0; _i < n; _i = _i + 1 {
    sb.write_string(s)
  }
  sb.to_string()
}

///|
/// A `Limits` with a tiny input bound, everything else default.
fn tiny_input() -> Limits {
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
/// A `Limits` with a tiny JSON byte bound and a generous input bound, so the
/// `max_json_bytes` check (not the `max_input_bytes` check) is what fires.
fn tiny_json_limits() -> Limits {
  {
    max_input_bytes: 1 << 20,
    max_links: 1024,
    max_params_per_link: 256,
    max_relations_per_link: 64,
    max_target_bytes: 8192,
    max_parameter_name_bytes: 256,
    max_parameter_value_bytes: 8192,
    max_quoted_string_bytes: 16384,
    max_linkset_links: 8192,
    max_json_bytes: 64,
  }
}

///|
test "the three presets expose their documented bounds and every parser bound is enforced" {
  // Preset values.
  let d = Limits::default()
  let s = Limits::strict()
  let p = Limits::permissive()
  assert_true(d.max_input_bytes() == 1 << 20)
  assert_true(d.max_links() == 1024)
  assert_true(d.max_relations_per_link() == 64)
  assert_true(s.max_links() == 64)
  assert_true(s.max_params_per_link() == 32)
  assert_true(s.max_target_bytes() == 512)
  assert_true(s.max_quoted_string_bytes() == 2048)
  assert_true(p.max_links() == 100000)
  assert_true(p.max_json_bytes() == 256 << 20)

  // max_input_bytes (Input stage).
  expect_err_kind(
    parse_link_header("<a>; rel=\"next\"", tiny_input()),
    LimitExceeded,
  )
  match parse_link_header("<a>; rel=\"next\"", tiny_input()) {
    Ok(_) => fail("expected limit error")
    Err(e) => assert_true(e.stage() == Input)
  }

  // max_links (strict: 64).
  let many = repeat_str("<a>; rel=\"next\",", 70)
  expect_err_kind(parse_link_header(many, s), LimitExceeded)

  // max_target_bytes (strict: 512).
  let long_target = repeat_str("a", 600)
  expect_err_kind(
    parse_link_header("<\{long_target}>; rel=\"next\"", s),
    LimitExceeded,
  )

  // max_params_per_link (strict: 32).
  let extra_params = repeat_str("; x-i=v", 40)
  expect_err_kind(
    parse_link_header("<a>; rel=\"next\"\{extra_params}", s),
    LimitExceeded,
  )

  // max_relations_per_link (strict: 16).
  let many_rels = repeat_str("next ", 20)
  expect_err_kind(
    parse_link_header("<a>; rel=\"\{many_rels}\"", s),
    LimitExceeded,
  )

  // max_parameter_name_bytes (strict: 64).
  let long_name = repeat_str("a", 70)
  expect_err_kind(
    parse_link_header("<a>; rel=\"next\"; x-\{long_name}=v", s),
    LimitExceeded,
  )

  // max_parameter_value_bytes (strict: 1024).
  let long_value = repeat_str("v", 2000)
  expect_err_kind(
    parse_link_header("<a>; rel=\"next\"; x=\{long_value}", s),
    LimitExceeded,
  )

  // max_quoted_string_bytes (strict: 2048).
  let long_title = repeat_str("x", 3000)
  expect_err_kind(
    parse_link_header("<a>; rel=\"next\"; title=\"\{long_title}\"", s),
    LimitExceeded,
  )

  // max_json_bytes on the JSON parser.
  let long_href = repeat_str("a", 200)
  let big_json = "{\"linkset\":[{\"next\":[{\"href\":\"/\{long_href}\"}]}]}"
  expect_err_kind(
    parse_linkset_json(big_json, tiny_json_limits()),
    LimitExceeded,
  )

  // Enforced limits are reported with the Limit stage.
  match parse_link_header(many, s) {
    Ok(_) => fail("expected limit error")
    Err(e) => assert_true(e.stage() == Limit)
  }

  // At or under the bound parses cleanly.
  let ok = unwrap_ok(
    parse_link_header("<a>; rel=\"next\", <b>; rel=\"prev\"", s),
  )
  assert_true(ok.length() == 2)
}
