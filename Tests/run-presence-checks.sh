#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Pass the Debug products directory from a successful Xcode build.
products_dir="${1:?Supply the Xcode Debug products directory}"
test_dir="${TMPDIR:-/tmp}/pokopeeko-presence-checks"
mkdir -p "$test_dir"
xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
  -I "$products_dir" -framework Security -framework SystemConfiguration -framework Network -lz \
  "$products_dir/SocketIO.o" "$products_dir/Starscream.o" \
  PokoPeeko/PokoPeeko/Features/Music/MusicPlayback.swift \
  PokoPeeko/PokoPeeko/Features/Music/DTOs/MusicStatusUpdateDTO.swift \
  PokoPeeko/PokoPeeko/Features/Presence/PresenceService.swift \
  PokoPeeko/PokoPeeko/Features/Presence/PresenceStore.swift \
  PokoPeeko/PokoPeeko/Shared/Models/DetectedApp.swift \
  PokoPeeko/PokoPeeko/Shared/Models/Friend.swift \
  PokoPeeko/PokoPeeko/Shared/Networking/APIConfig.swift \
  Tests/PresenceChecks.swift -o "$test_dir/checks"
python3 Tests/presence_protocol_server.py "$test_dir/checks"
