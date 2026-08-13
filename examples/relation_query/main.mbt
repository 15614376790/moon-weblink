// relation_query — Example: query the offline IANA Link Relation Types
// registry snapshot (no network access at runtime) and filter links by
// relation type.
//
// Run: moon run examples/relation_query

///|
fn main {
  // Registry membership is checked against the bundled offline snapshot.
  for name in ["next", "canonical", "not-a-real-rel"] {
    if @weblink.is_registered_relation(name) {
      match @weblink.relation_info(name) {
        Some(info) => println("\{name}: registered — \{info.description()}")
        None => println("\{name}: registered")
      }
    } else {
      println("\{name}: not registered (not in the offline IANA snapshot)")
    }
  }

  // Filter a header by relation type.
  let header = "<https://a.example/>; rel=\"next\", <https://b.example/>; rel=\"alternate\""
  match @weblink.parse_link_header(header, @weblink.Limits::default()) {
    Err(e) => println("error: \{e.to_display()}")
    Ok(links) => {
      let nexts = @weblink.filter_by_relation(links, "next")
      println("links with rel=next: \{nexts.length()}")
      for l in nexts {
        println("  \{l.target()}")
      }
    }
  }

  println(
    "registered relations in the snapshot: \{@weblink.registered_relation_count()}",
  )
}
