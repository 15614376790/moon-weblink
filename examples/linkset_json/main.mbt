// linkset_json — Example: convert a `Link` header field value to an
// `application/linkset+json` document (RFC 9264 Section 4.2) and back, with
// no loss at the model level.
//
// Run: moon run examples/linkset_json

///|
fn main {
  let header = "<https://example.com/>; rel=\"canonical\", " +
    "<https://cdn.example.com/a.js>; rel=\"stylesheet\"; media=\"screen\""

  // Link header -> linkset JSON.
  match
    @weblink.link_header_to_linkset_json(header, @weblink.Limits::default()) {
    Err(e) => println("error: \{e.to_display()}")
    Ok(json) => {
      println("linkset JSON:")
      println(json)
      // linkset JSON -> canonical Link header.
      match
        @weblink.linkset_json_to_link_header(json, @weblink.Limits::default()) {
        Err(e) => println("back-conversion error: \{e.to_display()}")
        Ok(back) => {
          println("back to a Link header:")
          println(back)
        }
      }
    }
  }
}
