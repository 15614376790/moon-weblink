// parse_header — Example: parse an RFC 8288 `Link` header field value and
// print each parsed link.
//
// Run:
//   moon run examples/parse_header
//   moon run examples/parse_header -- --input "<https://example.com/page/2>; rel=\"next\"; title=\"Page 2\""
//
// The first token of `@env.args()` is the executable path, so the input is
// the second token when present; otherwise a built-in sample is used.

///|
fn main {
  let input = pick_input(@env.args())
  match @weblink.parse_link_header(input, @weblink.Limits::default()) {
    Ok(links) => {
      for i = 0; i < links.length(); i = i + 1 {
        let link = links[i]
        println("link \{i}: <\{link.target()}>; rel=\"\{relation_list(link)}\"")
        match link.title() {
          Some(t) => println("  title: \{t}")
          None => ()
        }
        match link.media_type() {
          Some(t) => println("  type: \{t}")
          None => ()
        }
        for hl in link.hreflang() {
          println("  hreflang: \{hl}")
        }
      }
      println("parsed \{links.length()} link(s)")
    }
    Err(e) => println("error: \{e.to_display()}")
  }
}

///|
fn pick_input(args : Array[String]) -> String {
  if args.length() > 2 && args[1] == "--input" {
    args[2]
  } else if args.length() > 1 && !args[1].has_prefix("-") {
    args[1]
  } else {
    "<https://example.com/page/2>; rel=\"next\"; title=\"Page 2\", <https://example.com/>; rel=\"canonical\""
  }
}

///|
fn relation_list(link : @weblink.WebLink) -> String {
  let parts : Array[String] = Array::new()
  for rt in link.relations() {
    match rt.extension_uri() {
      Some(u) => parts.push(u)
      None =>
        match rt.name() {
          Some(n) => parts.push(n)
          None => parts.push("?")
        }
    }
  }
  let mut out = ""
  for i = 0; i < parts.length(); i = i + 1 {
    if i > 0 {
      out = out + " "
    }
    out = out + parts[i]
  }
  out
}
