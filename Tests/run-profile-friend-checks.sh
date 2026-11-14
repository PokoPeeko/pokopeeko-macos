#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_output_dir="${TMPDIR:-/tmp}/pokopeeko-profile-friend-checks"
mkdir -p "$test_output_dir"
xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
  -module-cache-path "$test_output_dir/module-cache" \
  PokoPeeko/PokoPeeko/App/AppState.swift \
  PokoPeeko/PokoPeeko/Features/Profile/ProfileService.swift \
  PokoPeeko/PokoPeeko/Features/Profile/FriendProfileViewModel.swift \
  PokoPeeko/PokoPeeko/Features/Profile/ProfileSnapshotCache.swift \
  PokoPeeko/PokoPeeko/Features/Profile/DTOs/*.swift \
  PokoPeeko/PokoPeeko/Features/Friends/FriendService.swift \
  PokoPeeko/PokoPeeko/Features/Friends/FriendRequest.swift \
  PokoPeeko/PokoPeeko/Features/Friends/FriendsViewModel.swift \
  PokoPeeko/PokoPeeko/Features/Friends/DTOs/*.swift \
  PokoPeeko/PokoPeeko/Shared/Models/UserProfile.swift \
  PokoPeeko/PokoPeeko/Shared/Models/Friend.swift \
  PokoPeeko/PokoPeeko/Shared/Session/*.swift \
  PokoPeeko/PokoPeeko/Shared/Networking/APIConfig.swift \
  PokoPeeko/PokoPeeko/Shared/Networking/SessionAPIClient.swift \
  PokoPeeko/PokoPeeko/Shared/Networking/DTOs/ErrorResponseDTO.swift \
  Tests/ProfileFriendChecks.swift -o "$test_output_dir/checks"
"$test_output_dir/checks"
