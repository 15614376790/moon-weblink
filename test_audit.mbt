// test_audit.mbt — Tests for the deterministic audit layer (audit.mbt).

///|
/// Whether the report contains at least one finding with the given code.
fn has_code(report : AuditReport, code : String) -> Bool {
  for issue in report.issues() {
    if issue.code() == code {
      return true
    }
  }
  false
}

///|
test "a clean link set audits clean" {
  // Registered relations and absolute anchors produce no findings.
  let report = unwrap_ok(
    audit_link_header(
      "<https://e.example/a>; rel=\"next\", <https://e.example/b>; rel=\"canonical\"; anchor=\"https://e.example/\"",
    ),
  )
  assert_true(report.is_clean())
  assert_true(report.issue_count() == 0)
  assert_true(report.has_errors() == false)
  assert_true(report.count_at(Warning) == 0)

  // Extension relation URIs are never flagged as unregistered.
  let ext = unwrap_ok(audit_link_header("<a>; rel=\"https://rel.example/x\""))
  assert_true(ext.is_clean())
}

///|
test "deprecated rev, unregistered relations and relative anchors are flagged" {
  // The deprecated `rev` parameter survives as an extension parameter and is
  // reported with a stable code and the offending link index.
  let rev = unwrap_ok(audit_link_header("<a>; rel=\"next\"; rev=\"alternate\""))
  assert_true(has_code(rev, "deprecated-rev"))
  assert_true(rev.count_at(Warning) >= 1)
  for issue in rev.issues() {
    if issue.code() == "deprecated-rev" {
      assert_true(issue.link_index() == 0)
    }
  }

  // A relation type in token form that is missing from the IANA snapshot is
  // a likely typo.
  let typo = unwrap_ok(audit_link_header("<a>; rel=\"nxt\""))
  assert_true(has_code(typo, "unregistered-relation"))
  let clean_next = unwrap_ok(audit_link_header("<a>; rel=\"next\""))
  assert_true(has_code(clean_next, "unregistered-relation") == false)

  // A relative anchor leaves the context ambiguous.
  let rel_anchor = unwrap_ok(
    audit_link_header("<a>; rel=\"next\"; anchor=\"/rel\""),
  )
  assert_true(has_code(rel_anchor, "relative-anchor"))
  assert_true(rel_anchor.count_at(Warning) >= 1)

  // Findings reference the right link index when the issue is not on link 0.
  let two = unwrap_ok(
    audit_link_header("<https://e.example/ok>; rel=\"next\", <b>; rel=\"nxt\""),
  )
  let mut found = false
  for issue in two.issues() {
    if issue.code() == "unregistered-relation" {
      found = true
      assert_true(issue.link_index() == 1)
    }
  }
  assert_true(found)
}

///|
test "duplicate links, title+title* and duplicate singletons are reported" {
  // Two links with the same target and relation set are duplicates.
  let dup = unwrap_ok(audit_link_header("<a>; rel=\"next\", <a>; rel=\"next\""))
  assert_true(has_code(dup, "duplicate-link"))
  assert_true(dup.count_at(Warning) >= 1)

  // Coexistence of title and title* is informational.
  let both = unwrap_ok(
    audit_link_header("<a>; rel=\"next\"; title=\"x\"; title*=UTF-8'en'x"),
  )
  assert_true(has_code(both, "title-and-title-star"))
  assert_true(both.count_at(Info) >= 1)

  // A repeated single-occurrence parameter is recorded by the parser and
  // reported as a set-level (link_index -1) finding.
  let sing = unwrap_ok(
    audit_link_header("<a>; rel=\"next\"; title=\"x\"; title=\"y\""),
  )
  assert_true(has_code(sing, "duplicate-singleton"))
  let mut idx = -2
  for issue in sing.issues() {
    if issue.code() == "duplicate-singleton" {
      idx = issue.link_index()
    }
  }
  assert_true(idx == -1)

  // Severity accessors behave.
  assert_true(sing.count_at(Info) >= 1)
  assert_true(sing.has_errors() == false)
}
