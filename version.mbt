// version.mbt — single source of truth for the library version string.

///|
/// The released library version. `moon.mod` mirrors this value; the CLI and
/// any consumer that prints a version should use this function instead of
/// hard-coding the string.
pub fn library_version() -> String {
  "0.1.1"
}
