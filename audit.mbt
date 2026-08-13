// audit.mbt — Deterministic, offline audit of a link collection.
//
// Audit reviews a parsed `LinkSet` for suspicious or deprecated patterns. It
// is advisory: a link set with issues is still well-formed and usable. Every
// check is a pure function of the model:
//
//   - the registry membership check uses the offline IANA snapshot
//     (relation_registry.mbt) — audit never performs a network request,
//   - the checks run in a fixed order and links are walked in document
//     order, so `audit_link_set` is deterministic: the same input always
//     produces the same report.
//
// Audit catches the patterns RFC 8288 warns about: the deprecated `rev`
// parameter, relation types that look registered but are not in the registry
// (typos are the classic case), the coexistence of `title` and `title*`,
// redundant or relative anchors, values beyond the configured resource
// limits, and duplicate parameter names or duplicate links.
//
// The parser itself enforces RFC 8288's first-wins rule for the
// single-occurrence target attributes, so a model never contains two
// `anchor` / `media` / `title` / `type` values; duplicates of *extension*
// parameters are preserved in `WebLink::extensions` and are reported here.

///|
/// The importance of an audit finding.
pub enum AuditSeverity {
  Info
  Warning
  Error
} derive(Eq)

///|
/// A single audit finding. `code` is a stable, machine-readable identifier;
/// `message` is human readable; `link_index` is the 0-based index of the
/// offending link, or `-1` for a set-level finding.
pub struct AuditIssue {
  severity : AuditSeverity
  code : String
  message : String
  link_index : Int
}

///|
/// The result of auditing a link set: every finding, in deterministic order.
pub struct AuditReport {
  issues : Array[AuditIssue]
}

///|
/// The stable lowercase name of a severity, used by the CLI JSON output.
pub fn AuditSeverity::to_string(self : AuditSeverity) -> String {
  match self {
    Info => "info"
    Warning => "warning"
    Error => "error"
  }
}

///|
/// The severity of this finding.
pub fn AuditIssue::severity(self : AuditIssue) -> AuditSeverity {
  self.severity
}

///|
/// The stable machine-readable code of this finding.
pub fn AuditIssue::code(self : AuditIssue) -> String {
  self.code
}

///|
/// A human readable description of this finding.
pub fn AuditIssue::message(self : AuditIssue) -> String {
  self.message
}

///|
/// The 0-based index of the offending link, or `-1` for set-level findings.
pub fn AuditIssue::link_index(self : AuditIssue) -> Int {
  self.link_index
}

///|
/// The findings, in deterministic order.
pub fn AuditReport::issues(self : AuditReport) -> Array[AuditIssue] {
  self.issues
}

///|
/// The number of findings.
pub fn AuditReport::issue_count(self : AuditReport) -> Int {
  self.issues.length()
}

///|
/// Whether the report contains no findings.
pub fn AuditReport::is_clean(self : AuditReport) -> Bool {
  self.issues.is_empty()
}

///|
/// The number of findings at the given severity.
pub fn AuditReport::count_at(
  self : AuditReport,
  severity : AuditSeverity,
) -> Int {
  let mut n = 0
  for issue in self.issues {
    if issue.severity == severity {
      n = n + 1
    }
  }
  n
}

///|
/// Whether the report contains at least one `Error`-severity finding.
pub fn AuditReport::has_errors(self : AuditReport) -> Bool {
  self.issues.any(fn(i) { i.severity == Error })
}

///|
/// Audits a link set against the default resource limits.
pub fn audit_link_set(linkset : LinkSet) -> AuditReport {
  audit_link_set_with_limits(linkset, Limits::default())
}

///|
/// Audits a link set against the given resource limits. The parse-time
/// `max_links` and `max_input_bytes` bounds do not apply here (the model is
/// already in memory); the per-value bounds are still enforced.
pub fn audit_link_set_with_limits(
  linkset : LinkSet,
  limits : Limits,
) -> AuditReport {
  audit_links(linkset.links(), limits)
}

///|
fn audit_links(links : Array[WebLink], limits : Limits) -> AuditReport {
  let issues = Array::new()

  // Set-level: duplicate links (same target and same relation set).
  // The quadratic scan is bounded to keep worst-case audit cost linear for
  // very large link sets.
  if links.length() <= 512 {
    for i = 0; i < links.length(); i = i + 1 {
      for j = i + 1; j < links.length(); j = j + 1 {
        if links_equivalent(links[i], links[j]) {
          push_issue(
            issues,
            Warning,
            "duplicate-link",
            "duplicate link: same target and relation set as link \{i}",
            j,
          )
          break
        }
      }
    }
  }

  for i = 0; i < links.length(); i = i + 1 {
    audit_link(issues, links[i], i, limits)
  }

  { issues, }
}

///|
/// Parses `input` as a `Link` header with the default limits and audits the
/// result. Any parse error is returned unchanged.
pub fn audit_link_header(input : String) -> Result[AuditReport, LinkError] {
  audit_link_header_with_limits(input, Limits::default())
}

///|
/// Parses `input` as a `Link` header with the given limits and audits the
/// result. Any parse error is returned unchanged.
pub fn audit_link_header_with_limits(
  input : String,
  limits : Limits,
) -> Result[AuditReport, LinkError] {
  match parse_link_header_detailed(input, limits) {
    Ok(parsed) => {
      let base = audit_links(parsed.links(), limits)
      Ok(add_duplicate_singletons(base, parsed.duplicates()))
    }
    Err(e) => Err(e)
  }
}

///|
/// Adds a set-level finding for every single-occurrence parameter that the
/// parser had to ignore (RFC 8288 first-wins).
fn add_duplicate_singletons(
  base : AuditReport,
  duplicates : Array[String],
) -> AuditReport {
  if duplicates.is_empty() {
    return base
  }
  let issues = Array::new()
  for issue in base.issues() {
    issues.push(issue)
  }
  for name in duplicates {
    push_issue(
      issues,
      Info,
      "duplicate-singleton",
      "single-occurrence parameter \"\{name}\" appeared more than once; later values were ignored",
      -1,
    )
  }
  { issues, }
}

///|
fn push_issue(
  issues : Array[AuditIssue],
  severity : AuditSeverity,
  code : String,
  message : String,
  link_index : Int,
) -> Unit {
  issues.push({ severity, code, message, link_index })
}

///|
fn audit_link(
  issues : Array[AuditIssue],
  link : WebLink,
  index : Int,
  limits : Limits,
) -> Unit {
  // 1. Deprecated `rev` parameter (RFC 8288 Section 3.4.1). The parser
  //    preserves it as an extension parameter; flag it here.
  for p in link.extensions() {
    if p.name().equal_ignore_ascii_case("rev") {
      push_issue(
        issues,
        Warning,
        "deprecated-rev",
        "\"rev\" is deprecated by RFC 8288; use a registered relation type",
        index,
      )
    }
  }

  // 2. Relation types that look registered (token form) but are not in the
  //    offline IANA snapshot. A typo is the common cause.
  for rt in link.relations() {
    if rt.is_registered() {
      let name = match rt {
        Registered(n) => n
        Extension(_) => abort("unreachable: is_registered is false")
      }
      if !is_registered_relation(name) {
        push_issue(
          issues,
          Warning,
          "unregistered-relation",
          "relation type \"\{name}\" is not in the IANA registry",
          index,
        )
      }
    }
  }

  // 3. Coexistence of `title` and `title*` (RFC 8288 Section 3.4.2).
  //    When both are present applications SHOULD use the `title*` value.
  match link.title() {
    Some(_) =>
      match link.title_star() {
        Some(_) =>
          push_issue(
            issues,
            Info,
            "title-and-title-star",
            "both title and title* are present; title* should be preferred",
            index,
          )
        None => ()
      }
    None => ()
  }

  // 4. Anchor checks (RFC 8288 Section 3.2): an anchor equal to the target
  //    is redundant, and a relative anchor leaves the context ambiguous.
  match link.anchor() {
    Some(a) =>
      if a == link.target() {
        push_issue(
          issues,
          Info,
          "redundant-anchor",
          "anchor equals the link target",
          index,
        )
      } else if !is_absolute_uri_reference(a) {
        push_issue(
          issues,
          Warning,
          "relative-anchor",
          "anchor \"\{a}\" is a relative reference; the context is ambiguous",
          index,
        )
      }
    None => ()
  }

  // 5. Oversized values relative to the configured limits.
  if byte_len(link.target()) > limits.max_target_bytes() {
    push_issue(
      issues,
      Warning,
      "oversized-target",
      "target exceeds max_target_bytes (\{limits.max_target_bytes()})",
      index,
    )
  }
  match link.title() {
    Some(t) =>
      if byte_len(t) > limits.max_quoted_string_bytes() {
        push_issue(
          issues,
          Warning,
          "oversized-title",
          "title exceeds max_quoted_string_bytes (\{limits.max_quoted_string_bytes()})",
          index,
        )
      }
    None => ()
  }
  match link.title_star() {
    Some(ev) =>
      if byte_len(ev.value()) > limits.max_quoted_string_bytes() {
        push_issue(
          issues,
          Warning,
          "oversized-title",
          "title* value exceeds max_quoted_string_bytes (\{limits.max_quoted_string_bytes()})",
          index,
        )
      }
    None => ()
  }
  for p in link.extensions() {
    if byte_len(p.name()) > limits.max_parameter_name_bytes() {
      push_issue(
        issues,
        Warning,
        "oversized-parameter",
        "parameter name exceeds max_parameter_name_bytes (\{limits.max_parameter_name_bytes()})",
        index,
      )
    }
    match p.value() {
      Some(v) =>
        if byte_len(v) > limits.max_parameter_value_bytes() {
          push_issue(
            issues,
            Warning,
            "oversized-parameter",
            "parameter value exceeds max_parameter_value_bytes (\{limits.max_parameter_value_bytes()})",
            index,
          )
        }
      None => ()
    }
  }

  // 6. Duplicate extension parameter names (extension params are repeatable,
  //    so this is legal — but a repeated name is usually a sender bug).
  for k = 0; k < link.extensions().length(); k = k + 1 {
    let name = link.extensions()[k].name()
    let mut earlier = false
    for m = 0; m < k; m = m + 1 {
      if link.extensions()[m].name().equal_ignore_ascii_case(name) {
        earlier = true
        break
      }
    }
    if earlier {
      push_issue(
        issues,
        Info,
        "duplicate-extension-parameter",
        "extension parameter \"\{name}\" appears more than once",
        index,
      )
    }
  }
}

///|
fn links_equivalent(a : WebLink, b : WebLink) -> Bool {
  if a.target() != b.target() {
    return false
  }
  let an = a.relation_names()
  let bn = b.relation_names()
  if an.length() != bn.length() {
    return false
  }
  for i = 0; i < an.length(); i = i + 1 {
    if an[i] != bn[i] {
      return false
    }
  }
  true
}

///|
/// Byte length of a string (UTF-8 encoding). Used by the limit checks.
fn byte_len(s : String) -> Int {
  @utf8.encode(s).length()
}

///|
/// Whether `s` is an absolute URI reference, i.e. starts with a valid
/// RFC 3986 scheme. Used to distinguish absolute anchors from relative ones.
fn is_absolute_uri_reference(s : String) -> Bool {
  let bytes = @utf8.encode(s)
  let n = bytes.length()
  if n == 0 {
    return false
  }
  if !is_alpha(bytes[0]) {
    return false
  }
  for i = 1; i < n; i = i + 1 {
    let b = bytes[i]
    if b == 58 {
      return true
    }
    if is_alnum(b) {
      continue
    }
    if b == 43 || b == 45 || b == 46 {
      continue
    }
    return false
  }
  false
}

///|
fn is_alnum(b : Byte) -> Bool {
  is_alpha(b) || (b.to_int() >= 48 && b.to_int() <= 57)
}
