// relation_registry.mbt — Offline IANA Link Relation Types registry access.
//
// The registry data lives in generated_relations.mbt, which is produced at
// development time by scripts/import_iana_relations.py from the offline
// snapshot testdata/iana/link-relations.csv. Nothing in this module touches
// the network at runtime; `audit.mbt` uses `is_registered_relation` to tell
// a registered relation type from an extension relation type (an absolute
// URI) without ever fetching anything.
//
// Per RFC 8288 Section 2.1.1, registered relation types are compared
// case-insensitively (the registry table itself is lowercase).

///|
/// One entry of the IANA Link Relation Types registry.
pub struct RelationInfo {
  name : String
  description : String
  reference : String
  notes : String
}

///|
/// The relation type name (always lowercase in the registry).
pub fn RelationInfo::name(self : RelationInfo) -> String {
  self.name
}

///|
/// The registered description of the relation type.
pub fn RelationInfo::description(self : RelationInfo) -> String {
  self.description
}

///|
/// The IANA-recorded reference (an RFC, a specification, or a URI).
pub fn RelationInfo::reference(self : RelationInfo) -> String {
  self.reference
}

///|
/// Additional IANA notes, if any (the empty string when absent).
pub fn RelationInfo::notes(self : RelationInfo) -> String {
  self.notes
}

///|
/// Whether `name` is a registered IANA relation type. Matching is
/// case-insensitive, per RFC 8288 Section 2.1.1.
pub fn is_registered_relation(name : String) -> Bool {
  for entry in generated_relation_data() {
    if entry.name.equal_ignore_ascii_case(name) {
      return true
    }
  }
  false
}

///|
/// The registry entry for `name`, or `None` when no such relation type is
/// registered. Matching is case-insensitive. The first (alphabetically
/// earliest) match is returned, which is the canonical entry.
pub fn relation_info(name : String) -> RelationInfo? {
  for entry in generated_relation_data() {
    if entry.name.equal_ignore_ascii_case(name) {
      return Some(entry)
    }
  }
  None
}

///|
/// A fresh copy of every registry entry, sorted by relation type name
/// (alphabetical, case-sensitive). The returned array is a copy: mutating it
/// never affects later calls.
pub fn registered_relations() -> Array[RelationInfo] {
  let out = Array::new()
  for entry in generated_relation_data() {
    out.push(entry)
  }
  out.sort_by(fn(a, b) {
    if a.name() < b.name() {
      -1
    } else if a.name() > b.name() {
      1
    } else {
      0
    }
  })
  out
}

///|
/// The number of relation types in the offline snapshot.
pub fn registered_relation_count() -> Int {
  generated_relation_data().length()
}
