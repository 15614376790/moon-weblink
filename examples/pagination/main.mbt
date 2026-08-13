// pagination — Example: walk a paginated API response using the `next` and
// `prev` relations, and resolve the targets against a base URI (RFC 3986
// Section 5.2.2).
//
// Run: moon run examples/pagination

///|
fn main {
  let header = "<https://api.example.com/users?page=2>; rel=\"next\"; type=\"application/json\", " +
    "<https://api.example.com/users?page=1>; rel=\"prev\""
  let base = "https://api.example.com/users"

  match @weblink.parse_link_header(header, @weblink.Limits::default()) {
    Err(e) => println("error: \{e.to_display()}")
    Ok(links) => {
      match @weblink.find_next(links) {
        Some(l) => println("next: \{l.target()}")
        None => println("next: none")
      }
      match @weblink.find_prev(links) {
        Some(l) => println("prev: \{l.target()}")
        None => println("prev: none")
      }
      // Resolve a relative reference against the base URI-reference.
      let relative = "./users?page=3"
      match @weblink.resolve_uri_reference_string(base, relative) {
        Ok(resolved) => println("resolved \{relative} -> \{resolved}")
        Err(e) => println("resolution error: \{e.to_display()}")
      }
      println("links parsed: \{links.length()}")
    }
  }
}
