// test_registry.mbt — Tests for the offline IANA Link Relation Types
// registry snapshot (relation_registry.mbt).

///|
test "the offline registry snapshot is populated and lookup is case-insensitive" {
  // The snapshot holds a substantial number of relation types.
  let count = registered_relation_count()
  assert_true(count >= 60)

  // Well-known registered relations are present.
  assert_true(is_registered_relation("next"))
  assert_true(is_registered_relation("self"))
  assert_true(is_registered_relation("alternate"))
  assert_true(is_registered_relation("canonical"))
  assert_true(is_registered_relation("prev"))
  assert_true(is_registered_relation("stylesheet"))
  assert_true(is_registered_relation("icon"))
  assert_true(is_registered_relation("manifest"))
  assert_true(is_registered_relation("preconnect"))

  // Matching is case-insensitive per RFC 8288 Section 2.1.1.
  assert_true(is_registered_relation("NEXT"))
  assert_true(is_registered_relation("Canonical"))

  // Unknown names, empty strings and extension URIs are not registered.
  assert_true(is_registered_relation("nxt") == false)
  assert_true(is_registered_relation("") == false)
  assert_true(is_registered_relation("https://rel.example/x") == false)

  // relation_info returns the canonical entry, or None for unknown names.
  match relation_info("canonical") {
    Some(info) => {
      assert_str_eq(info.name(), "canonical")
      assert_true(info.description().length() > 0)
      assert_true(info.reference().length() > 0)
    }
    None => fail("canonical should be present")
  }
  assert_true(relation_info("not-a-real-rel") is None)

  // registered_relations() is a fresh, complete copy in registry order.
  let all = registered_relations()
  assert_true(all.length() == count)
  for i = 1; i < all.length(); i = i + 1 {
    assert_true(all[i - 1].name() <= all[i].name())
  }

  // Mutating the returned copy does not affect later calls.
  all[0] = { name: "zzz", description: "", reference: "", notes: "" }
  assert_true(is_registered_relation(all[0].name()) == false)
  assert_true(registered_relations().length() == count)
}
