// main.mbt — moon-weblink command-line tool: entry point and dispatch.
//
// The tool reads input exclusively from the `--input` argument. This MoonBit
// toolchain version exposes no stdin facility and `fn main` must return
// `Unit` (there is no portable way to set the process exit code), so the CLI
// reports every outcome as one deterministic line of stdout text, which makes
// it safe to script by grepping that text. The same binary builds unchanged
// for the wasm-gc, js and native targets. `moon run` passes the executable
// path as `@env.args()[0]`; `split_command` drops that leading token.

///|
fn main {
  run_cli(@env.args())
}

///|
fn run_cli(args : Array[String]) -> Unit {
  let (cmd, rest) = split_command(args)
  let opts = parse_options(rest)
  if opts.unknown != "" {
    println("error: unknown option \{opts.unknown}")
    println("run `weblink-tool help` for usage")
    return
  }
  if cmd == "help" {
    print_usage()
    return
  }
  if cmd == "version" {
    println("weblink-tool 0.1.0-dev (15614376790/moon-weblink)")
    return
  }
  if opts.help {
    print_command_usage(cmd)
    return
  }
  match cmd {
    "parse" => cmd_parse(opts)
    "validate" => cmd_validate(opts)
    "canonicalize" => cmd_canonicalize(opts)
    "query" => cmd_query(opts)
    "to-linkset-json" => cmd_to_linkset_json(opts)
    "from-linkset-json" => cmd_from_linkset_json(opts)
    "to-linkset-text" => cmd_to_linkset_text(opts)
    "relation" => cmd_relation(opts)
    "audit" => cmd_audit(opts)
    "stats" => cmd_stats(opts)
    _ => {
      println("error: unknown command '\{cmd}'")
      println("run `weblink-tool help` for usage")
    }
  }
}

///|
fn print_usage() -> Unit {
  println("weblink-tool — RFC 8288 Web Linking and RFC 9264 Linkset toolkit")
  println("usage: weblink-tool <command> [options]")
  println("")
  println("commands:")
  println("  parse             parse a Link header field value into links")
  println("  validate          parse and report valid/invalid")
  println("  canonicalize      emit the canonical Link header form")
  println("  query             find links by relation, media type, or hreflang")
  println(
    "  to-linkset-json   convert a Link header to application/linkset+json",
  )
  println(
    "  from-linkset-json convert application/linkset+json to a Link header",
  )
  println("  to-linkset-text   convert to application/linkset (multiline text)")
  println("  relation          query the offline IANA relation registry")
  println("  audit             audit a Link header for issues")
  println("  stats             print library and registry statistics")
  println("  version           print the version")
  println("  help              show this help")
  println("")
  println("options:")
  println("  --input <text>    the input string (required by most commands)")
  println("  --limits <p>      limits preset: default | strict | permissive")
  println("  --json            machine-readable JSON output (parse, audit)")
  println("  --rel <name>      query: filter by relation type")
  println("  --type <media>    query: filter by media type")
  println("  --hreflang <tag>  query: filter by hreflang language tag")
  println("  --list            relation: list the whole registry")
  println("  --count           relation: print only the registry count")
  println("  --help            show this help")
}

///|
fn print_command_usage(cmd : String) -> Unit {
  println("weblink-tool \{cmd} — see `weblink-tool help` for general usage")
}
