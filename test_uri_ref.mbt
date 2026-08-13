// test_uri_ref.mbt — Tests for RFC 3986 URI-reference parsing and resolution
// (uri_ref.mbt), including the official test vectors of RFC 3986 Section 5.4.

///|
/// Resolves `reference` against the RFC 3986 base and checks the result.
fn assert_resolves(reference : String, expected : String) -> Unit raise {
  let got = unwrap_ok(
    resolve_uri_reference_string("http://a/b/c/d;p?q", reference),
  )
  assert_str_eq(got, expected)
}

///|
test "parse_uri_reference decomposes every component" {
  let uri = unwrap_ok(parse_uri_reference("http://example.com:8080/path?q=1#f"))
  match uri.scheme() {
    Some(s) => assert_str_eq(s, "http")
    None => fail("scheme missing")
  }
  match uri.authority() {
    Some(a) => assert_str_eq(a, "example.com:8080")
    None => fail("authority missing")
  }
  assert_str_eq(uri.path(), "/path")
  match uri.query() {
    Some(q) => assert_str_eq(q, "q=1")
    None => fail("query missing")
  }
  match uri.fragment() {
    Some(f) => assert_str_eq(f, "f")
    None => fail("fragment missing")
  }
}

///|
test "parse_uri_reference of a relative reference has no scheme or authority" {
  let uri = unwrap_ok(parse_uri_reference("../../g?y#s"))
  assert_true(uri.scheme() is None)
  assert_true(uri.authority() is None)
  assert_str_eq(uri.path(), "../../g")
  match uri.query() {
    Some(q) => assert_str_eq(q, "y")
    None => fail("query missing")
  }
  match uri.fragment() {
    Some(f) => assert_str_eq(f, "s")
    None => fail("fragment missing")
  }
}

///|
test "parse_uri_reference of the empty string is empty" {
  let uri = unwrap_ok(parse_uri_reference(""))
  assert_str_eq(uri.to_string(), "")
  assert_true(uri.scheme() is None)
  assert_str_eq(uri.path(), "")
}

///|
test "recomposition round-trips the components" {
  let s = "https://user:pass@host:8443/a/b%20c?d=e&f#g-h"
  let uri = unwrap_ok(parse_uri_reference(s))
  assert_str_eq(uri.to_string(), s)
}

///|
test "percent-encoding is preserved byte-for-byte" {
  let uri = unwrap_ok(parse_uri_reference("/a%2Fb%20c"))
  assert_str_eq(uri.path(), "/a%2Fb%20c")
}

///|
test "malformed percent-encoding is rejected" {
  expect_err_kind(
    parse_uri_reference("http://ex%ample"),
    InvalidPercentEncoding,
  )
  expect_err_kind(parse_uri_reference("http://ex%2"), InvalidPercentEncoding)
  expect_err_kind(parse_uri_reference("http://ex%GG"), InvalidPercentEncoding)
}

///|
test "percent-encoding is allowed in the authority" {
  // reg-name and userinfo both permit pct-encoded octets (RFC 3986).
  let uri = unwrap_ok(parse_uri_reference("http://%65xample.com/~u"))
  match uri.authority() {
    Some(a) => assert_str_eq(a, "%65xample.com")
    None => fail("authority missing")
  }
  let user = unwrap_ok(parse_uri_reference("http://user%20name@host/x"))
  match user.authority() {
    Some(a) => assert_str_eq(a, "user%20name@host")
    None => fail("authority missing")
  }
}

///|
test "space and control characters in a URI are rejected" {
  expect_err_kind(parse_uri_reference("http://exa mple.com"), InvalidToken)
  expect_err_kind(parse_uri_reference("http://example.com/\u{1}"), InvalidToken)
}

///|
test "colon in the first path segment without a scheme is ambiguous" {
  expect_err_kind(parse_uri_reference("1a:b"), InvalidToken)
}

///|
test "scheme must start with a letter" {
  expect_err_kind(parse_uri_reference("1http://x"), InvalidToken)
}

///|
test "scheme characters are letters digits plus dot dash" {
  let uri = unwrap_ok(parse_uri_reference("mailto:user@example.com"))
  match uri.scheme() {
    Some(s) => assert_str_eq(s, "mailto")
    None => fail("scheme missing")
  }
  assert_str_eq(uri.path(), "user@example.com")
}

///|
test "IPv6 authority is accepted" {
  let uri = unwrap_ok(parse_uri_reference("http://[::1]:8080/x"))
  match uri.authority() {
    Some(a) => assert_str_eq(a, "[::1]:8080")
    None => fail("authority missing")
  }
}

///|
test "remove_dot_segments collapses dot segments" {
  assert_str_eq(remove_dot_segments("/a/b/c/./../../g"), "/a/g")
  assert_str_eq(remove_dot_segments("mid/content=5/../6"), "mid/6")
  assert_str_eq(remove_dot_segments("/a/./b/../c"), "/a/c")
  assert_str_eq(remove_dot_segments("/a/b/../../"), "/")
  assert_str_eq(remove_dot_segments(""), "")
  assert_str_eq(remove_dot_segments("/"), "/")
}

// --- RFC 3986 Section 5.4.1: Normal Examples -------------------------------

///|
test "RFC 3986 5.4.1 normal examples" {
  assert_resolves("g:h", "g:h")
  assert_resolves("g", "http://a/b/c/g")
  assert_resolves("./g", "http://a/b/c/g")
  assert_resolves("g/", "http://a/b/c/g/")
  assert_resolves("/g", "http://a/g")
  assert_resolves("//g", "http://g")
  assert_resolves("?y", "http://a/b/c/d;p?y")
  assert_resolves("g?y", "http://a/b/c/g?y")
  assert_resolves("#s", "http://a/b/c/d;p?q#s")
  assert_resolves("g#s", "http://a/b/c/g#s")
  assert_resolves("g?y#s", "http://a/b/c/g?y#s")
  assert_resolves(";x", "http://a/b/c/;x")
  assert_resolves("g;x", "http://a/b/c/g;x")
  assert_resolves("g;x?y#s", "http://a/b/c/g;x?y#s")
  assert_resolves("", "http://a/b/c/d;p?q")
  assert_resolves(".", "http://a/b/c/")
  assert_resolves("./", "http://a/b/c/")
  assert_resolves("..", "http://a/b/")
  assert_resolves("../", "http://a/b/")
  assert_resolves("../g", "http://a/b/g")
  assert_resolves("../..", "http://a/")
  assert_resolves("../../", "http://a/")
  assert_resolves("../../g", "http://a/g")
}

// --- RFC 3986 Section 5.4.2: Abnormal Examples ------------------------------

///|
test "RFC 3986 5.4.2 abnormal examples" {
  assert_resolves("../../../g", "http://a/g")
  assert_resolves("../../../../g", "http://a/g")
  assert_resolves("/./g", "http://a/g")
  assert_resolves("/../g", "http://a/g")
  assert_resolves("g.", "http://a/b/c/g.")
  assert_resolves(".g", "http://a/b/c/.g")
  assert_resolves("g..", "http://a/b/c/g..")
  assert_resolves("..g", "http://a/b/c/..g")
  assert_resolves("./../g", "http://a/b/g")
  assert_resolves("./g/.", "http://a/b/c/g/")
  assert_resolves("g/./h", "http://a/b/c/g/h")
  assert_resolves("g/../h", "http://a/b/c/h")
  assert_resolves("g;x=1/./y", "http://a/b/c/g;x=1/y")
  assert_resolves("g;x=1/../y", "http://a/b/c/y")
  assert_resolves("g?y/./x", "http://a/b/c/g?y/./x")
  assert_resolves("g?y/../x", "http://a/b/c/g?y/../x")
  assert_resolves("g#s/./x", "http://a/b/c/g#s/./x")
  assert_resolves("g#s/../x", "http://a/b/c/g#s/../x")
}

///|
test "resolve an absolute reference ignores the base entirely" {
  let got = unwrap_ok(
    resolve_uri_reference_string("http://a/b/c/d;p?q", "https://other/x"),
  )
  assert_str_eq(got, "https://other/x")
}

///|
test "resolve with an empty base path uses the authority" {
  let got = unwrap_ok(resolve_uri_reference_string("http://a", "b"))
  assert_str_eq(got, "http://a/b")
}

///|
test "resolve against a base without authority" {
  let got = unwrap_ok(resolve_uri_reference_string("/base/path/x", "y"))
  assert_str_eq(got, "/base/path/y")
}

///|
test "resolve preserves a new fragment and drops the base fragment" {
  let got = unwrap_ok(
    resolve_uri_reference_string("http://a/b?old#basefrag", "#new"),
  )
  assert_str_eq(got, "http://a/b?old#new")
}

///|
test "resolve returns errors for malformed inputs" {
  expect_err_kind(
    resolve_uri_reference_string("http://exa mple", "x"),
    InvalidToken,
  )
  expect_err_kind(
    resolve_uri_reference_string("http://a", "ex%ample"),
    InvalidPercentEncoding,
  )
}

///|
test "UriReference::empty is a well-formed empty reference" {
  let e = UriReference::empty()
  assert_str_eq(e.to_string(), "")
  assert_true(e.scheme() is None)
  assert_true(e.authority() is None)
  assert_str_eq(e.path(), "")
}
