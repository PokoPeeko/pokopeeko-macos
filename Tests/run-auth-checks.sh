#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_output_dir="${TMPDIR:-/tmp}/pokopeeko-auth-checks"
mkdir -p "$test_output_dir"
xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
  -module-cache-path "$test_output_dir/module-cache" \
  PokoPeeko/PokoPeeko/Features/Auth/Services/AuthService.swift \
  PokoPeeko/PokoPeeko/Features/Auth/DTOs/*.swift \
  PokoPeeko/PokoPeeko/Features/Auth/AppleAuthHelper.swift \
  PokoPeeko/PokoPeeko/Features/Auth/ProfileImageProcessor.swift \
  PokoPeeko/PokoPeeko/Features/Profile/ProfilePhotoViewModel.swift \
  PokoPeeko/PokoPeeko/Features/Profile/NicknameEditViewModel.swift \
  PokoPeeko/PokoPeeko/Shared/Session/*.swift \
  PokoPeeko/PokoPeeko/Shared/Models/UserProfile.swift \
  PokoPeeko/PokoPeeko/Shared/Networking/APIConfig.swift \
  PokoPeeko/PokoPeeko/Shared/Networking/DTOs/ErrorResponseDTO.swift \
  Tests/AuthServiceChecks.swift -o "$test_output_dir/checks"
"$test_output_dir/checks"
