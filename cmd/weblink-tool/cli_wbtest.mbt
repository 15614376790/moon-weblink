// cli_wbtest.mbt — whitebox tests for argv normalization in the CLI package.

///|
/// Expects `split_command` to yield the given command and option list.
fn expect_split(args : Array[String], cmd : String, rest : Array[String]) -> Unit raise {
  let (actual_cmd, actual_rest) = split_command(args)
  assert_true(actual_cmd == cmd, msg="expected command \{cmd}, got \{actual_cmd}")
  assert_true(
    actual_rest.length() == rest.length(),
    msg="expected \{rest.length().to_string()} options, got \{actual_rest.length().to_string()}",
  )
  for i = 0; i < rest.length(); i = i + 1 {
    assert_true(actual_rest[i] == rest[i], msg="option \{i.to_string()} mismatch")
  }
}

///|
test "cli argv: native-style prefix" {
  expect_split(["C:\\bin\\weblink-tool.exe", "stats"], "stats", Array::new())
}

///|
test "cli argv: js-style prefix" {
  expect_split(
    ["C:\\node.exe", "D:\\proj\\weblink-tool.js", "parse", "--input", "<a>; rel=next"],
    "parse",
    ["--input", "<a>; rel=next"],
  )
}

///|
test "cli argv: wasm-style prefix" {
  expect_split(["D:\\proj\\weblink-tool.wasm", "version"], "version", Array::new())
}

///|
test "cli argv: already-normalized" {
  expect_split(["canonicalize", "--input", "x"], "canonicalize", ["--input", "x"])
}

///|
test "cli argv: bare engine name prefix" {
  expect_split(["node", "stats"], "stats", Array::new())
}

///|
test "cli argv: program prefix without command falls back to help" {
  expect_split(["D:\\proj\\weblink-tool.exe"], "help", Array::new())
}

///|
test "cli argv: engine name as a positional is preserved" {
  expect_split(["query", "node"], "query", ["node"])
}
