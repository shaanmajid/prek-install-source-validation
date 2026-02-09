#!/usr/bin/env bash
set -euo pipefail

BINARY="${1:?Usage: $0 <path-to-prek-binary>}"
BINARY="$(realpath "$BINARY")"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

PASS=0
FAIL=0

assert_output() {
    local label="$1" exe="$2" expected_desc="$3" expected_cmd="$4"
    local output

    output=$("$exe" self update --color never 2>&1) && {
        echo "FAIL [$label]: expected non-zero exit code"
        FAIL=$((FAIL + 1))
        return
    }

    if ! echo "$output" | grep -qF "$expected_desc"; then
        echo "FAIL [$label]: expected description '$expected_desc' not found in output:"
        echo "  $output"
        FAIL=$((FAIL + 1))
        return
    fi

    if ! echo "$output" | grep -qF "$expected_cmd"; then
        echo "FAIL [$label]: expected command '$expected_cmd' not found in output:"
        echo "  $output"
        FAIL=$((FAIL + 1))
        return
    fi

    echo "PASS [$label]"
    PASS=$((PASS + 1))
}

assert_unknown() {
    local label="$1" exe="$2"
    local output

    output=$("$exe" self update --color never 2>&1) && {
        echo "FAIL [$label]: expected non-zero exit code"
        FAIL=$((FAIL + 1))
        return
    }

    if ! echo "$output" | grep -qF "external package manager"; then
        echo "FAIL [$label]: expected 'external package manager' not found in output:"
        echo "  $output"
        FAIL=$((FAIL + 1))
        return
    fi

    echo "PASS [$label]"
    PASS=$((PASS + 1))
}

place_binary() {
    local dir="$1"
    mkdir -p "$dir"
    cp "$BINARY" "$dir/prek"
    chmod +x "$dir/prek"
    echo "$dir/prek"
}

# --- Homebrew (ARM) ---
exe=$(place_binary "$TMPDIR/opt/homebrew/Cellar/prek/0.3.2/bin")
assert_output "Homebrew (ARM)" "$exe" "installed via Homebrew" "brew update && brew upgrade prek"

# --- Homebrew (Intel) ---
exe=$(place_binary "$TMPDIR/usr/local/Cellar/prek/0.3.2/bin")
assert_output "Homebrew (Intel)" "$exe" "installed via Homebrew" "brew update && brew upgrade prek"

# --- uv tool ---
exe=$(place_binary "$TMPDIR/home/user/.local/share/uv/tools/prek/bin")
assert_output "uv tool" "$exe" "installed via uv tool" "uv tool upgrade prek"

# --- pipx ---
exe=$(place_binary "$TMPDIR/home/user/.local/share/pipx/venvs/prek/bin")
assert_output "pipx" "$exe" "installed via pipx" "pipx upgrade prek"

# --- asdf ---
exe=$(place_binary "$TMPDIR/home/user/.asdf/installs/prek/0.3.2/bin")
assert_output "asdf" "$exe" "installed via asdf" "asdf install prek latest"

# --- mise ---
exe=$(place_binary "$TMPDIR/home/user/.local/share/mise/installs/prek/0.3.2/bin")
assert_output "mise" "$exe" "installed via mise" "mise upgrade prek"

# --- Unknown ---
exe=$(place_binary "$TMPDIR/usr/local/bin")
assert_unknown "Unknown fallback" "$exe"

# --- Summary ---
echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
