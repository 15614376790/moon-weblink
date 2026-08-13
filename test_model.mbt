// test_model.mbt — Tests for the core data model (model.mbt).

///|
test "web_link builds an empty link" {
  let l = web_link("/page")
  assert_str_eq(l.target(), "/page")
  assert_true(l.relations().is_empty())
  assert_true(l.anchor() is None)
  assert_true(l.hreflang().is_empty())
  assert_true(l.media() is None)
  assert_true(l.title() is None)
  assert_true(l.title_star() is None)
  assert_true(l.media_type() is None)
  assert_true(l.extensions().is_empty())
}

///|
test "LinkSet::from_links preserves order and count" {
  let set = LinkSet::from_links([web_link("/a"), web_link("/b")])
  assert_true(set.link_count() == 2)
  assert_false(set.is_empty())
  assert_str_eq(set.links()[0].target(), "/a")
  assert_str_eq(set.links()[1].target(), "/b")
}

///|
test "LinkSet::new is empty" {
  let set = LinkSet::new()
  assert_true(set.link_count() == 0)
  assert_true(set.is_empty())
}

///|
test "LinkSet::add appends links" {
  let set = LinkSet::new()
  set.add(web_link("/a"))
  set.add(web_link("/b"))
  assert_true(set.link_count() == 2)
  assert_str_eq(set.links()[1].target(), "/b")
}

///|
test "RelationType::matches is case-insensitive for registered names" {
  let rt : RelationType = Registered("Next")
  assert_true(rt.matches("NEXT"))
  assert_true(rt.matches("next"))
  assert_true(rt.matches("NeXt"))
  assert_false(rt.matches("previous"))
}

///|
test "RelationType::matches compares extension URIs exactly" {
  let rt : RelationType = Extension("https://example.com/rel")
  assert_true(rt.matches("https://example.com/rel"))
  assert_false(rt.matches("HTTPS://EXAMPLE.COM/REL"))
  assert_false(rt.matches("https://example.com/other"))
}

///|
test "RelationType accessors split the two forms" {
  let reg : RelationType = Registered("author")
  let ext : RelationType = Extension("https://e.test/rel")
  assert_true(reg.is_registered())
  assert_false(reg.is_extension())
  match reg.name() {
    Some(n) => assert_str_eq(n, "author")
    None => fail("registered name should be present")
  }
  assert_true(reg.extension_uri() is None)
  assert_false(ext.is_registered())
  assert_true(ext.is_extension())
  assert_true(ext.name() is None)
  match ext.extension_uri() {
    Some(u) => assert_str_eq(u, "https://e.test/rel")
    None => fail("extension URI should be present")
  }
}

///|
test "WebLink::has_relation and relation_names" {
  let link = web_link("/p")
  link.relations.push(Registered("next"))
  link.relations.push(Extension("https://e.test/x"))
  assert_true(link.has_relation("NEXT"))
  assert_true(link.has_relation("next"))
  assert_true(link.has_relation("https://e.test/x"))
  assert_false(link.has_relation("prev"))
  assert_true(link.relation_names().length() == 2)
  assert_str_eq(link.relation_names()[0], "next")
  assert_str_eq(link.relation_names()[1], "https://e.test/x")
}

///|
test "WebLink::has_relation on a link with no relations is false" {
  let link = web_link("/p")
  assert_false(link.has_relation("next"))
  assert_true(link.relation_names().is_empty())
}

///|
test "ExtendedValue accessors return the stored parts" {
  let ev = { charset: "UTF-8", language: Some("en"), value: "hello" }
  assert_str_eq(ev.charset(), "UTF-8")
  match ev.language() {
    Some(l) => assert_str_eq(l, "en")
    None => fail("language should be present")
  }
  assert_str_eq(ev.value(), "hello")
}

///|
test "LinkParameter accessors return the stored parts" {
  let p = { name: "x-foo", value: Some("bar"), quoted: true }
  assert_str_eq(p.name(), "x-foo")
  match p.value() {
    Some(v) => assert_str_eq(v, "bar")
    None => fail("value should be present")
  }
  assert_true(p.quoted())
}

///|
test "model structs are constructible with field syntax" {
  let link : WebLink = {
    target: "https://example.com/x",
    relations: [Registered("next")],
    anchor: Some("https://example.com/"),
    hreflang: ["en"],
    media: Some("screen"),
    title: Some("Hello"),
    title_star: None,
    media_type: Some("text/html"),
    extensions: [{ name: "x-flag", value: None, quoted: false }],
  }
  assert_str_eq(link.target(), "https://example.com/x")
  assert_true(link.relations().length() == 1)
  match link.anchor() {
    Some(a) => assert_str_eq(a, "https://example.com/")
    None => fail("anchor should be present")
  }
  assert_str_eq(link.hreflang()[0], "en")
  assert_true(link.extensions().length() == 1)
}
