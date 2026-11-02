# PokoPeeko for macOS

친구들의 앱 사용 상태와 사용 시간을 공유하는 macOS 메뉴바 앱입니다.

## 개발 환경

- Xcode 26.2 이상, macOS 26.2 이상
- SwiftUI / Observation 기반 MVVM
- Firebase SDK는 Swift Package Manager로 관리합니다. `Package.resolved`를 커밋해 버전을 고정합니다.

## 실행

1. `PokoPeeko/PokoPeeko.xcodeproj`를 엽니다.
2. 프로젝트 담당자에게 Firebase의 `GoogleService-Info.plist`를 받아 `PokoPeeko/PokoPeeko/`에 넣습니다. 이 파일은 Git에서 제외되며 앱 실행 시 필요합니다.
3. 로컬 개발용 서명 팀을 선택한 뒤 `PokoPeeko` 스킴으로 실행합니다.
4. Debug 빌드의 로그인 화면 또는 **개발 → UI 미리보기 열기**로 인증 없이 UI를 확인할 수 있습니다. 이 경로는 로그인·세션 상태를 변경하지 않습니다.

기존 인증 코드는 초기 구현 상태입니다. 백엔드 주소는 현재 `Shared/Networking/APIConfig.swift`의 개발 서버를 사용하며, 인증 완성 단계에서 설정과 API 명세를 정리할 예정입니다.

## 현재 구현 범위

- 메인 앱: 대시보드, 친구, 앱 사용 현황, 프로필, 설정, 앱 정보, 피드백 화면
- 메뉴바 팝오버: 친구 활동 목록, 온라인 필터, 메인 앱 및 설정으로 이동
- 샘플 데이터 / 빈 상태 전환, 친구·앱 검색, 앱 정렬
- 시스템·라이트·다크 테마 설정 저장, 피드백 초안 복사

기본 화면은 빈 상태입니다. 툴바의 **샘플 데이터**를 켜면 정적인 예시가 메인 앱과 팝오버에 함께 표시됩니다. 실제 활동 측정이나 서버 동기화가 실행되는 것은 아닙니다. 피드백은 전송되지 않으며 초안은 화면 수명 동안만 유지됩니다.

Release 빌드에는 인증 없는 UI 미리보기 진입이 없습니다. 기존 로그인 경로를 유지합니다.

## 문서

- [기능 요구사항](docs/PRD.md)
- [아키텍처](docs/ARCHITECTURE.md)
- [개발 규칙](AGENTS.md)

## 빌드 검증

```sh
xcodebuild -project PokoPeeko/PokoPeeko.xcodeproj \
  -scheme PokoPeeko -configuration Debug \
  CODE_SIGNING_ALLOWED=NO build
```

Xcode 개인 설정, 빌드 산출물, 로컬 환경 파일 및 인증 설정은 커밋하지 않습니다.
