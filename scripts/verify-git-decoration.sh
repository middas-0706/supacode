#!/usr/bin/env bash
# Run the real model's Swift Testing suite and an optimized microbenchmark,
# without the app's Ghostty/Tuist dependencies. Optional argument: baseline ref.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
verification_dir="$(mktemp -d "${TMPDIR:-/tmp}/supacode-git-decoration.XXXXXX")"
trap 'rm -rf "$verification_dir"' EXIT
mkdir -p "$verification_dir/Sources/supacode" "$verification_dir/Tests/supacodeTests"
source_path="supacode/Features/FileExplorer/Models/GitFileStatus.swift"
model_path="$verification_dir/Sources/supacode/GitFileStatus.swift"
if [ "$#" -gt 1 ]; then
  echo "usage: scripts/verify-git-decoration.sh [baseline-git-ref]" >&2
  exit 2
elif [ "$#" -eq 1 ]; then
  git show "$1:$source_path" > "$model_path"
else
  cp "$source_path" "$model_path"
fi
cp supacodeTests/GitStatusParserTests.swift "$verification_dir/Tests/supacodeTests/"
cat > "$verification_dir/Package.swift" <<'EOF'
// swift-tools-version: 6.2
import PackageDescription
let package = Package(
  name: "GitDecorationVerification",
  platforms: [.macOS(.v26)],
  targets: [
    .target(name: "supacode"),
    .testTarget(name: "supacodeTests", dependencies: ["supacode"]),
  ]
)
EOF
xcrun swift test --package-path "$verification_dir"
xcrun swiftc -O "$model_path" scripts/benchmarks/GitDecorationBenchmark.swift \
  -o "$verification_dir/benchmark"
# Stable Set iteration makes baseline runs comparable; never enabled in the app.
SWIFT_DETERMINISTIC_HASHING=1 "$verification_dir/benchmark"
