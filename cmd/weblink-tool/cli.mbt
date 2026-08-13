// cli.mbt — argument model and parsing for the weblink-tool CLI.

///|
struct CliOptions {
  mut input : String
  mut input_set : Bool
  mut limits_preset : String
  mut json : Bool
  mut rel : String
  mut media_type : String
  mut hreflang : String
  mut list : Bool
  mut count : Bool
  mut help : Bool
  positionals : Array[String]
  mut unknown : String
}

///|
fn empty_options() -> CliOptions {
  {
    input: "",
    input_set: false,
    limits_preset: "default",
    json: false,
    rel: "",
    media_type: "",
    hreflang: "",
    list: false,
    count: false,
    help: false,
    positionals: Array::new(),
    unknown: "",
  }
}

///|
fn known_command(c : String) -> Bool {
  c == "parse" ||
  c == "validate" ||
  c == "canonicalize" ||
  c == "query" ||
  c == "to-linkset-json" ||
  c == "from-linkset-json" ||
  c == "to-linkset-text" ||
  c == "relation" ||
  c == "audit" ||
  c == "stats" ||
  c == "help" ||
  c == "version"
}

///| Splits `@env.args()` into the command and its options. `moon run` passes

///| the executable path as `args[0]`, so a leading token that is not itself a

///|
/// command is dropped.
fn split_command(args : Array[String]) -> (String, Array[String]) {
  if args.is_empty() {
    return ("help", Array::new())
  }
  let mut start = 0
  if !known_command(args[0]) {
    start = 1
  }
  if start >= args.length() {
    return ("help", Array::new())
  }
  let cmd = args[start]
  let rest = Array::new()
  for i = start + 1; i < args.length(); i = i + 1 {
    rest.push(args[i])
  }
  (cmd, rest)
}

///|
/// Parses the option tokens following a command into a `CliOptions`.
fn parse_options(args : Array[String]) -> CliOptions {
  let o = empty_options()
  let mut i = 0
  while i < args.length() {
    let a = args[i]
    if a == "--input" ||
      a == "--limits" ||
      a == "--rel" ||
      a == "--type" ||
      a == "--hreflang" {
      let value = if i + 1 < args.length() { args[i + 1] } else { "" }
      if a == "--input" {
        o.input = value
        o.input_set = true
      } else if a == "--limits" {
        o.limits_preset = value
      } else if a == "--rel" {
        o.rel = value
      } else if a == "--type" {
        o.media_type = value
      } else if a == "--hreflang" {
        o.hreflang = value
      }
      i = i + 2
    } else if a == "--json" {
      o.json = true
      i = i + 1
    } else if a == "--list" {
      o.list = true
      i = i + 1
    } else if a == "--count" {
      o.count = true
      i = i + 1
    } else if a == "--help" || a == "-h" {
      o.help = true
      i = i + 1
    } else if a.has_prefix("-") {
      o.unknown = a
      i = i + 1
    } else {
      o.positionals.push(a)
      i = i + 1
    }
  }
  o
}

///|
/// The version banner printed by `version` and `stats`, built from the
/// library's single-source version string.
fn version_banner() -> String {
  "weblink-tool \{@weblink.library_version()} (15614376790/moon-weblink)"
}

///|
/// The limits preset named by `--limits` (default / strict / permissive).
fn resolve_limits(preset : String) -> @weblink.Limits {
  if preset == "strict" {
    @weblink.Limits::strict()
  } else if preset == "permissive" {
    @weblink.Limits::permissive()
  } else {
    @weblink.Limits::default()
  }
}

///|
/// The input string: `--input` when set, else the first positional.
fn get_input(o : CliOptions) -> String {
  if o.input_set && o.input.length() > 0 {
    o.input
  } else if o.positionals.length() > 0 {
    o.positionals[0]
  } else {
    ""
  }
}
