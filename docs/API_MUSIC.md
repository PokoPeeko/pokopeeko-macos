# Mac 음악 감지와 공유

## 현재 구현

- 음악 연동 화면에서 Apple Music 또는 Spotify를 선택하고 감지·공유를 켠다. 카드 헤더의 switch 토글로 카드 전체를 활성/비활성화한다. 기본값은 꺼짐이며 선택·설정은 로컬 저장한다. 비활성화하면 앱 선택·상태 영역을 흐리게 표시하고 조작을 막는다.
- 선택한 앱이 실행 중일 때만 약 1초 간격으로 곡 제목·가수·재생 상태를 읽는다. 조회 완료 후 다음 조회를 예약하여 중첩하지 않는다. 음악 앱을 자동 실행하거나 재생을 제어하지 않는다.
- AppleScript가 사용하는 macOS Apple Events의 읽기 전용 scripting property를 직접 조회한다. 스크립트 프로세스를 매초 만들지 않으며, UI와 분리된 작업에서 타임아웃을 적용한다. 제목·가수는 문자열 구분자로 직렬화하지 않아 줄바꿈·쉼표도 보존한다.
- 실행 중인 프로세스 PID에만 요청한다. Music은 playback/library.read scripting target을 유지하고 Music·Spotify 두 bundle ID에만 Apple Events sandbox 예외를 설정한다. macOS 자동화 권한은 사용자가 별도 ‘권한 요청’ 버튼을 누를 때만 요청한다. 감지 토글·자동 시작·재시도·주기 조회에서는 요청하지 않는다. 거부 시 설정 안내와 명시적 재시도를 제공한다.
- 재생 중에는 곡·가수를, 일시정지에는 pause 아이콘과 흐린 곡·가수를 표시한다. 앱 종료·재생 중지·공유 끄기에는 로컬 표시를 없앤다. 음악 앱 전환이나 비활성화 이전에 시작한 늦은 조회는 반영하지 않는다.
- 긴 곡·가수 문자열만 수평으로 스크롤한다. 동작 줄이기 설정에서는 정적으로 표시하며 전체 내용을 접근성 레이블과 도움말로 제공한다.
- 메인 창이나 음악 화면을 닫아도 공유 모델이 감지를 유지한다. 개발용 로컬 진입은 제거했으며 음악 설정 화면은 로그인 후 접근한다. 소켓 연결 없이 감지한 정보는 연결 시 최신 상태로 전송한다.
- 음악 화면은 공유 꺼짐·앱 실행 대기·접근 확인 중·권한 필요·연결 실패·연결됨을 구분한다. 읽기에 성공했지만 재생 곡이 없으면 연결됨을 유지하고 재생 대기만 표시한다. 실패/권한 대기 안내는 연결 후 사라진다.
- 주기 조회는 `AEDeterminePermissionToAutomateTarget(askUserIfNeeded: false)`와 Apple Event의 `kAEDoNotPromptForUserConsent` 옵션으로 승인 창을 띄우지 않는다. 명시적 권한 버튼에서만 UI 외부 작업으로 `askUserIfNeeded: true`를 호출한다. 미승인/거부 시 자동 반복 요청을 멈추고 사용자가 ‘권한 요청’ 또는 설정 변경 후 ‘다시 확인’을 누르게 한다. 설정에서는 PokoPeeko 아래의 대상 음악 앱을 허용한다.
- 현재 곡 카드에 가능한 앨범 표지와 재생 진행률을 표시한다. Apple Music의 현재 track artwork raw data 또는 Spotify artwork URL을 곡 전환 시 한 번 읽으며, 이미지가 없으면 음악 앱 아이콘을 사용한다. Apple Music artwork 읽기에는 `com.apple.Music.library.read` scripting target을 추가했다.
- 재생 위치·길이는 로컬 UI 전용으로 읽고 서버에 전송하지 않는다. Spotify의 곡 길이는 밀리초를 초로 변환한다. 재생 중에만 표시 시간을 보간하고 일시정지 시 멈추며 다음 조회로 보정한다. 이 진행률은 읽기 전용이며 앱 사용 시간 누적과 별개다.
- 진행률 변화만으로 공유 변경 콜백을 실행하지 않는다. 곡·가수·재생 상태의 실제 변경만 기존 Socket.IO DTO로 보낸다.

## 서버 계약과 연결

2026-11-12 최신 배포 Swagger 기준으로 연결한다. 내부 모델은 `playing / paused / closed`를 사용하고, 서버 DTO는 아래 값과 이벤트로 변환한다. 이전 제안의 `playbackState` 필드는 보내지 않는다.

| 방향 | 이벤트 | 데이터와 처리 |
| --- | --- | --- |
| 송신 | `music_status:update` | 필수 `artistName`, `trackTitle`(각 1~200자), `status: PLAYING / PAUSE` |
| 송신 | `music_status:remove` | payload 없음. 본인의 음악 상태만 삭제 |
| 수신 | `music_status:updated` | `userId`, `artistName`, `trackTitle`, `status`, `updatedAt`(Unix 밀리초) |
| 수신 | `music_status:removed` | `userId`만 포함. 해당 친구 음악 표시만 제거 |

- 곡·가수·재생 상태가 변경될 때만 전송한다. 같은 상태를 로컬에서 1초마다 확인해도 서버에 반복 전송하지 않는다. 각 문자열은 공백을 정리하고 최대 200자로 제한한다.
- 일시정지에도 곡·가수를 함께 전송하며 친구 화면에 pause 아이콘과 흐린 텍스트를 표시한다.
- 음악 앱 종료·재생 중지·공유 끄기·유효한 곡 정보가 없는 상태에는 삭제 이벤트를 보낸다. 앱 활동 공유와 소켓 연결은 유지한다.
- 서버는 최신 음악 상태를 저장하고 수락된 친구에게 전달한다. 소켓 연결 시 최신 친구 앱·음악 상태를 자동 전달하고, 클라이언트도 리스너 등록 후 연결해 `friends_status:get`을 요청한다. 늦게 접속한 친구도 재생·일시정지 상태를 받는다.
- 재접속 시 재생 중·일시정지는 현재 상태를 다시 보내며, 음악이 없으면 삭제 이벤트를 다시 보낸다. 소켓 연결 없이 감지한 중간 이벤트를 모두 재생하지 않고 현재 상태만 보낸다.
- 삭제 알림에는 timestamp가 없다. 일반 음악 업데이트끼리는 `updatedAt` 순서를 확인하지만 삭제와 오래된 비동기 조회의 경합을 완전히 구분할 수 없다. 후속 안정성 항목으로 남긴다.
- 서버의 음악 상태는 사용자 단위다. 동일 계정으로 여러 Mac을 사용하면 한 Mac의 음악 삭제가 다른 Mac의 음악 상태에도 영향을 준다. 기기별 우선순위 정책은 이후 범위다.

## 검증

- `bash Tests/run-music-checks.sh`: 기본 비활성, 연결/재생 대기 상태 구분, 변경 중복 제거, 일시정지·종료·비활성화, 로컬 진행률 보간/정지, 표지 조회 중복 방지, 늦은 응답, 권한 거부, 요청 필드 확인. 실제 음악 앱을 조회하지 않는다.
- 기존 Presence 검사: 격리된 Socket.IO 서버로 음악 송신 필드·중복 제거, PLAYING/PAUSE 수신, 음악만 삭제, 초기 paused 상태 수신, 재접속 시 paused/삭제 재전송를 확인한다.
- 실제 서명된 앱의 자동화 권한 승인·두 플레이어의 실제 재생 및 두 계정 간 전달은 사용자 환경에서 별도 확인해야 한다.

권한 구성 참고: [Apple Events entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events), [App Sandbox Apple Events 제한](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/AppSandboxTemporaryExceptionEntitlements.html).

자동화 권한 요청 문구는 `Configuration/Info.plist`에 명시하고 생성된 기본 Info.plist와 병합한다. 실행 앱에서 해당 키 누락과 -1743을 확인해, 사용자 정의 `INFOPLIST_KEY_…` 설정에만 의존하지 않도록 수정했다. 실제 macOS 승인 창과 자동화 목록 등록은 서명된 새 빌드에서 확인해야 한다.

권한 승인 이후 실행 앱의 `-10004`와 Music의 `core/getd` sandbox dispatch 거절 로그를 확인했다. TCC 거부(-1743/-1744)와 구분하고 Music에만 한정된 Apple Events 호환 예외를 추가했다. 이 변경은 App Sandbox 전체를 끄지 않는다. 실제 새 서명 빌드에서 Music 응답 성공 여부는 별도로 확인해야 한다.

대시보드와 음악 연동은 `NowPlayingView`를 공유한다. 대시보드는 compact 크기만 다르며 같은 로컬 위치·길이·표지를 사용한다. UI 재사용으로 조회나 소켓 전송 주기를 늘리지 않는다.
