// commands.mbt — the concrete subcommand implementations of weblink-tool.
//
// Every command reads its input from `CliOptions` (the `--input` argument or
// the first positional), runs the matching library function, and writes a
// deterministic report to stdout. On error the CLI prints one `error:` line
// (stage, kind, byte offset and bounded context) and continues; it never
// aborts the process, because a parser toolkit must be safe to script.

///|
fn print_error(e : @weblink.LinkError) -> Unit {
  println(
    "error: \{e.stage().to_string()}::\{e.kind().to_string()} at byte \{e.offset().to_string()}: \{e.context()}",
  )
}

///|
fn require_input(o : CliOptions) -> String {
  let input = get_input(o)
  if input.length() == 0 {
    println(
      "error: no input; pass the document with --input <text> or as a positional",
    )
  }
  input
}

///|
/// `parse`: parse a Link header field value and pretty-print each link, or
/// emit machine-readable JSON with `--json`.
fn cmd_parse(o : CliOptions) -> Unit {
  let input = require_input(o)
  if input.length() == 0 {
    return
  }
  let limits = resolve_limits(o.limits_preset)
  match @weblink.parse_link_header(input, limits) {
    Ok(links) => {
      if o.json {
        println(links_json(links))
      } else {
        for i = 0; i < links.length(); i = i + 1 {
          println(render_link(i, links[i]))
        }
      }
      println("links: \{links.length().to_string()}")
    }
    Err(e) => print_error(e)
  }
}

///|
/// `validate`: report whether the input is a well-formed Link header value.
fn cmd_validate(o : CliOptions) -> Unit {
  let input = require_input(o)
  if input.length() == 0 {
    return
  }
  match @weblink.parse_link_header(input, resolve_limits(o.limits_preset)) {
    Ok(links) => println("valid: true (\{links.length().to_string()} links)")
    Err(e) => {
      println("valid: false")
      print_error(e)
    }
  }
}

///|
/// `canonicalize`: emit the canonical RFC 8288 Link header serialization of
/// the parsed input.
fn cmd_canonicalize(o : CliOptions) -> Unit {
  let input = require_input(o)
  if input.length() == 0 {
    return
  }
  let result = if o.limits_preset == "default" {
    @weblink.canonicalize_link_header(input)
  } else {
    @weblink.canonicalize_link_header_with_limits(
      input,
      resolve_limits(o.limits_preset),
    )
  }
  match result {
    Ok(canon) => println(canon)
    Err(e) => print_error(e)
  }
}

///|
/// `query`: find links matching `--rel`, `--type` and/or `--hreflang`
/// filters (combined with AND) and print their targets.
fn cmd_query(o : CliOptions) -> Unit {
  let input = require_input(o)
  if input.length() == 0 {
    return
  }
  if o.rel == "" && o.media_type == "" && o.hreflang == "" {
    println("error: query needs at least one of --rel, --type, --hreflang")
    return
  }
  match @weblink.parse_link_header(input, resolve_limits(o.limits_preset)) {
    Err(e) => print_error(e)
    Ok(links) => {
      let mut matches = links
      if o.rel != "" {
        matches = @weblink.filter_by_relation(matches, o.rel)
      }
      if o.media_type != "" {
        matches = @weblink.filter_by_type(matches, o.media_type)
      }
      if o.hreflang != "" {
        matches = @weblink.filter_by_hreflang(matches, o.hreflang)
      }
      if o.json {
        println(links_json(matches))
      } else {
        for l in matches {
          println(l.target())
        }
      }
      println("matches: \{matches.length().to_string()}")
    }
  }
}

///|
/// `to-linkset-json`: convert a Link header (or a linkset text document) to
/// an `application/linkset+json` document.
fn cmd_to_linkset_json(o : CliOptions) -> Unit {
  let input = require_input(o)
  if input.length() == 0 {
    return
  }
  let limits = resolve_limits(o.limits_preset)
  let result = if input.trim().has_prefix("{") {
    @weblink.linkset_text_to_linkset_json(input, limits)
  } else {
    @weblink.link_header_to_linkset_json(input, limits)
  }
  match result {
    Ok(json) => println(json)
    Err(e) => print_error(e)
  }
}

///|
/// `from-linkset-json`: convert an `application/linkset+json` document to a
/// canonical Link header value.
fn cmd_from_linkset_json(o : CliOptions) -> Unit {
  let input = require_input(o)
  if input.length() == 0 {
    return
  }
  match
    @weblink.linkset_json_to_link_header(input, resolve_limits(o.limits_preset)) {
    Ok(header) => println(header)
    Err(e) => print_error(e)
  }
}

///|
/// `to-linkset-text`: convert a Link header or a linkset JSON document to an
/// `application/linkset` text document.
fn cmd_to_linkset_text(o : CliOptions) -> Unit {
  let input = require_input(o)
  if input.length() == 0 {
    return
  }
  let limits = resolve_limits(o.limits_preset)
  let result = if input.trim().has_prefix("{") {
    @weblink.linkset_json_to_linkset_text(input, limits)
  } else {
    match @weblink.link_header_to_linkset(input, limits) {
      Ok(set) => Ok(@weblink.linkset_to_linkset_text(set))
      Err(e) => Err(e)
    }
  }
  match result {
    Ok(text) => println(text)
    Err(e) => print_error(e)
  }
}

///|
/// `relation`: query the offline IANA Link Relation Types registry snapshot.
fn cmd_relation(o : CliOptions) -> Unit {
  if o.count {
    println(
      "registered relations: \{@weblink.registered_relation_count().to_string()}",
    )
    return
  }
  if o.list {
    for info in @weblink.registered_relations() {
      println(info.name())
    }
    println(
      "registered relations: \{@weblink.registered_relation_count().to_string()}",
    )
    return
  }
  let name = if o.rel != "" {
    o.rel
  } else if o.positionals.length() > 0 {
    o.positionals[0]
  } else {
    println("error: relation needs a name, --count or --list")
    return
  }
  if @weblink.is_registered_relation(name) {
    match @weblink.relation_info(name) {
      Some(info) => {
        println("relation: \{info.name()}")
        println("registered: true")
        println("description: \{info.description()}")
        if info.reference().length() > 0 {
          println("reference: \{info.reference()}")
        }
        if info.notes().length() > 0 {
          println("notes: \{info.notes()}")
        }
      }
      None => println("relation: \{name}\nregistered: true")
    }
  } else {
    println("relation: \{name}")
    println("registered: false (not in the offline IANA snapshot)")
  }
}

///|
/// `audit`: run the deterministic audit over a parsed Link header value.
fn cmd_audit(o : CliOptions) -> Unit {
  let input = require_input(o)
  if input.length() == 0 {
    return
  }
  match
    @weblink.audit_link_header_with_limits(
      input,
      resolve_limits(o.limits_preset),
    ) {
    Err(e) => print_error(e)
    Ok(report) => {
      if o.json {
        println(audit_json(report))
        return
      }
      if report.is_clean() {
        println("audit: clean")
      } else {
        for issue in report.issues() {
          println(
            "\{issue.severity().to_string()} \{issue.code()} [link \{issue.link_index().to_string()}]: \{issue.message()}",
          )
        }
      }
      let mut info_count = 0
      let mut warning_count = 0
      let mut error_count = 0
      for issue in report.issues() {
        let sev = issue.severity().to_string()
        if sev == "info" {
          info_count = info_count + 1
        } else if sev == "warning" {
          warning_count = warning_count + 1
        } else {
          error_count = error_count + 1
        }
      }
      println(
        "summary: \{info_count.to_string()} info, \{warning_count.to_string()} warnings, \{error_count.to_string()} errors",
      )
    }
  }
}

///|
/// `stats`: library statistics — the offline registry size and the resource
/// limit presets.
fn cmd_stats(_o : CliOptions) -> Unit {
  println("weblink-tool 0.1.0-dev (15614376790/moon-weblink)")
  println(
    "registered relations (offline IANA snapshot): \{@weblink.registered_relation_count().to_string()}",
  )
  print_limits("default", @weblink.Limits::default())
  print_limits("strict", @weblink.Limits::strict())
  print_limits("permissive", @weblink.Limits::permissive())
}

///|
fn print_limits(label : String, l : @weblink.Limits) -> Unit {
  let parts : Array[String] = Array::new()
  parts.push(label + ": input=" + l.max_input_bytes().to_string())
  parts.push("links=" + l.max_links().to_string())
  parts.push("params=" + l.max_params_per_link().to_string())
  parts.push("rels=" + l.max_relations_per_link().to_string())
  parts.push("target=" + l.max_target_bytes().to_string())
  println(join(parts, " "))
}
