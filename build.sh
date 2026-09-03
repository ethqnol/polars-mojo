#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

LIB_STATIC="target/release/libpolars_ffi.a"
BIN_DIR="bin"
mkdir -p "$BIN_DIR"

build_rust() {
    cargo build --release
}

if [ ! -f "$LIB_STATIC" ]; then
    build_rust
fi

if [ $# -eq 0 ]; then
    echo "usage: $0 <path/to/file.mojo> [--run] [args...]"
    echo "       $0 --rust-build"
    exit 0
fi

if [ "$1" == "--rust-build" ] || [ "$1" == "--rust" ]; then
    build_rust
    exit 0
fi

SRC_FILE="$1"
shift

RUN_AFTER=0
EXTRA_ARGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --run)
            RUN_AFTER=1
            shift
            ;;
        --rebuild-rust)
            build_rust
            shift
            ;;
        *)
            EXTRA_ARGS+=("$1")
            shift
            ;;
    esac
done

BASENAME=$(basename "$SRC_FILE" .mojo)
OUTPUT_BIN="$BIN_DIR/$BASENAME"

mojo build -I "$SCRIPT_DIR" \
    -Xlinker "$SCRIPT_DIR/$LIB_STATIC" \
    -Xlinker -lpthread \
    -Xlinker -ldl \
    -Xlinker -lm \
    -o "$OUTPUT_BIN" \
    "$SRC_FILE"

if [ $RUN_AFTER -eq 1 ]; then
    "$OUTPUT_BIN" ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
fi
