# PokoPeeko

**친구의 지금을, Mac 메뉴바에서.**

PokoPeeko는 친구가 사용 중인 앱과 듣고 있는 음악을 실시간으로 공유하는 macOS 메뉴바 앱입니다. 각자의 공간에서 작업하면서도 서로의 일상을 가볍게 나눌 수 있습니다.

## 주요 기능

### 메뉴바에서 확인하는 친구의 활동

메뉴바를 열어 친구가 현재 사용 중인 앱을 확인하세요. 온라인 친구를 기본으로 표시하고, 오프라인 친구도 함께 볼 수 있습니다. 내 활동은 목록 맨 위에서 확인할 수 있습니다.

### Apple Music · Spotify 음악 공유

Mac에서 듣고 있는 곡 제목과 가수를 친구에게 공유합니다. 일시정지 상태도 함께 표시하며, 음악 앱을 종료하면 음악 표시가 사라집니다.

대시보드와 음악 연동 화면에서는 내 음악의 앨범 표지와 재생 진행률도 확인할 수 있습니다.

### 직접 선택하는 공유 범위

공유할 앱을 선택하고 감지를 원하지 않는 앱은 차단할 수 있습니다. 자동으로 감지되지 않는 앱은 직접 추가할 수 있으며, 앱 활동과 음악 공유는 각각 켜고 끌 수 있습니다.

### 친구 검색과 프로필

이름으로 사용자를 검색하고 친구 요청을 보낼 수 있습니다. 받은 요청과 보낸 요청을 관리하고, 친구의 프로필을 확인하세요. 내 프로필 사진과 닉네임도 변경할 수 있습니다.

### Mac에 맞춘 설정

라이트·다크 모드와 시스템 테마를 지원합니다. Mac 로그인 시 자동 실행을 설정하고, 메뉴바에서 작업 흐름을 유지하며 사용할 수 있습니다.

## 사용 방법

1. Apple 계정으로 로그인하고 프로필을 설정합니다.
2. 이름으로 친구를 검색하고 친구 요청을 보냅니다.
3. 친구가 요청을 수락하면 메뉴바에서 서로의 앱 활동을 확인할 수 있습니다.
4. 음악 공유를 사용하려면 음악 연동에서 Apple Music 또는 Spotify를 선택하고 공유를 켭니다. 권한 요청 버튼을 눌러 macOS 자동화 접근을 허용해 주세요.

## 지원 환경

- macOS 26.2 이상
- 음악 공유: Mac용 Apple Music 또는 Spotify

## 기술 스택

| 구분 | 기술 |
|---|---|
| 언어 | Swift |
| UI | SwiftUI, AppKit |
| 아키텍처 | MVVM, Feature 기반 구조 |
| 상태 관리 | Observation |
| 인증 | Sign in with Apple, Firebase Authentication |
| 네트워크 | URLSession, Socket.IO |
| 앱 감지 | NSWorkspace, NSRunningApplication |
| 음악 감지 | Apple Events |
| 로컬 저장 | Keychain, UserDefaults, 파일 캐시 |

## 개발 환경 및 실행

1. 저장소를 클론합니다.
2. `PokoPeeko/PokoPeeko.xcodeproj`를 엽니다.
3. Firebase 설정 파일 `GoogleService-Info.plist`를 `PokoPeeko/PokoPeeko/`에 추가합니다.
4. Xcode에서 서명 팀을 설정하고 `PokoPeeko` 스킴으로 실행합니다.

Xcode 26.2 이상이 필요합니다. Firebase 설정 파일은 저장소에 포함하지 않습니다.

## 프로젝트 문서

- [개발 및 검증 안내](docs/DEVELOPMENT.md)
- [아키텍처](docs/ARCHITECTURE.md)
- [디자인](docs/DESIGN.md)

## 문의 및 피드백

오류 제보와 기능 제안은 [GitHub Issues](https://github.com/PokoPeeko/pokopeeko-macos/issues)에 남겨 주세요.
