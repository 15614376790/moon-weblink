# verify_all.ps1 - End-to-end verification of moon-weblink.
#
# Runs, in order:
#   1.  moon fmt --check
#   2.  moon info
#   3.  moon check / build / test for wasm, wasm-gc, js and native
#   4.  CLI smoke tests on every target, plus content assertions
#   5.  every example program
#   6.  scripts/count_code.py          (line budgets, named-test count)
#   7.  scripts/verify_iana_snapshot.py (offline IANA snapshot integrity)
#   8.  moon package --list
#
# Prints one PASS/FAIL line per step and exits non-zero if any step failed.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\verify_all.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\verify_all.ps1 -MoonBin D:\Moonbit\bin\moon.exe
#   powershell -ExecutionPolicy Bypass -File scripts\verify_all.ps1 -TargetDir D:\temp\moon-weblink-build
#
# The moon binary is resolved in this order: -MoonBin > $env:MOON_BIN > PATH
# > D:\Moonbit\bin\moon.exe.

param(
    [string]$MoonBin = "",
    [string]$TargetDir = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

if ($MoonBin -eq "") {
    # Resolution order: -MoonBin (explicit) > $env:MOON_BIN > PATH > known
    # install location.
    if ($env:MOON_BIN -and (Test-Path $env:MOON_BIN)) {
        $MoonBin = $env:MOON_BIN
    } else {
        $candidate = Get-Command moon -ErrorAction SilentlyContinue
        if ($candidate) {
            $MoonBin = $candidate.Source
        } elseif (Test-Path "D:\Moonbit\bin\moon.exe") {
            $MoonBin = "D:\Moonbit\bin\moon.exe"
        } else {
            Write-Host "FAIL: could not locate the moon binary (pass -MoonBin or set MOON_BIN)."
            exit 1
        }
    }
}
Write-Host "moon: $MoonBin"
$TargetArgs = @()
if ($TargetDir -ne "") {
    $TargetArgs = @("--target-dir", $TargetDir)
    Write-Host "target dir: $TargetDir"
}

$failures = @()
$steps = 0

function Step([string]$Name, [scriptblock]$Body) {
    $script:steps++
    try {
        & $Body
        if ($LASTEXITCODE -eq 0) {
            Write-Host "PASS  $Name"
        } else {
            Write-Host "FAIL  $Name (exit $LASTEXITCODE)"
            $script:failures += $Name
        }
    } catch {
        Write-Host "FAIL  $Name ($_)"
        $script:failures += $Name
    }
}

Write-Host "--- formatting ---"
Step "moon fmt --check" { & $MoonBin fmt @TargetArgs --check }
Step "moon info" { & $MoonBin info @TargetArgs }

Write-Host "--- check / build / test across targets ---"
foreach ($t in @("wasm", "wasm-gc", "js", "native")) {
    Step "moon check --target $t --deny-warn" { & $MoonBin check @TargetArgs --target $t --deny-warn }
    Step "moon build --target $t"   { & $MoonBin build @TargetArgs --target $t }
    Step "moon test --target $t --deny-warn" { & $MoonBin test @TargetArgs --target $t --deny-warn }
}

Write-Host "--- CLI smoke tests (per target) ---"
foreach ($t in @("wasm", "wasm-gc", "js", "native")) {
    Step "cli [$t]: version" {
        $out = & $MoonBin run @TargetArgs --target $t cmd/weblink-tool -- version
        $out | Out-Host
        if (-not ($out -match "weblink-tool 0\.1\.1 \(15614376790/moon-weblink\)")) {
            throw "expected the version banner"
        }
    }
    Step "cli [$t]: parse a Link header" {
        $out = & $MoonBin run @TargetArgs --target $t cmd/weblink-tool -- parse --input '<https://a.example/>; rel="next"'
        $out | Out-Host
        if (-not ($out -match "next")) { throw "expected the next relation in the parse output" }
    }
    Step "cli [$t]: canonicalize with mixed-case parameter names" {
        $out = & $MoonBin run @TargetArgs --target $t cmd/weblink-tool -- canonicalize --input '<https://a.example/>; REL="canonical"'
        $out | Out-Host
        if (-not ($out -match 'rel="canonical"')) { throw "expected the canonical form" }
    }
    Step "cli [$t]: relation registry lookup" {
        $out = & $MoonBin run @TargetArgs --target $t cmd/weblink-tool -- relation next
        $out | Out-Host
        if (-not ($out -match "next")) { throw "expected the next registry entry" }
    }
}

Write-Host "--- CLI content assertions (default target) ---"
Step "cli: stats" {
    & $MoonBin run @TargetArgs cmd/weblink-tool -- stats | Out-Host
}
Step "cli: validate a malformed value reports invalid" {
    $out = & $MoonBin run @TargetArgs cmd/weblink-tool -- validate --input 'not a link'
    $out | Out-Host
    if (-not ($out -match "valid: false")) { throw "expected 'valid: false'" }
}
Step "cli: audit flags the deprecated rev parameter" {
    $out = & $MoonBin run @TargetArgs cmd/weblink-tool -- audit --input '<https://a.example/>; rel="canonical"; rev="made"'
    $out | Out-Host
    if (-not ($out -match "deprecated-rev")) { throw "expected a deprecated-rev finding" }
}
Step "cli: to-linkset-json emits an RFC 9264 linkset" {
    # Windows PowerShell 5.1 cannot pass embedded double quotes through a
    # native-command argument (CommandLineToArgvW mangling), so JSON cannot
    # travel via `moon run` argv. This step keeps argv quote-free; the
    # header <-> JSON round-trip is exercised in-process by the linkset_json
    # example below and by the test suite.
    $out = & $MoonBin run @TargetArgs cmd/weblink-tool -- to-linkset-json --input '<a>; rel=next'
    $out | Out-Host
    if (-not ($out -match '"linkset"')) { throw "expected a linkset JSON document" }
    if (-not ($out -match '"next"')) { throw "expected the next relation member" }
}

Write-Host "--- examples ---"
foreach ($ex in @("parse_header", "pagination", "linkset_json", "relation_query", "audit_header")) {
    Step "example: $ex" { & $MoonBin run @TargetArgs examples/$ex | Out-Host }
}
Step "example: linkset_json round-trips header -> JSON -> header" {
    $out = & $MoonBin run @TargetArgs examples/linkset_json
    $out | Out-Host
    if (-not ($out -match '"linkset"')) { throw "example did not emit linkset JSON" }
    if (-not ($out -match 'back to a Link header:')) { throw "example did not convert back" }
    if (-not ($out -match 'rel="stylesheet"')) { throw "round-trip lost the stylesheet relation" }
}

Write-Host "--- repository checks ---"
Step "python scripts/count_code.py" {
    & python scripts/count_code.py
}
Step "python scripts/verify_iana_snapshot.py" {
    & python scripts/verify_iana_snapshot.py
}
Step "moon package --list" {
    & $MoonBin package @TargetArgs --list
}

Write-Host ""
Write-Host "ran $steps verification steps"
if ($failures.Count -gt 0) {
    Write-Host "FAILED: $($failures.Count) step(s):"
    $failures | ForEach-Object { Write-Host "  - $_" }
    exit 1
}
Write-Host "ALL CHECKS PASSED"
exit 0
