// test_property.mbt — Deterministic property tests.
//
// Every generator is the fixed-seed PRNG from test_helpers.mbt: no clock, no
// `random()`. The same seeds always produce the same corpus on every platform
// and every run. Each iteration checks a round-trip or normalization
// invariant against a freshly generated input; the whole file exercises more
// than 1200 deterministic cases.

///|
test "property: header round-trip for 400 random links" {
  let rng = rng_new(11)
  let dflt = Limits::default()
  for _i = 0; _i < 400; _i = _i + 1 {
    let link = rng.web_link()
    let header = serialize_link(link)
    let reparsed = unwrap_ok(parse_link_header(header, dflt))
    assert_true(reparsed.length() == 1)
    // Serialization is canonical: parse then re-serialize reproduces the
    // exact same header text.
    assert_str_eq(serialize_link(reparsed[0]), header)
  }
}

///|
test "property: linkset text and JSON round-trips for 300 random sets" {
  let rng = rng_new(22)
  let dflt = Limits::default()
  for _i = 0; _i < 300; _i = _i + 1 {
    let links = Array::new()
    let n = rng.range(1, 5)
    for _j = 0; _j < n; _j = _j + 1 {
      links.push(rng.web_link())
    }
    let set = LinkSet::from_links(links)

    // Text round-trip: parse(serialize(set)) re-serializes identically, and
    // the text form doubles as a valid Link header field value.
    let text = serialize_linkset_text(set)
    let text_parsed = unwrap_ok(parse_linkset_text(text, dflt))
    assert_str_eq(serialize_linkset_text(text_parsed), text)
    let as_header = unwrap_ok(parse_link_header(text, dflt))
    assert_str_eq(serialize_link_header(as_header), text)

    // JSON normalization is a fixed point: one parse/serialize cycle is
    // stable, because the JSON format normalizes a multi-relation link to one
    // link per relation type on first serialization.
    let j1 = serialize_linkset_json(set)
    let json_parsed = unwrap_ok(parse_linkset_json(j1, dflt))
    assert_str_eq(serialize_linkset_json(json_parsed), j1)
  }
}

///|
test "property: URI, language-tag and relation-type invariants for 300 random cases" {
  let rng = rng_new(33)
  for _i = 0; _i < 300; _i = _i + 1 {
    // A generated URI-reference recomposes byte-for-byte.
    let uri = rng.uri()
    let parsed = unwrap_ok(parse_uri_reference(uri))
    assert_str_eq(parsed.to_string(), uri)

    // Resolution is idempotent, for both absolute and relative references.
    let once = unwrap_ok(
      resolve_uri_reference_string("http://a.example/b/c/d;p?q", uri),
    )
    let twice = unwrap_ok(
      resolve_uri_reference_string("http://a.example/b/c/d;p?q", once),
    )
    assert_str_eq(twice, once)

    // A generated language tag is valid.
    assert_true(valid_language_tag(rng.lang_tag()))

    // A generated extension relation URI parses as an extension type.
    let ext = "https://rel.example/" + rng.segment(1, 8)
    let rt = unwrap_ok(parse_relation_type(ext))
    assert_true(rt.is_extension())
  }

  // remove_dot_segments is idempotent on generated paths.
  let rng2 = rng_new(55)
  for _i = 0; _i < 200; _i = _i + 1 {
    let p = "/\{rng2.segment(1, 6)}/\{rng2.segment(1, 6)}/./../\{rng2.segment(1, 6)}"
    let once = remove_dot_segments(p)
    assert_str_eq(remove_dot_segments(once), once)
  }
}
