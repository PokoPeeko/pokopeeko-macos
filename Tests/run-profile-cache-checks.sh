#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_output_dir="${TMPDIR:-/tmp}/pokopeeko-profile-cache-checks"
mkdir -p "$test_output_dir"
xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
  -module-cache-path "$test_output_dir/module-cache" \
  PokoPeeko/PokoPeeko/Features/Profile/ProfileSnapshotCache.swift \
  PokoPeeko/PokoPeeko/Shared/Components/ProfileImageCache.swift \
  PokoPeeko/PokoPeeko/Shared/Models/UserProfile.swift \
  PokoPeeko/PokoPeeko/Shared/Networking/APIConfig.swift \
  Tests/ProfileCacheChecks.swift -o "$test_output_dir/checks"
"$test_output_dir/checks"
