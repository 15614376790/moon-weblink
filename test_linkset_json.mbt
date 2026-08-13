// test_linkset_json.mbt — Tests for the RFC 9264 `application/linkset+json`
// format (linkset_json.mbt).

///|
/// A one-relation link carrying an explicit anchor context.
fn anchor_link(target : String, rel : String, anchor : String) -> WebLink {
  {
    target,
    relations: [Registered(rel)],
    anchor: Some(anchor),
    hreflang: [],
    media: None,
    title: None,
    title_star: None,
    media_type: None,
    extensions: [],
  }
}

///|
test "serialize_linkset_json emits the canonical document shape" {
  // One minimal link: a single context object with one relation member.
  let link = web_link("/page")
  link.relations.push(Registered("next"))
  let set = LinkSet::from_links([link])
  assert_str_eq(
    serialize_linkset_json(set),
    "{\n  \"linkset\": [\n    {\n      \"next\": [\n        {\n          \"href\": \"/page\"\n        }\n      ]\n    }\n  ]\n}",
  )

  // A link with an anchor and target attributes groups under the anchor
  // context and carries the attributes on the target object.
  let rich : WebLink = {
    target: "https://example.com/next",
    relations: [Registered("next")],
    anchor: Some("https://example.com/"),
    hreflang: ["en"],
    media: Some("print"),
    title: Some("Go next"),
    title_star: None,
    media_type: Some("text/html"),
    extensions: [{ name: "x-note", value: Some("v1"), quoted: false }],
  }
  let rich_json = serialize_linkset_json(LinkSet::from_links([rich]))
  assert_true(rich_json.contains("\"anchor\": \"https://example.com/\""))
  assert_true(rich_json.contains("\"href\": \"https://example.com/next\""))
  assert_true(rich_json.contains("\"hreflang\": [\"en\"]"))
  assert_true(rich_json.contains("\"media\": \"print\""))
  assert_true(rich_json.contains("\"title\": \"Go next\""))
  assert_true(rich_json.contains("\"type\": \"text/html\""))
  assert_true(rich_json.contains("\"x-note\": [\"v1\"]"))

  // Two links sharing the anchor appear under a single context object.
  let a = anchor_link("https://example.com/a", "next", "https://example.com/")
  let b = anchor_link("https://example.com/b", "prev", "https://example.com/")
  let two_json = serialize_linkset_json(LinkSet::from_links([a, b]))
  assert_true(two_json.contains("\"anchor\": \"https://example.com/\""))
  assert_true(two_json.contains("\"next\": ["))
  assert_true(two_json.contains("\"prev\": ["))
}

///|
test "parse_linkset_json builds the model and round-trips" {
  // A minimal document parses to one link with one relation.
  let set = unwrap_ok(
    parse_linkset_json(
      "{\"linkset\": [{\"next\": [{\"href\": \"/page\"}]}]}",
      Limits::default(),
    ),
  )
  assert_true(set.link_count() == 1)
  assert_str_eq(set.links()[0].target(), "/page")
  assert_true(set.links()[0].has_relation("next"))
  assert_str_eq(serialize_link_header(set.links()), "</page>; rel=\"next\"")

  // The canonical serialization of the parsed model is a fixed point.
  let canonical = serialize_linkset_json(set)
  let reparsed = unwrap_ok(parse_linkset_json(canonical, Limits::default()))
  assert_str_eq(serialize_linkset_json(reparsed), canonical)

  // A multi-relation link is emitted under each relation member and
  // normalizes back to one link per relation type.
  let multi = web_link("/p")
  multi.relations.push(Registered("next"))
  multi.relations.push(Registered("prev"))
  let multi_json = serialize_linkset_json(LinkSet::from_links([multi]))
  assert_true(multi_json.contains("\"next\": ["))
  assert_true(multi_json.contains("\"prev\": ["))
  let back = unwrap_ok(parse_linkset_json(multi_json, Limits::default()))
  assert_true(back.link_count() == 2)
  assert_true(back.links()[0].has_relation("next"))
  assert_true(back.links()[1].has_relation("prev"))

  // title*, hreflang and extension attributes survive a round trip.
  let parsed = unwrap_ok(
    parse_linkset_json(
      "{\"linkset\":[{\"https://rel.example/x\":[{\"href\":\"/d\",\"title*\":[{\"value\":\"café\",\"language\":\"fr\"}],\"hreflang\":[\"fr\",\"de\"],\"x-tag\":[\"v1\"]}]}]}",
      Limits::default(),
    ),
  )
  let l = parsed.links()[0]
  assert_true(l.has_relation("https://rel.example/x"))
  assert_true(l.hreflang().length() == 2)
  match l.title_star() {
    Some(ev) => {
      assert_str_eq(ev.value(), "café")
      match ev.language() {
        Some(lang) => assert_str_eq(lang, "fr")
        None => fail("language missing")
      }
    }
    None => fail("title* missing")
  }
  assert_true(l.extensions().length() == 1)
  assert_str_eq(l.extensions()[0].name(), "x-tag")
}

///|
test "structural and JSON errors are reported as LinkError" {
  // Invalid JSON syntax.
  let r1 = parse_linkset_json("{\"linkset\": [", Limits::default())
  match r1 {
    Ok(_) => fail("expected invalid JSON error")
    Err(e) => assert_true(e.kind() == InvalidJson)
  }

  // Top-level value is not an object.
  expect_err_kind(
    parse_linkset_json("[1, 2]", Limits::default()),
    InvalidJsonShape,
  )

  // Missing "linkset" member.
  expect_err_kind(
    parse_linkset_json("{\"foo\": []}", Limits::default()),
    InvalidJsonShape,
  )

  // "linkset" is not the sole member.
  expect_err_kind(
    parse_linkset_json("{\"linkset\": [], \"extra\": 1}", Limits::default()),
    InvalidJsonShape,
  )

  // "linkset" value is not an array.
  expect_err_kind(
    parse_linkset_json("{\"linkset\": {}}", Limits::default()),
    InvalidJsonShape,
  )

  // A link target object is missing "href".
  expect_err_kind(
    parse_linkset_json("{\"linkset\": [{\"next\": [{}]}]}", Limits::default()),
    InvalidJsonShape,
  )

  // "href" is not a string.
  expect_err_kind(
    parse_linkset_json(
      "{\"linkset\": [{\"next\": [{\"href\": 5}]}]}",
      Limits::default(),
    ),
    InvalidJsonShape,
  )

  // A relation member is not an array.
  expect_err_kind(
    parse_linkset_json(
      "{\"linkset\": [{\"next\": {\"href\": \"/x\"}}]}",
      Limits::default(),
    ),
    InvalidJsonShape,
  )

  // "anchor" is not a string.
  expect_err_kind(
    parse_linkset_json(
      "{\"linkset\": [{\"anchor\": 5, \"next\": [{\"href\": \"/x\"}]}]}",
      Limits::default(),
    ),
    InvalidJsonShape,
  )

  // A small document parses fine under the default byte bound.
  let r10 = parse_linkset_json(
    "{\"linkset\": [{\"next\": [{\"href\": \"/x\"}]}]}",
    Limits::default(),
  )
  match r10 {
    Ok(_) => ()
    Err(_) => fail("expected a small JSON document to parse within limits")
  }
}
