// test_truncation.mbt — Truncation safety.
//
// The parser front doors must accept a stream that ends at any byte offset:
// a truncated header, a truncated JSON document, a truncated URI or extended
// value. Every byte-prefix of the complex inputs below is fed to the parsers;
// none may panic and every outcome is either `Ok` or a structured `Err`.
// All inputs in this file are ASCII, so a byte-prefix is a character boundary.
//
// The two tests together exercise more than 2000 (prefix, parser) cases.

///|
/// The first `n` bytes of `s` (safe because the inputs here are ASCII).
fn byte_prefix(s : String, n : Int) -> String {
  let bytes = @utf8.encode(s)
  decode_utf8(bytes.view(start=0, end=n))
}

///|
/// Evaluates a result, discarding it (used to force parser execution).
fn[T] force(r : Result[T, LinkError]) -> Unit {
  match r {
    Ok(_) => ()
    Err(_) => ()
  }
}

///|
test "every byte-prefix of a complex Link header and linkset text never panics" {
  let dflt = Limits::default()
  let header = "<https://example.com/a/b?q=1#frag>; rel=\"next prev https://rel.example/x\"; anchor=\"https://example.com/\"; hreflang=\"en-US\"; hreflang=\"fr\"; media=\"print\"; title=\"A title with \\\"quotes\\\" and \\\\backslashes\"; title*=UTF-8'en'h%C3%A9llo; type=\"text/html; charset=utf-8\"; x-note=value1; x-flag; hreflang=\"de\"; x-extra=abcdefghij"
  let text = "<a>; rel=\"next\",\n<b>; rel=\"prev\"; media=\"screen\",\n<https://e.example/x>; rel=\"canonical\""
  let len1 = @utf8.encode(header).length()
  let len2 = @utf8.encode(text).length()
  assert_true(len1 + len2 >= 400)

  let mut cases = 0
  for i = 0; i <= len1; i = i + 1 {
    let p = byte_prefix(header, i)
    force(parse_link_header(p, dflt))
    force(parse_linkset_text(p, dflt))
    force(canonicalize_link_header(p))
    force(parse_linkset_json(p, dflt))
    force(parse_uri_reference(p))
    cases = cases + 5
  }
  for i = 0; i <= len2; i = i + 1 {
    let p = byte_prefix(text, i)
    force(parse_linkset_text(p, dflt))
    force(parse_link_header(p, dflt))
    cases = cases + 2
  }
  assert_true(cases >= 1500)
}

///|
test "every byte-prefix of complex JSON, URI and ext-value inputs never panics" {
  let dflt = Limits::default()
  let json = "{\"linkset\":[{\"anchor\":\"https://example.com/\",\"next\":[{\"href\":\"https://example.com/next\",\"hreflang\":[\"en\",\"fr\",\"de\"],\"media\":\"print\",\"title\":\"T\",\"type\":\"text/html\",\"x-note\":[\"v1\",\"v2\"]}],\"prev\":[{\"href\":\"https://example.com/prev\",\"media\":\"screen\",\"hreflang\":[\"en\"],\"title*\":[{\"value\":\"salut\",\"language\":\"fr\"}]}],\"https://rel.example/x\":[{\"href\":\"/other\"}]}]}"
  let uri = "https://user%20name@example.com:8443/a%2Fb/c/d/e/f/g;p?q=%20x%20y&r=z&s=w&t=v#frag"
  let ext = "UTF-8'en'hello%20world%2C%20with%20%C3%A9%20accented%20and%20more%20text%20here%20and%20there%20everywhere"
  let lj = @utf8.encode(json).length()
  let lu = @utf8.encode(uri).length()
  let le = @utf8.encode(ext).length()
  assert_true(lj + lu + le >= 500)

  let mut cases = 0
  for i = 0; i <= lj; i = i + 1 {
    force(parse_linkset_json(byte_prefix(json, i), dflt))
    cases = cases + 1
  }
  for i = 0; i <= lu; i = i + 1 {
    let p = byte_prefix(uri, i)
    force(parse_uri_reference(p))
    force(parse_link_header("<\{p}>; rel=\"next\"", dflt))
    cases = cases + 2
  }
  for i = 0; i <= le; i = i + 1 {
    let p = byte_prefix(ext, i)
    force(parse_extended_value_string(p))
    force(parse_link_header("<a>; title*=\{p}", dflt))
    cases = cases + 2
  }
  assert_true(cases >= 400)
}
