// error.mbt — Structured error model for moon-weblink.
//
// RFC 8288 Web Linking / RFC 9264 Linkset processing has many distinct
// failure modes across several processing stages. Public APIs never return
// `Result[T, String]`; they return `Result[T, LinkError]` so callers can
// dispatch on a stable (stage, kind) pair, an optional UTF-8 byte offset,
// and a short context string.
//
// `LinkError` is declared as a `suberror` (MoonBit's raise-based error
// type). Internal processing functions use `raise LinkError` and let errors
// propagate through the call stack without plumbing; every public boundary
// function wraps those internals in `try`/`catch` and converts to
// `Result[T, LinkError]`.
//
// Offsets are UTF-8 byte offsets into the exact input string that was
// passed to the public entry point. The offset is `0` when it is not
// meaningful for the kind of error (for example registry lookups). The
// `context` string is a short, truncated excerpt of the input around the
// failure point; it never echoes the whole (possibly megabytes-long) input.

///|
/// The processing stage in which an error was detected.
pub(all) enum LinkErrorStage {
  Input
  Header
  LinkValue
  Target
  Parameter
  Relation
  QuotedString
  ExtendedValue
  UriReference
  LinksetText
  LinksetJson
  Registry
  Limit
} derive(Eq)

///|
/// The concrete error category. Stable across versions so callers can
/// switch on it without string matching.
pub(all) enum LinkErrorKind {
  EmptyInput
  UnexpectedCharacter
  ExpectedAngleBracket
  UnterminatedTarget
  InvalidTarget
  InvalidToken
  MissingParameterName
  InvalidParameter
  UnterminatedQuotedString
  InvalidQuotedPair
  InvalidRelation
  InvalidExtensionRelation
  InvalidPercentEncoding
  UnsupportedCharset
  InvalidUtf8
  InvalidLanguageTag
  InvalidJson
  InvalidJsonShape
  InvalidLinkset
  DuplicateParameter
  LimitExceeded
  TrailingInput
  InvalidContextValue
  InvalidMediaType
} derive(Eq)

///|
/// A structured error returned by every public API.
///
/// - `stage()` — where the failure happened.
/// - `kind()` — what failed.
/// - `offset()` — UTF-8 byte offset into the input, `0` when not meaningful.
/// - `context()` — short excerpt of the input at the failure point
///   (bounded, never the full input).
pub(all) suberror LinkError {
  LinkError(LinkErrorStage, LinkErrorKind, Int, String)
}

///|
/// Constructs a `LinkError` with the given stage, kind and context and a
/// zero offset.
pub fn link_error(
  stage : LinkErrorStage,
  kind : LinkErrorKind,
  context : String,
) -> LinkError {
  LinkError(stage, kind, 0, context)
}

///|
/// Constructs a `LinkError` carrying an explicit UTF-8 byte offset.
pub fn link_error_at(
  stage : LinkErrorStage,
  kind : LinkErrorKind,
  offset : Int,
  context : String,
) -> LinkError {
  LinkError(stage, kind, offset, context)
}

///|
/// The stage in which this error was detected.
pub fn LinkError::stage(self : LinkError) -> LinkErrorStage {
  match self {
    LinkError(stage, _, _, _) => stage
  }
}

///|
/// The concrete kind of this error.
pub fn LinkError::kind(self : LinkError) -> LinkErrorKind {
  match self {
    LinkError(_, kind, _, _) => kind
  }
}

///|
/// The UTF-8 byte offset into the input where the error was detected,
/// or `0` when the offset is not meaningful for this error kind.
pub fn LinkError::offset(self : LinkError) -> Int {
  match self {
    LinkError(_, _, offset, _) => offset
  }
}

///|
/// A short, bounded excerpt of the input around the failure point.
pub fn LinkError::context(self : LinkError) -> String {
  match self {
    LinkError(_, _, _, context) => context
  }
}

///|
/// A single-line human readable rendering of the error, intended for
/// terminal output and CLI use.
pub fn LinkError::to_display(self : LinkError) -> String {
  let LinkError(stage, kind, offset, context) = self
  "\{stage.to_string()}::\{kind.to_string()} at byte \{offset}: \{context}"
}

///|
/// Stable programmatic name for a stage, used by the CLI JSON output.
pub fn LinkErrorStage::to_string(self : LinkErrorStage) -> String {
  match self {
    Input => "Input"
    Header => "Header"
    LinkValue => "LinkValue"
    Target => "Target"
    Parameter => "Parameter"
    Relation => "Relation"
    QuotedString => "QuotedString"
    ExtendedValue => "ExtendedValue"
    UriReference => "UriReference"
    LinksetText => "LinksetText"
    LinksetJson => "LinksetJson"
    Registry => "Registry"
    Limit => "Limit"
  }
}

///|
/// Stable programmatic name for a kind, used by the CLI JSON output.
pub fn LinkErrorKind::to_string(self : LinkErrorKind) -> String {
  match self {
    EmptyInput => "EmptyInput"
    UnexpectedCharacter => "UnexpectedCharacter"
    ExpectedAngleBracket => "ExpectedAngleBracket"
    UnterminatedTarget => "UnterminatedTarget"
    InvalidTarget => "InvalidTarget"
    InvalidToken => "InvalidToken"
    MissingParameterName => "MissingParameterName"
    InvalidParameter => "InvalidParameter"
    UnterminatedQuotedString => "UnterminatedQuotedString"
    InvalidQuotedPair => "InvalidQuotedPair"
    InvalidRelation => "InvalidRelation"
    InvalidExtensionRelation => "InvalidExtensionRelation"
    InvalidPercentEncoding => "InvalidPercentEncoding"
    UnsupportedCharset => "UnsupportedCharset"
    InvalidUtf8 => "InvalidUtf8"
    InvalidLanguageTag => "InvalidLanguageTag"
    InvalidJson => "InvalidJson"
    InvalidJsonShape => "InvalidJsonShape"
    InvalidLinkset => "InvalidLinkset"
    DuplicateParameter => "DuplicateParameter"
    LimitExceeded => "LimitExceeded"
    TrailingInput => "TrailingInput"
    InvalidContextValue => "InvalidContextValue"
    InvalidMediaType => "InvalidMediaType"
  }
}

///|
/// Maximum length of the context excerpt stored inside an error. Longer
/// inputs are truncated so that errors never carry megabytes of input.
pub fn max_context_bytes() -> Int {
  80
}

///|
/// Downcasts the abstract `Error` caught in a `catch` clause back to the
/// `LinkError` suberror. Every function in this package raises `LinkError`
/// exclusively, so any other suberror reaching this boundary is a bug and is
/// reported loudly rather than silently lost.
fn unwrap_link_error(e : Error) -> LinkError {
  match e {
    LinkError(stage, kind, offset, context) =>
      LinkError(stage, kind, offset, context)
    _ =>
      abort(
        "internal error: unexpected non-LinkError propagated to a Result boundary",
      )
  }
}
