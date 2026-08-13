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

///|
/// True when the token is a bare JavaScript/WASM engine name, with or
/// without the Windows `.exe` suffix.
fn is_engine_name(a : String) -> Bool {
  a == "node" ||
  a == "node.exe" ||
  a == "deno" ||
  a == "deno.exe" ||
  a == "bun" ||
  a == "bun.exe"
}

///|
/// True when the token is a program path: it contains a directory separator
/// and ends in an executable extension.
fn is_program_path(a : String) -> Bool {
  (a.contains("\\") || a.contains("/")) &&
  (
    a.has_suffix(".exe") ||
    a.has_suffix(".js") ||
    a.has_suffix(".cjs") ||
    a.has_suffix(".mjs") ||
    a.has_suffix(".wasm")
  )
}

///|
/// The number of leading argv tokens that are runtime/program prefixes:
/// engine names (`node`, `deno`, `bun`) and program paths. Scanning stops at
/// the first known command or the first token that is neither, so a real CLI
/// command or user input is never consumed.
fn strip_program_name(args : Array[String]) -> Int {
  let mut start = 0
  while start < args.length() {
    if known_command(args[start]) {
      break
    }
    if !is_engine_name(args[start]) && !is_program_path(args[start]) {
      break
    }
    start = start + 1
  }
  start
}

///|
/// Splits `@env.args()` into the command and its options.
///
/// Each MoonBit target prefixes `@env.args()` differently: native and
/// wasm-gc pass `[program, args...]`, js passes `[node, program.js,
/// args...]`. `strip_program_name` skips those prefixes uniformly. As a
/// fallback for platforms that report a bare executable name without a
/// directory separator, a single leading token that is not a known command
/// is dropped as well.
fn split_command(args : Array[String]) -> (String, Array[String]) {
  if args.is_empty() {
    return ("help", Array::new())
  }
  let mut start = strip_program_name(args)
  if start == 0 && !known_command(args[0]) {
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
