# PokoPeeko for macOS

친구들의 현재 앱 사용 상태와 음악을 실시간으로 공유하는 macOS 메뉴바 앱입니다. 사용 시간 누적·공유는 설계 단계이며 아직 구현되지 않았습니다.

## 개발 환경

- Xcode 26.2 이상, macOS 26.2 이상
- SwiftUI / Observation 기반 MVVM
- Firebase SDK는 Swift Package Manager로 관리합니다. `Package.resolved`를 커밋해 버전을 고정합니다.

## 실행

1. `PokoPeeko/PokoPeeko.xcodeproj`를 엽니다.
2. 프로젝트 담당자에게 Firebase의 `GoogleService-Info.plist`를 받아 `PokoPeeko/PokoPeeko/`에 넣습니다. 이 파일은 Git에서 제외되며 앱 실행 시 필요합니다.
3. 로컬 개발용 서명 팀을 선택한 뒤 `PokoPeeko` 스킴으로 실행합니다.
4. 단일 메인 창 안에서 로그인 → 필요한 경우 프로필 설정 → 메인 화면으로 전환됩니다. 메뉴바에서도 같은 창을 열고 활성화합니다.

인증은 Apple → Firebase → 백엔드 순서로 처리하며 `needsProfileSetup`에 따라 프로필 설정 또는 메인 앱으로 이동합니다. 개발 서버 주소는 `Shared/Networking/APIConfig.swift`에서 수정합니다. 요청·응답과 미연동 항목은 [인증 API 문서](docs/API_AUTH.md)를 참고하세요.

## 현재 구현 범위

- Apple 로그인, 닉네임 필수·사진 선택 프로필 설정, 세션·설정 진행 상태 Keychain 저장, 로그아웃
- 메인 앱: 대시보드, 친구, 앱 목록, 음악 연동, 프로필, 설정, 정보, 피드백 화면
- 메뉴바 팝오버: 온라인 친구 기본 표시, 오프라인 포함 옵션, 메인 앱·친구 추가·설정으로 이동 및 창 활성화
- 실행 중인 앱 감지, 앱 실행·전환·종료 이벤트 수신, 현재 활성 앱 표시
- 로컬 앱 목록·차단·노출 설정 저장, 친구·앱 검색, 앱 정렬
- 앱 직접 추가(.app 파일 선택 또는 이름·번들 ID 입력), 감지 차단·해제 및 차단한 앱 탭, 노출 설정, 목록 삭제 UI
- 친구 목록 조회, 이름으로 사용자 검색·UUID로 요청 전송, 받은·보낸 요청 조회·수락·거절·취소
- 앱 시작 시 세션 검증과 내 프로필 조회, 사용자 프로필 조회, 실제 아바타 로딩
- 친구 목록·메뉴바·대시보드에서 프로필 상세 조회 및 상세 내 친구 삭제
- 계정별 프로필 캐시, 아바타 메모리·디스크 캐시 및 중복 다운로드 방지, 새로고침 중 기존 정보 유지
- Socket.IO 세션 인증, 현재 앱 공유, 친구 활동 수신, 20초 heartbeat·재조회, 재연결 및 콘솔 상태 로그
- 기존 프로필 사진 다시 선택·PNG 업로드, 닉네임 유지
- 사진을 유지하는 닉네임 변경, 공백 없는 1~10자 검증
- macOS 로그인 시 자동 실행 등록·해제, 승인 상태 안내, 활동 공유 일시 중지, 오프라인 친구 표시 설정
- 시스템·라이트·다크 테마 설정 저장, 피드백 초안 복사

샘플 데이터는 없습니다. 앱을 실행하거나 전환하면 실제 앱이 목록에 등록됩니다. 감지 허용을 끄면 차단한 앱 탭으로 이동하고 재등록을 막습니다. 노출을 끄면 관리 목록에는 남고 대시보드에서 숨겨집니다. 목록 삭제는 앱을 제거하거나 차단하지 않으므로 다음 감지 시 재등록될 수 있습니다.

앱 아이콘은 로컬의 설치된 앱에서 가져옵니다. 친구의 앱을 이 Mac에서 찾을 수 없으면 기본 아이콘을 표시합니다. 친구의 앱 활동은 Socket.IO 연결 성공 시 표시합니다. 실제 두 계정 간 상태 전달은 별도 검증이 필요합니다. 프로필 사진은 확인된 서버 정적 경로로 표시합니다.

Mac Apple Music·Spotify의 곡·가수·재생/일시정지 공유와 종료 시 음악 삭제를 연결했습니다. 친구 삭제는 프로필 상세에서 제공하며 사용 시간 측정은 미구현입니다. 피드백 초안은 복사할 수 있지만 전송되지 않으며 화면 수명 동안만 유지됩니다. Debug·Release 모두 동일한 단일 창과 로그인 경로를 사용합니다.

## 문서

- [기능 요구사항](docs/PRD.md)
- [아키텍처](docs/ARCHITECTURE.md)
- [인증 API](docs/API_AUTH.md)
- [프로필 API](docs/API_PROFILE.md)
- [친구 요청 API](docs/API_FRIENDS.md)
- [실시간 상태 API](docs/API_PRESENCE.md)
- [개발 규칙](AGENTS.md)

## 빌드 검증

```sh
xcodebuild -project PokoPeeko/PokoPeeko.xcodeproj \
  -scheme PokoPeeko -configuration Debug \
  CODE_SIGNING_ALLOWED=NO build
```

Xcode 개인 설정, 빌드 산출물, 로컬 환경 파일 및 인증 설정은 커밋하지 않습니다.

앱 목록 정책 및 실제 실행 중인 앱 조회 검증(테스트 전용 저장 영역 사용):

```sh
swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
  PokoPeeko/PokoPeeko/Shared/Models/DetectedApp.swift \
  PokoPeeko/PokoPeeko/Features/Apps/AppCatalog.swift \
  PokoPeeko/PokoPeeko/Shared/Components/AppIconView.swift \
  Tests/AppCatalogChecks.swift -o /tmp/pokopeeko-app-catalog-checks
/tmp/pokopeeko-app-catalog-checks
```

인증 요청·파일 전송 검증(외부 요청 없이 가짜 HTTP 응답 사용, 실제 Keychain 변경 없음):

```sh
bash Tests/run-auth-checks.sh
```

프로필·세션 복원·친구 요청 회귀 검증(모의 HTTP 및 메모리 저장소 사용):

```sh
bash Tests/run-profile-friend-checks.sh
```

실제 사용자에게 친구 요청을 보내거나 실제 Keychain 데이터를 변경하지 않습니다.

실제 Socket.IO 모듈·격리된 localhost 프로토콜 검증(먼저 Xcode 빌드 필요):

```sh
bash Tests/run-presence-checks.sh /private/tmp/pokopeeko-ui-build/Build/Products/Debug
```

프로필·아바타 캐시 검증(모의 HTTP와 테스트 전용 디렉터리):

```sh
bash Tests/run-profile-cache-checks.sh
```

Mac 음악 감지·공유의 현재 범위와 서버 계약은 [음악 API](docs/API_MUSIC.md)를 참고한다. 로컬 감지 검사는 `bash Tests/run-music-checks.sh`로 실행한다.

앱 아이콘은 `Assets.xcassets/AppIcon.appiconset`에 macOS용 16~1024px PNG로 등록되어 있습니다.

현재 적용된 앱 아이콘 원본은 `Design/AppIcon/Concepts/02-rabbit-laptop-apple-v2.png`입니다(토끼·맥북·애플 로고 시안).

친구 관리에서 별도 삭제 탭과 개발용 안내·로컬 진입은 제거했습니다. 추가된 사용자 검색 API로 이름 검색을 제공하며 요청·삭제는 내부 UUID로 식별합니다.

UI 강조색의 기준 파일과 라이트·다크 값은 [디자인 규칙](docs/DESIGN.md)에 정리했습니다.
