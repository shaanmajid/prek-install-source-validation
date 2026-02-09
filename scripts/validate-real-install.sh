#!/usr/bin/env bash
set -euo pipefail

DIST_DIR="${1:?Usage: $0 <dist-directory>}"
DIST_DIR="$(realpath "$DIST_DIR")"
WHEEL=$(ls "$DIST_DIR"/*.whl | head -1)

if [ -z "$WHEEL" ]; then
    echo "ERROR: No .whl file found in $DIST_DIR"
    exit 1
fi

echo "Using wheel: $WHEEL"

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

# --- uv tool ---
echo ""
echo "=== Testing uv tool install ==="
uv tool install --force "$WHEEL"

# Find the installed binary
UV_PREK=""
for candidate in \
    "$HOME/.local/share/uv/tools/prek/bin/prek" \
    "$HOME/.local/bin/prek"; do
    if [ -x "$candidate" ]; then
        # Resolve symlinks to get the real path
        real=$(realpath "$candidate")
        if echo "$real" | grep -q "uv/tools/prek"; then
            UV_PREK="$real"
            break
        fi
    fi
done

if [ -z "$UV_PREK" ]; then
    echo "FAIL [uv tool]: could not locate installed binary"
    FAIL=$((FAIL + 1))
else
    echo "Found uv tool binary at: $UV_PREK"
    assert_output "uv tool" "$UV_PREK" "installed via uv tool" "uv tool upgrade prek"
fi

uv tool uninstall prek || true

# --- pipx ---
echo ""
echo "=== Testing pipx install ==="
pipx install --force "$WHEEL"

# Find the installed binary via pipx's own environment info
PIPX_VENVS=$(pipx environment --value PIPX_LOCAL_VENVS 2>/dev/null || echo "")
PIPX_PREK=""

if [ -n "$PIPX_VENVS" ] && [ -x "$PIPX_VENVS/prek/bin/prek" ]; then
    PIPX_PREK="$PIPX_VENVS/prek/bin/prek"
else
    # Fallback: resolve the symlink from ~/.local/bin/prek
    if command -v prek &>/dev/null; then
        real=$(realpath "$(command -v prek)")
        if echo "$real" | grep -q "pipx/venvs/prek"; then
            PIPX_PREK="$real"
        fi
    fi
fi

if [ -z "$PIPX_PREK" ]; then
    echo "FAIL [pipx]: could not locate installed binary"
    echo "  PIPX_LOCAL_VENVS=$PIPX_VENVS"
    echo "  which prek=$(command -v prek 2>/dev/null || echo 'not found')"
    FAIL=$((FAIL + 1))
else
    echo "Found pipx binary at: $PIPX_PREK"
    assert_output "pipx" "$PIPX_PREK" "installed via pipx" "pipx upgrade prek"
fi

pipx uninstall prek || true

# --- Summary ---
echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
