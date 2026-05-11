#!/bin/bash
# Mac CI build wrapper for CCExtractor.
# Invoked from a GitHub Actions workflow (macos-latest or self-hosted).
# Delegates to CCExtractor's own mac/build.command so we don't drift from
# the canonical build recipe maintained by the CCExtractor team.
#
# Usage (from workflow):
#   CCX_REPO=$GITHUB_WORKSPACE BUILD_FLAVOR=ocr ./build.sh
#
# Environment:
#   CCX_REPO      — path to checked-out CCExtractor repo (default: $GITHUB_WORKSPACE)
#   BUILD_FLAVOR  — one of: baseline | ocr | hardsubx | debug (default: baseline)
#                   "debug" sets -g for WP1 debug-symbols requirement.
#   ARTIFACT_DIR  — where to copy the resulting binary (default: ./artifact)

set -euo pipefail

CCX_REPO="${CCX_REPO:-${GITHUB_WORKSPACE:-}}"
BUILD_FLAVOR="${BUILD_FLAVOR:-baseline}"
ARTIFACT_DIR="${ARTIFACT_DIR:-./artifact}"

if [ -z "$CCX_REPO" ] || [ ! -d "$CCX_REPO/mac" ]; then
    echo "ERROR: CCX_REPO must point to a CCExtractor checkout with a mac/ subdir" >&2
    echo "       got: '${CCX_REPO}'" >&2
    exit 1
fi

case "$BUILD_FLAVOR" in
    baseline) FLAGS=() ;;
    ocr)      FLAGS=(OCR) ;;
    hardsubx) FLAGS=(OCR -hardsubx) ;;
    debug)    FLAGS=(-debug) ;;
    *) echo "ERROR: unknown BUILD_FLAVOR '${BUILD_FLAVOR}'" >&2; exit 1 ;;
esac

echo "==> Build flavor: ${BUILD_FLAVOR} (flags: ${FLAGS[*]:-none})"
echo "==> CCExtractor repo: ${CCX_REPO}"

cd "$CCX_REPO/mac"
./build.command "${FLAGS[@]}"

if [ ! -x ./ccextractor ]; then
    echo "ERROR: build.command finished but ./ccextractor is missing or not executable" >&2
    exit 1
fi

echo "==> Build artifact:"
./ccextractor --version | head -5

mkdir -p "$ARTIFACT_DIR"
cp ./ccextractor "$ARTIFACT_DIR/"
echo "==> Copied to ${ARTIFACT_DIR}/ccextractor"
