# 실시간 친구 앱 상태

명세: [배포 서버 Swagger](https://port-0-pokopeeko-mvzcjohte9c33cc4.sel3.cloudtype.app/api-docs)의 최상단 Socket.IO 설명과 상태 DTO.

## 연결

- 클라이언트: 공식 `socket.io-client-swift` 16.1.1, Swift Package Manager로 고정한다.
- Socket.IO namespace: `/user-status`, Engine.IO handshake path: `/socket.io/`. `/api`는 붙이지 않는다.
- namespace CONNECT payload의 `sessionId`로 인증한다. Swift의 `connect(withPayload:)`가 서버의 `auth.sessionId`에 해당하며 쿼리나 REST 헤더에 세션을 넣지 않는다.
- `APIConfig.socketBaseURL`에 소켓 서버 origin을 설정한다. 현재는 사용자가 제공한 API 배포 주소를 기본값으로 사용하며 별도 소켓 주소는 확인되지 않았다.
- Swagger는 소켓 Gateway가 API와 별도의 포트 80을 사용한다고 설명한다. 확인 당시 현재 배포 origin의 `/socket.io/?EIO=4&transport=polling`은 HTTP 404였다. 클라이언트 연결 구현 완료와 실제 배포 서버 접속 성공을 구분한다.
- 현재 사용자가 로컬 서버로 변경한 환경에서는 REST `http://172.28.49.236:3000`, 소켓 `http://172.28.49.236:80`을 사용한다. 같은 handshake 요청으로 3000번은 404, 80번은 Engine.IO open packet을 포함한 200을 확인했다. 실제 사용자 세션의 namespace 연결 및 두 계정 송수신 검증은 별도로 필요하다. 시연하는 두 Mac 모두 이 서버에 접근할 수 있는 네트워크에 있어야 한다.

## 이벤트

| 방향 | 이벤트 | 데이터 |
| --- | --- | --- |
| 송신 | `music_status:update` | 필수 `artistName`, `trackTitle`(각 최대 200자), `status: PLAYING / PAUSE`. 변경·재연결 시 전송 |
| 송신 | `music_status:remove` | payload 없음. 음악 상태만 삭제 |
| 송신 | `window_status:update` | 필수 문자열 `appTitle`(최대 100자), `taskDescription`(최대 500자) |
| 송신 | `friends_status:get` | 없음. 결과는 개별 updated 이벤트로 수신하며 ACK·조회 완료 이벤트 없음 |
| 송신 | `user_status:heartbeat` | 없음. 20초마다 전송, 서버 상태 TTL 60초 갱신 |
| 수신 | `window_status:updated` | `userId` UUID, `appTitle`, `taskDescription`, `updatedAt` Unix 밀리초 |
| 수신 | `music_status:updated` | `userId`, `artistName`, `trackTitle`, `status`, `updatedAt` |
| 수신 | `music_status:removed` | `userId`. 해당 사용자의 음악 캐시만 삭제 |
| 수신 | `user_status:removed` | `userId`. 해당 사용자의 앱·음악 캐시 모두 삭제 |
| 수신 | `exception` / `connect_error` | 연결·인증·요청 오류. 정확한 세션 무효 메시지만 해당 세션 정리로 전달 |

리스너를 먼저 등록한 뒤 연결한다. 연결 직후와 친구 목록 조회·친구 수락 후 상태를 조회한다. 20초마다 heartbeat, 현재 앱 재전송, 친구 상태 재조회를 수행한다. 재연결 시에도 현재 앱을 재전송한다. 알 수 없는 서버 오류는 인증 만료로 처리하지 않는다.

연결 상태 배너·인디케이터는 일반 화면에 표시하지 않는다. `OSLog`의 subsystem `com.peekopoko.pokopeeko`, category `Presence`에 연결·종료·오류를 기록한다. Socket.IO 원본 로그는 비활성화하고 세션·토큰·친구 UUID·앱 제목·이벤트 본문은 기록하지 않는다. 서버 호스트·포트와 namespace는 연결 진단용으로 기록한다.

## 앱 동작과 제한

- 로컬 앱 감지 변경을 서비스가 직접 구독하므로 메인 화면을 닫아도 앱이 실행 중이면 상태 공유를 계속한다.
- 감지와 노출이 허용된 현재 앱의 이름만 보낸다. 작업 설명은 `앱 사용 중`이며 실제 창 제목·문서명은 수집하지 않는다.
- 사용자가 설정에서 활동 공유를 끄면 연결과 친구 상태 수신은 유지하며 본인의 앱 상태만 비공개로 전송한다. 다시 켜면 현재 감지된 앱을 전송한다.
- 현재 앱이 없거나 차단·노출 비활성 상태면 앱 제목 `활동 비공개`, 설명 `공유 중인 앱이 없습니다`로 이전 상태를 교체한다. 이는 빈 문자열·삭제 이벤트를 지원하지 않는 현재 계약에 맞춘 클라이언트 표시 정책이다. 다른 디바이스에서 공유 중인 상태까지 지우지는 않는다.
- 친구 UUID로 REST 목록과 상태를 합성한다. 실시간 연결이 없으면 온라인 여부를 확인 불가로 표시한다. 연결 중 상태가 없으면 `오프라인 또는 공유 활동 없음`으로 표시한다. 서버는 접속자 전체 명단을 제공하지 않으므로 접속 여부 자체와 완전히 동일하지는 않다.
- 상태별 마지막 수신 후 70초 동안 갱신되지 않으면 로컬 표시를 비운다. heartbeat가 서버 `updatedAt`을 변경하지 않으므로 이를 TTL 기준으로 쓰지 않는다. 재조회에서 동일 timestamp를 받아도 마지막 수신 시각을 갱신한다. 오래된 timestamp의 이벤트는 최신 상태를 덮어쓰지 않는다.
- 서버 응답에는 앱 번들 ID와 누적 사용 시간이 없다. 앱 아이콘은 정확한 로컬 이름 일치로 찾을 수 있는 경우만 표시하고, 사용 시간을 임의로 계산하지 않는다. Mac Apple Music·Spotify의 곡·가수 감지·전송을 연결했다. 일시정지는 곡·가수와 PAUSE 상태를 전송하고 종료·공유 끄기는 음악 삭제 이벤트로 연결했다. 자세한 계약은 [음악 API](API_MUSIC.md)를 따른다.
- 로그아웃·세션 변경 시 소켓과 타이머·친구 상태를 정리한다. 이전 연결의 늦은 콜백은 무시한다.

## 검증

`Tests/run-presence-checks.sh <Xcode Debug products 디렉터리>`는 빌드된 공식 Socket.IO 모듈을 사용한다. 격리된 localhost Engine.IO v4 polling 서버로 namespace 인증, 앱 상태 전송·수신, 비공개 상태 교체, heartbeat·친구 재조회, 인증 거절·종료를 검증한다. 순서가 바뀐 이벤트·자연 만료·음악 상태·친구 삭제 시 캐시 정리도 검사한다. 실제 사용자 계정이나 배포 서버를 사용하지 않으며 제품에 샘플 데이터를 넣지 않는다.

메뉴바의 내 활동 행은 친구들과 같은 목록 상단에 고정하되 친구 서버 목록에 자신을 추가하지 않고 공유 모델의 현재 앱·음악과 내 프로필을 읽어 표시한다. 앱 공유를 끄면 비공개 상태를 표시하며 음악 공유 설정은 별도로 반영한다. 이는 로컬 모니터링이며 서버가 친구에게 실제 전달했다는 ACK 표시가 아니다.
