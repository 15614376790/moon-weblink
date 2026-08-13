// test_relation.mbt — Tests for relation-type parsing (relation.mbt).

///|
test "parse a registered relation type as a token" {
  let rt = unwrap_ok(parse_relation_type("next"))
  assert_true(rt.is_registered())
  assert_false(rt.is_extension())
  match rt {
    Registered(n) => assert_str_eq(n, "next")
    Extension(_) => fail("should be registered")
  }
}

///|
test "parse an extension relation type as an absolute URI" {
  let rt = unwrap_ok(parse_relation_type("https://example.com/rel"))
  assert_true(rt.is_extension())
  match rt {
    Extension(u) => assert_str_eq(u, "https://example.com/rel")
    Registered(_) => fail("should be extension")
  }
}

///|
test "empty relation type is rejected" {
  expect_err_kind(parse_relation_type(""), InvalidRelation)
}

///|
test "relation type with invalid token characters is rejected" {
  expect_err_kind(parse_relation_type("bad[rel"), InvalidRelation)
  expect_err_kind(parse_relation_type("has space"), InvalidRelation)
  expect_err_kind(parse_relation_type("a/b"), InvalidRelation)
}

///|
test "relation type with a space is not split by parse_relation_type" {
  expect_err_kind(parse_relation_type("next prev"), InvalidRelation)
}

///|
test "relation type case is preserved" {
  match unwrap_ok(parse_relation_type("Next")) {
    Registered(n) => assert_str_eq(n, "Next")
    Extension(_) => fail("should be registered")
  }
}

///|
test "relation_type_is_registered and is_extension helpers" {
  assert_true(relation_type_is_registered(Registered("next")))
  assert_false(relation_type_is_extension(Registered("next")))
  assert_true(relation_type_is_extension(Extension("https://e.test/x")))
  assert_false(relation_type_is_registered(Extension("https://e.test/x")))
}

///|
test "parse_relation_list splits on runs of spaces" {
  let rels = unwrap_ok(
    parse_relation_list("next  prev   last", Limits::default()),
  )
  assert_true(rels.length() == 3)
  assert_str_eq(rels[0].name().unwrap(), "next")
  assert_str_eq(rels[1].name().unwrap(), "prev")
  assert_str_eq(rels[2].name().unwrap(), "last")
}

///|
test "parse_relation_list mixes registered and extension forms" {
  let rels = unwrap_ok(
    parse_relation_list("next https://example.com/rel", Limits::default()),
  )
  assert_true(rels.length() == 2)
  assert_true(rels[0].is_registered())
  assert_true(rels[1].is_extension())
}

///|
test "parse_relation_list of empty string is an error" {
  expect_err_kind(parse_relation_list("", Limits::default()), InvalidRelation)
}

///|
test "parse_relation_list enforces max_relations_per_link" {
  expect_err_kind(
    parse_relation_list("next prev last alternate", relation_limits(2)),
    LimitExceeded,
  )
}

///|
/// A `Limits` identical to `default()` except `max_relations_per_link`.
fn relation_limits(n : Int) -> Limits {
  {
    max_input_bytes: 1 << 20,
    max_links: 1024,
    max_params_per_link: 256,
    max_relations_per_link: n,
    max_target_bytes: 8192,
    max_parameter_name_bytes: 256,
    max_parameter_value_bytes: 8192,
    max_quoted_string_bytes: 16384,
    max_linkset_links: 8192,
    max_json_bytes: 4 << 20,
  }
}

///|
test "split_on_spaces collapses runs of spaces" {
  let parts = split_on_spaces("  a   b  ")
  assert_true(parts.length() == 2)
  assert_str_eq(parts[0], "a")
  assert_str_eq(parts[1], "b")
}

///|
test "split_on_spaces of empty input is empty" {
  assert_true(split_on_spaces("").is_empty())
  assert_true(split_on_spaces("   ").is_empty())
}
