// audit_header — Example: run the deterministic, offline audit over a
// `Link` header field value and print every finding.
//
// The header below demonstrates the patterns the audit flags: the deprecated
// `rev` parameter, a relation type that looks registered but is not in the
// IANA snapshot, and a `title`/`title*` coexistence.
//
// Run: moon run examples/audit_header

///|
fn main {
  let header = "<https://example.com/a>; rel=\"canonical\"; rev=\"made\", " +
    "<https://example.com/b>; rel=\"mystrey\"; title=\"T\"; title*=UTF-8'en'T"
  match @weblink.audit_link_header(header) {
    Err(e) => println("error: \{e.to_display()}")
    Ok(report) => {
      if report.is_clean() {
        println("audit: clean")
      } else {
        for issue in report.issues() {
          println(
            "\{issue.severity().to_string()} \{issue.code()} [link \{issue.link_index().to_string()}]: \{issue.message()}",
          )
        }
      }
      println("findings: \{report.issue_count().to_string()}")
    }
  }
}
