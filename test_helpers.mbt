// test_helpers.mbt — Shared test infrastructure for the moon-weblink suite.
//
// Everything here is deterministic. Property tests use a tiny fixed-seed
// PRNG (never the clock, never `random()`), and each test file seeds it with
// a distinct constant so the generated corpus is broad but perfectly
// reproducible on every platform and every run.
//
// Note: in MoonBit each `*_test.mbt` file is compiled as its own test unit,
// so helpers must be duplicated per file. The deterministic generators here
// are replicated (with a smaller surface) in the files that need them; the
// helpers that only depend on the public library API live in this file and
// are re-declared where used.

///|
/// Asserts that two strings are equal, printing both on failure.
fn assert_str_eq(actual : String, expected : String) -> Unit raise {
  if actual != expected {
    fail("strings differ.\n  expected: \{expected}\n  actual:   \{actual}")
  }
}

///|
/// Unwraps an Ok result, failing the test on error.
fn[T] unwrap_ok(r : Result[T, LinkError]) -> T raise {
  match r {
    Ok(v) => v
    Err(e) => fail("expected Ok, got: \{e.to_display()}")
  }
}

///|
/// Requires an `Err` with the exact `LinkErrorKind`, failing the test
/// otherwise.
fn[T] expect_err_kind(
  r : Result[T, LinkError],
  kind : LinkErrorKind,
) -> Unit raise {
  match r {
    Ok(_) => fail("expected error \{kind.to_string()}, got Ok")
    Err(e) =>
      if e.kind() == kind {
        ()
      } else {
        fail("expected kind \{kind.to_string()}, got \{e.to_display()}")
      }
  }
}

///|
/// Asserts that two `WebLink` arrays are semantically equivalent by comparing
/// their canonical serializations (deterministic by construction).
fn assert_links_eq(a : Array[WebLink], b : Array[WebLink]) -> Unit raise {
  assert_str_eq(serialize_link_header(a), serialize_link_header(b))
}

// LinkError is a `suberror` and cannot be stored as a value, so the error
// introspection helpers below extract a plain value (or assert) instead of
// returning the error itself.

///|
/// The offset of the `Err`, failing the test on `Ok`.
fn[T] err_offset(r : Result[T, LinkError]) -> Int raise {
  match r {
    Ok(_) => fail("expected Err, got Ok")
    Err(e) => e.offset()
  }
}

///|
/// The kind of the `Err`, failing the test on `Ok`.
fn[T] err_kind(r : Result[T, LinkError]) -> LinkErrorKind raise {
  match r {
    Ok(_) => fail("expected Err, got Ok")
    Err(e) => e.kind()
  }
}

///|
/// The stage of the `Err`, failing the test on `Ok`.
fn[T] err_stage(r : Result[T, LinkError]) -> LinkErrorStage raise {
  match r {
    Ok(_) => fail("expected Err, got Ok")
    Err(e) => e.stage()
  }
}

///|
/// The context string of the `Err`, failing the test on `Ok`.
fn[T] err_context(r : Result[T, LinkError]) -> String raise {
  match r {
    Ok(_) => fail("expected Err, got Ok")
    Err(e) => e.context()
  }
}

///|
/// The display string of the `Err`, failing the test on `Ok`.
fn[T] err_display(r : Result[T, LinkError]) -> String raise {
  match r {
    Ok(_) => fail("expected Err, got Ok")
    Err(e) => e.to_display()
  }
}

// ---------------------------------------------------------------------------
// Deterministic PRNG
// ---------------------------------------------------------------------------

///|
/// A tiny linear-congruential PRNG. Same seed, same stream, always. All
/// values stay in [1, 2^31-1] so no overflow is possible on 64-bit `Int`.
priv struct Rng {
  mut state : Int
}

///|
fn rng_new(seed : Int) -> Rng {
  let s = (seed * 1013904223 + 12345) & 2147483647
  { state: if s == 0 { 1 } else { s } }
}

///|
fn Rng::next(self : Rng) -> Int {
  let n = (self.state * 1103515245 + 12345) & 2147483647
  self.state = n
  n
}

///|
/// A random integer in `[lo, hi)`.
fn Rng::range(self : Rng, lo : Int, hi : Int) -> Int {
  if hi <= lo {
    lo
  } else {
    lo + self.next() % (hi - lo)
  }
}

///|
fn Rng::flip(self : Rng) -> Bool {
  self.next() % 2 == 0
}

// ---------------------------------------------------------------------------
// Random text / URI generators
// ---------------------------------------------------------------------------

///|
/// ASCII characters accepted by every predicate in this library in a token.
let token_chars : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#$%&'*+-.^_`|~"

///|
/// RFC 3986 unreserved characters only (safe in any URI position).
let uri_seg_chars : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"

///|
/// Printable ASCII plus space, quote and backslash. Every byte is safe in a
/// quoted-string and round-trips through the serializer.
let quoted_chars : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 !\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"

///|
/// A random string of `token_chars`, length in `[min_len, max_len]`.
fn Rng::token(self : Rng, min_len : Int, max_len : Int) -> String {
  let len = self.range(min_len, max_len)
  let chars = @utf8.encode(token_chars)
  let sb = StringBuilder()
  for _i = 0; _i < len; _i = _i + 1 {
    let idx = self.range(0, chars.length())
    sb.write_char(chars[idx].to_char())
  }
  sb.to_string()
}

///|
/// A random string of `uri_seg_chars` (unreserved only).
fn Rng::segment(self : Rng, min_len : Int, max_len : Int) -> String {
  let len = self.range(min_len, max_len)
  let chars = @utf8.encode(uri_seg_chars)
  let sb = StringBuilder()
  for _i = 0; _i < len; _i = _i + 1 {
    let idx = self.range(0, chars.length())
    sb.write_char(chars[idx].to_char())
  }
  sb.to_string()
}

///|
/// A random quoted-string payload (printable ASCII, space, `"`, `\`).
fn Rng::quoted(self : Rng) -> String {
  let len = self.range(0, 14)
  let chars = @utf8.encode(quoted_chars)
  let sb = StringBuilder()
  for _i = 0; _i < len; _i = _i + 1 {
    let idx = self.range(0, chars.length())
    sb.write_char(chars[idx].to_char())
  }
  sb.to_string()
}

///|
/// A random URI-reference that is strictly valid per RFC 3986.
fn Rng::uri(self : Rng) -> String {
  let kind = self.range(0, 6)
  let host = self.segment(1, 8)
  let seg1 = self.segment(1, 10)
  let seg2 = self.segment(1, 10)
  match kind {
    0 => "https://\{host}.example.com/\{seg1}"
    1 => "http://\{host}:8080/\{seg1}?q=\{seg2}#frag"
    2 => "/\{seg1}/\{seg2}"
    3 => "\{seg1}/\{seg2}"
    4 => "\{seg1}?v=\{seg2}"
    5 => "#\{seg1}"
    _ => "https://\{host}/"
  }
}

///|
/// A random valid RFC 5646 language tag.
fn Rng::lang_tag(self : Rng) -> String {
  let tags : Array[String] = [
    "en", "en-US", "en-GB", "de", "de-AT", "fr", "fr-CA", "zh", "zh-Hans", "ja",
    "pt-BR", "x-private", "sr-Latn-RS", "es-419",
  ]
  tags[self.range(0, tags.length())]
}

///|
/// A random valid media type (RFC 6838, may carry parameters).
fn Rng::media_type(self : Rng) -> String {
  let types : Array[String] = [
    "text/html", "text/plain", "application/json", "image/png", "text/html; charset=utf-8",
    "application/atom+xml; type=feed", "application/ld+json",
  ]
  types[self.range(0, types.length())]
}

// ---------------------------------------------------------------------------
// Random model builder
// ---------------------------------------------------------------------------

///|
/// Well-known registered relation types, used as relation candidates.
let known_rels : Array[String] = [
  "next", "prev", "canonical", "alternate", "author", "help", "license", "stylesheet",
  "preconnect", "icon", "manifest", "edit", "self", "item",
]

///|
/// A random non-empty relation-type array (registered and extension forms).
fn Rng::relations(self : Rng) -> Array[RelationType] {
  let n = self.range(1, 3)
  let out = Array::new()
  for _i = 0; _i < n; _i = _i + 1 {
    if self.flip() {
      out.push(Registered(known_rels[self.range(0, known_rels.length())]))
    } else {
      out.push(Extension("https://rel.example/" + self.segment(1, 8)))
    }
  }
  out
}

///|
/// A random extension parameter list (0-3 entries, distinct names).
/// Names are generated from unreserved characters only so they never end in
/// `*` (a `name*` parameter is an RFC 8187 ext-value in the serializer, which
/// would not round-trip a plain token value).
fn Rng::extensions(self : Rng) -> Array[LinkParameter] {
  let n = self.range(0, 3)
  let out = Array::new()
  for _i = 0; _i < n; _i = _i + 1 {
    let name = "x-" + self.segment(1, 6)
    let value = if self.flip() { self.token(1, 8) } else { self.quoted() }
    out.push({ name, value: Some(value), quoted: false })
  }
  out
}

///|
/// A random `WebLink` model. All values are ASCII, so the serialized forms of
/// every supported format (header, linkset text, linkset JSON) round-trip.
fn Rng::web_link(self : Rng) -> WebLink {
  {
    target: self.uri(),
    relations: self.relations(),
    anchor: if self.flip() {
      Some(self.uri())
    } else {
      None
    },
    hreflang: {
      let out = Array::new()
      let n = self.range(0, 3)
      for _i = 0; _i < n; _i = _i + 1 {
        out.push(self.lang_tag())
      }
      out
    },
    media: if self.flip() {
      Some(self.quoted())
    } else {
      None
    },
    title: if self.flip() {
      Some(self.quoted())
    } else {
      None
    },
    title_star: if self.flip() {
      Some({
        charset: "UTF-8",
        language: if self.flip() {
          Some(self.lang_tag())
        } else {
          None
        },
        value: self.quoted(),
      })
    } else {
      None
    },
    media_type: if self.flip() {
      Some(self.media_type())
    } else {
      None
    },
    extensions: self.extensions(),
  }
}
