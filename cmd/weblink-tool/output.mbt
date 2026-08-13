// output.mbt — deterministic text and JSON rendering of links and reports.
//
// JSON here is emitted by hand (concatenation, never string interpolation
// inside quote-heavy literals) so the CLI has no runtime dependency beyond
// the library. The `parse --json` shape is a display format; the round-trippable
// documents are produced by the `to-linkset-json` / `from-linkset-json`
// subcommands through the library's own serializer.

///| Escapes a string for JSON: `"` and `\` are escaped, control characters

///|
/// below 0x20 become `\u00XX`, everything else is emitted as UTF-8.
fn json_quote(s : String) -> String {
  let sb = StringBuilder()
  sb.write_char('"')
  for c in s.iter() {
    let v = c.to_int()
    if v == 34 {
      sb.write_string("\\\"")
    } else if v == 92 {
      sb.write_string("\\\\")
    } else if v < 32 {
      sb.write_string("\\u00")
      sb.write_char(hex_digit(v / 16))
      sb.write_char(hex_digit(v % 16))
    } else {
      sb.write_char(c)
    }
  }
  sb.write_char('"')
  sb.to_string()
}

///|
fn hex_digit(v : Int) -> Char {
  if v < 10 {
    (48 + v).unsafe_to_char()
  } else {
    (65 + v - 10).unsafe_to_char()
  }
}

///|
/// The relation-type display text: the extension URI or the registered name.
fn relation_display(rt : @weblink.RelationType) -> String {
  match rt.extension_uri() {
    Some(u) => u
    None =>
      match rt.name() {
        Some(n) => n
        None => "?"
      }
  }
}

///|
/// The relation list of a link joined by single spaces (the `rel` value).
fn relation_list_text(link : @weblink.WebLink) -> String {
  let parts : Array[String] = Array::new()
  for rt in link.relations() {
    parts.push(relation_display(rt))
  }
  join(parts, " ")
}

///|
fn join(arr : Array[String], sep : String) -> String {
  let sb = StringBuilder()
  for i = 0; i < arr.length(); i = i + 1 {
    if i > 0 {
      sb.write_string(sep)
    }
    sb.write_string(arr[i])
  }
  sb.to_string()
}

///|
/// A human-readable multi-line rendering of one link.
fn render_link(index : Int, link : @weblink.WebLink) -> String {
  let sb = StringBuilder()
  sb.write_string("link ")
  sb.write_string(index.to_string())
  sb.write_string(": <")
  sb.write_string(link.target())
  sb.write_string(">; rel=\"")
  sb.write_string(relation_list_text(link))
  sb.write_string("\"")
  match link.anchor() {
    Some(a) => {
      sb.write_string("\n  anchor: ")
      sb.write_string(a)
    }
    None => ()
  }
  for hl in link.hreflang() {
    sb.write_string("\n  hreflang: ")
    sb.write_string(hl)
  }
  match link.media() {
    Some(m) => {
      sb.write_string("\n  media: ")
      sb.write_string(m)
    }
    None => ()
  }
  match link.title() {
    Some(t) => {
      sb.write_string("\n  title: ")
      sb.write_string(t)
    }
    None => ()
  }
  match link.title_star() {
    Some(ev) => {
      sb.write_string("\n  title*: ")
      sb.write_string(@weblink.serialize_extended_value(ev))
    }
    None => ()
  }
  match link.media_type() {
    Some(t) => {
      sb.write_string("\n  type: ")
      sb.write_string(t)
    }
    None => ()
  }
  for p in link.extensions() {
    sb.write_string("\n  ")
    sb.write_string(p.name())
    match p.value() {
      Some(v) => {
        sb.write_string("=")
        sb.write_string(v)
      }
      None => ()
    }
  }
  sb.to_string()
}

///|
/// A compact JSON object describing one link.
fn link_to_json(link : @weblink.WebLink) -> String {
  let sb = StringBuilder()
  sb.write_string("{\"target\": " + json_quote(link.target()))
  sb.write_string(", \"relations\": [" + rels_json(link) + "]")
  sb.write_string(", \"anchor\": " + opt_json(link.anchor()))
  sb.write_string(", \"hreflang\": [" + hreflang_json(link) + "]")
  sb.write_string(", \"media\": " + opt_json(link.media()))
  sb.write_string(", \"title\": " + opt_json(link.title()))
  match link.title_star() {
    Some(ev) =>
      sb.write_string(
        ", \"title*\": " + json_quote(@weblink.serialize_extended_value(ev)),
      )
    None => sb.write_string(", \"title*\": null")
  }
  sb.write_string(", \"type\": " + opt_json(link.media_type()))
  sb.write_string(", \"extensions\": [" + extensions_json(link) + "]}")
  sb.to_string()
}

///|
fn rels_json(link : @weblink.WebLink) -> String {
  let parts : Array[String] = Array::new()
  for rt in link.relations() {
    parts.push(json_quote(relation_display(rt)))
  }
  join(parts, ", ")
}

///|
fn hreflang_json(link : @weblink.WebLink) -> String {
  let parts : Array[String] = Array::new()
  for hl in link.hreflang() {
    parts.push(json_quote(hl))
  }
  join(parts, ", ")
}

///|
fn extensions_json(link : @weblink.WebLink) -> String {
  let parts : Array[String] = Array::new()
  for p in link.extensions() {
    match p.value() {
      Some(v) => parts.push(json_quote(p.name() + "=" + v))
      None => parts.push(json_quote(p.name()))
    }
  }
  join(parts, ", ")
}

///|
fn opt_json(v : String?) -> String {
  match v {
    Some(s) => json_quote(s)
    None => "null"
  }
}

///|
/// A JSON array of link objects.
fn links_json(links : Array[@weblink.WebLink]) -> String {
  let parts : Array[String] = Array::new()
  for link in links {
    parts.push(link_to_json(link))
  }
  "[" + join(parts, ", ") + "]"
}

///|
/// A JSON object describing an audit report.
fn audit_json(report : @weblink.AuditReport) -> String {
  let parts : Array[String] = Array::new()
  for issue in report.issues() {
    let sb = StringBuilder()
    sb.write_string(
      "{\"severity\": " + json_quote(issue.severity().to_string()),
    )
    sb.write_string(", \"code\": " + json_quote(issue.code()))
    sb.write_string(", \"message\": " + json_quote(issue.message()))
    sb.write_string(", \"link_index\": " + issue.link_index().to_string() + "}")
    parts.push(sb.to_string())
  }
  "{\"issues\": [" +
  join(parts, ", ") +
  "], \"clean\": " +
  report.is_clean().to_string() +
  "}"
}
