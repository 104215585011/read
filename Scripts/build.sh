#!/usr/bin/env bash
set -euo pipefail

echo "=== Building StudyOS (Swift Package) ==="
swift build -v

echo "=== Running Tests ==="
swift test -v

echo "=== Build and Test Completed Successfully ==="
