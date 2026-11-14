#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir="${TMPDIR:-/tmp}/pokopeeko-music-checks"
mkdir -p "$test_dir"
xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
  -module-cache-path "$test_dir/module-cache" \
  PokoPeeko/PokoPeeko/Features/Music/MusicPlayback.swift \
  PokoPeeko/PokoPeeko/Features/Music/DTOs/MusicStatusUpdateDTO.swift \
  PokoPeeko/PokoPeeko/Features/Music/MusicPlayerReader.swift \
  PokoPeeko/PokoPeeko/Features/Music/MusicViewModel.swift \
  Tests/MusicChecks.swift -o "$test_dir/checks"
"$test_dir/checks"
