#!/bin/bash
# SPDX-FileCopyrightText: 2024-2025 IHP-EDA-Tools Contributors
# SPDX-License-Identifier: Apache-2.0
#
# LibreLane RTL-to-GDS Test Suite for IHP-SG13G2
#
# This test suite uses librelane-nix for reproducible nix-eda tool versions.
# Can run inside IHP-EDA-Tools container or locally with nix.
#
# Usage:
#   ./run_tests.sh [design1] [design2] ...
#   ./run_tests.sh              # runs IHP-ready designs
#   ./run_tests.sh inverter     # runs only inverter
#   ./run_tests.sh all          # attempts all designs

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Output directories
if [ -z "${RAND:-}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom 2>/dev/null || echo "test$$")
fi
RUNS_DIR="${RUNS_DIR:-$SCRIPT_DIR/runs/$RAND}"

# PDK settings
PDK="${PDK:-ihp-sg13g2}"
STD_CELL_LIBRARY="${STD_CELL_LIBRARY:-sg13g2_stdcell}"

# Detect PDK_ROOT - environment, container, or ciel
if [ -n "${PDK_ROOT:-}" ]; then
    echo "[INFO] PDK_ROOT from environment: $PDK_ROOT"
elif [ -d "/foss/pdks/ihp-sg13g2" ]; then
    PDK_ROOT="/foss/pdks"
    echo "[INFO] Using container PDK: $PDK_ROOT"
else
    echo "[INFO] PDK_ROOT not set - will use ciel (nix-eda)"
fi

# LibreLane command - prefer librelane-nix for reproducibility
if command -v librelane-nix >/dev/null 2>&1; then
    LIBRELANE_CMD="${LIBRELANE_CMD:-librelane-nix}"
elif command -v librelane >/dev/null 2>&1; then
    LIBRELANE_CMD="${LIBRELANE_CMD:-librelane}"
else
    echo "[ERROR] Neither librelane-nix nor librelane found in PATH"
    echo "[INFO] Run inside IHP-EDA-Tools container or use 'nix develop'"
    exit 1
fi

echo "[INFO] Using: $LIBRELANE_CMD"

# IHP-compatible designs (have pdk::ihp-sg13g2* section or explicit PDN vars)
IHP_READY_DESIGNS="inverter user_proj_timer y_huff BM64"

# All designs available
ALL_DESIGNS="inverter usb APU user_proj_timer usb_cdc_core y_huff BM64 picorv32a"

# Determine which designs to run
if [ $# -gt 0 ]; then
    if [ "$1" = "all" ]; then
        DESIGNS="$ALL_DESIGNS"
    else
        DESIGNS="$*"
    fi
else
    DESIGNS="$IHP_READY_DESIGNS"
    echo "[INFO] Running IHP-ready designs only: $IHP_READY_DESIGNS"
    echo "[INFO] Use './run_tests.sh all' to attempt all designs"
fi

# Create runs directory
mkdir -p "$RUNS_DIR"

# Results tracking
PASSED=0
FAILED=0
SKIPPED=0
declare -a FAILED_DESIGNS=()

# Run each design
for design in $DESIGNS; do
    design_dir="$SCRIPT_DIR/designs/$design"

    if [ ! -d "$design_dir" ]; then
        echo "[WARN] Design directory not found: $design"
        ((SKIPPED++))
        continue
    fi

    if [ ! -f "$design_dir/config.json" ]; then
        echo "[WARN] config.json not found for $design"
        ((SKIPPED++))
        continue
    fi

    echo ""
    echo "============================================="
    echo "Running LibreLane for: $design"
    echo "============================================="

    # Create work directory
    work_dir="$RUNS_DIR/$design"
    mkdir -p "$work_dir"

    # Copy design files to work directory
    cp "$design_dir/config.json" "$work_dir/"
    [ -d "$design_dir/src" ] && cp -r "$design_dir/src" "$work_dir/"
    cp "$design_dir"/*.v "$work_dir/" 2>/dev/null || true
    cp "$design_dir"/*.cfg "$work_dir/" 2>/dev/null || true

    # Run LibreLane
    log_file="$work_dir/librelane.log"

    # Build command with optional PDK_ROOT
    LIBRELANE_ARGS=(
        --pdk "$PDK"
        --scl "$STD_CELL_LIBRARY"
        --condensed
    )

    # Use --manual-pdk when PDK_ROOT is provided (bypasses ciel)
    if [ -n "${PDK_ROOT:-}" ]; then
        LIBRELANE_ARGS+=(--manual-pdk --pdk-root "$PDK_ROOT")
        echo "[INFO] Using manual PDK: $PDK_ROOT"
    fi

    if $LIBRELANE_CMD "${LIBRELANE_ARGS[@]}" "$work_dir/config.json" > "$log_file" 2>&1; then
        echo "[PASS] $design completed successfully"
        ((PASSED++))

        # Show GDS file if created
        if [ -d "$work_dir/runs" ]; then
            gds_file=$(find "$work_dir/runs" -name "*.gds" -type f 2>/dev/null | head -1)
            if [ -n "$gds_file" ]; then
                echo "       GDS: $gds_file"
            fi
        fi
    else
        echo "[FAIL] $design failed - check $log_file"
        ((FAILED++))
        FAILED_DESIGNS+=("$design")

        # Show last few error lines
        if [ -f "$log_file" ]; then
            echo "       Last errors:"
            grep -i "error" "$log_file" | tail -5 | sed 's/^/       /' || true
        fi
    fi
done

# Summary
echo ""
echo "============================================="
echo "LibreLane Test Suite Summary"
echo "============================================="
echo "Passed:  $PASSED"
echo "Failed:  $FAILED"
echo "Skipped: $SKIPPED"

if [ ${#FAILED_DESIGNS[@]} -gt 0 ]; then
    echo ""
    echo "Failed designs:"
    for d in "${FAILED_DESIGNS[@]}"; do
        echo "  - $d"
    done
fi

echo ""
echo "Run logs: $RUNS_DIR"

# Exit with error if any failed
[ $FAILED -eq 0 ]
