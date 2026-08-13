// limits.mbt — Resource limits for moon-weblink.
//
// Link header values and Linkset documents are external, untrusted input.
// A hostile or buggy sender can produce multi-megabyte headers, thousands
// of links, thousands of parameters per link, or extremely long strings.
// Every public parser accepts a `Limits` value that bounds how much work a
// single parse may do. When a limit is exceeded the parser returns
// `LinkErrorKind::LimitExceeded`; it never panics and never silently
// truncates.
//
// Three presets are provided:
//   - `default()`   — generous, safe for normal use.
//   - `strict()`    — tight, for maximum-size network deployments.
//   - `permissive()`— large, for batch processing of known-good input.

///|
/// Bounds applied while parsing link data.
pub struct Limits {
  max_input_bytes : Int
  max_links : Int
  max_params_per_link : Int
  max_relations_per_link : Int
  max_target_bytes : Int
  max_parameter_name_bytes : Int
  max_parameter_value_bytes : Int
  max_quoted_string_bytes : Int
  max_linkset_links : Int
  max_json_bytes : Int
}

///|
/// Default limits. Intended for interactive and typical server use.
pub fn Limits::default() -> Limits {
  {
    max_input_bytes: 1 << 20,
    max_links: 1024,
    max_params_per_link: 256,
    max_relations_per_link: 64,
    max_target_bytes: 8192,
    max_parameter_name_bytes: 256,
    max_parameter_value_bytes: 8192,
    max_quoted_string_bytes: 16384,
    max_linkset_links: 8192,
    max_json_bytes: 4 << 20,
  }
}

///|
/// Strict limits. Intended for constrained deployments where every byte
/// counts and where the caller expects small, well-formed link data.
pub fn Limits::strict() -> Limits {
  {
    max_input_bytes: 16 * 1024,
    max_links: 64,
    max_params_per_link: 32,
    max_relations_per_link: 16,
    max_target_bytes: 512,
    max_parameter_name_bytes: 64,
    max_parameter_value_bytes: 1024,
    max_quoted_string_bytes: 2048,
    max_linkset_links: 256,
    max_json_bytes: 64 * 1024,
  }
}

///|
/// Permissive limits. Intended for batch processing of trusted data with
/// very large link sets.
pub fn Limits::permissive() -> Limits {
  {
    max_input_bytes: 64 << 20,
    max_links: 100000,
    max_params_per_link: 2048,
    max_relations_per_link: 1024,
    max_target_bytes: 1 << 20,
    max_parameter_name_bytes: 1024,
    max_parameter_value_bytes: 4 << 20,
    max_quoted_string_bytes: 8 << 20,
    max_linkset_links: 500000,
    max_json_bytes: 256 << 20,
  }
}

///|
/// Accessor for the input byte bound.
pub fn Limits::max_input_bytes(self : Limits) -> Int {
  self.max_input_bytes
}

///|
/// Accessor for the per-document link count bound.
pub fn Limits::max_links(self : Limits) -> Int {
  self.max_links
}

///|
/// Accessor for the per-link parameter count bound.
pub fn Limits::max_params_per_link(self : Limits) -> Int {
  self.max_params_per_link
}

///|
/// Accessor for the per-link relation count bound.
pub fn Limits::max_relations_per_link(self : Limits) -> Int {
  self.max_relations_per_link
}

///|
/// Accessor for the target (URI-reference) byte bound.
pub fn Limits::max_target_bytes(self : Limits) -> Int {
  self.max_target_bytes
}

///|
/// Accessor for the parameter name byte bound.
pub fn Limits::max_parameter_name_bytes(self : Limits) -> Int {
  self.max_parameter_name_bytes
}

///|
/// Accessor for the parameter value byte bound.
pub fn Limits::max_parameter_value_bytes(self : Limits) -> Int {
  self.max_parameter_value_bytes
}

///|
/// Accessor for the quoted-string byte bound.
pub fn Limits::max_quoted_string_bytes(self : Limits) -> Int {
  self.max_quoted_string_bytes
}

///|
/// Accessor for the Linkset link count bound.
pub fn Limits::max_linkset_links(self : Limits) -> Int {
  self.max_linkset_links
}

///|
/// Accessor for the Linkset JSON document byte bound.
pub fn Limits::max_json_bytes(self : Limits) -> Int {
  self.max_json_bytes
}
