# 친구 요청 API

명세: 개발 서버 [Swagger](https://port-0-pokopeeko-mvzcjohte9c33cc4.sel3.cloudtype.app/api-docs). 아래 요청은 모두 `x-session-id`로 인증하고 본문을 보내지 않는다.

| 기능 | 메서드·경로 |
| --- | --- |
| 받은 요청 | `GET /api/friend-request/requests/received` |
| 보낸 요청 | `GET /api/friend-request/requests/sent` |
| 보내기 | `POST /api/friend-request/{addresseeId}` |
| 수락 | `PATCH /api/friend-request/{friendRequestId}/accept` |
| 거절 | `PATCH /api/friend-request/{friendRequestId}/reject` |
| 취소 | `DELETE /api/friend-request/{friendRequestId}/cancel` |
| 친구 삭제 | `DELETE /api/friend/{addresseeId}` |
| 새 사용자 이름 검색 | `GET /api/user/search?keyword=...` |
| 전체 친구 목록 | `GET /api/friend/search` (keyword 생략) |

## 식별자와 응답

- 사용자 ID(`addresseeId`)는 UUID다.
- 요청 ID(`friendRequestId`)는 숫자로만 이루어진 **문자열**이다. BigInt 값을 정수로 변환하지 않아 오버플로·정밀도 손실을 방지한다.
- 조회 응답의 `data.friendRequests`에 요청 `id`와 `requester` 또는 `addressee`가 있다. 사용자 정보는 `id`, nullable `displayName`, nullable `profileImage`다.
- 보내기는 HTTP 201과 `data.friendRequestId`를 반환한다. 수락·거절·취소는 HTTP 200, `success`, `message`, `data: null`을 반환한다.
- 400은 본인 요청·중복 요청·친구 관계·이미 처리된 요청 등 서버의 규칙에 따른 거절이다. 서버 메시지를 표시하며 POST/PATCH/DELETE를 자동 재시도하지 않는다.

## 클라이언트 흐름

- 신규 사용자 이름 검색은 `GET /api/user/search`의 `keyword` 쿼리로 연결한다. 서버는 친구 여부와 관계없이 표시 이름으로 부분 검색하며 본인은 제외한다. `data.users`에 UUID·nullable 표시 이름·이미지 파일명을 반환한다.
- 이름 입력 → 검색 → 사용자 결과 선택 → 요청 확인 → 선택한 UUID로 POST한다. 이름 중복 결과를 합치지 않으며 UUID로 행과 대상을 식별한다. 친구 코드 입력·복사 UI는 제거한다. 검색 결과에 이미 친구·보낸 요청·받은 요청 상태를 표시한다.
- 받은 요청에서는 수락·거절, 보낸 요청에서는 취소를 제공한다. 진행 중 중복 조작을 막는다.
- 처리 성공 후 해당 목록과 수락된 친구 목록을 갱신한다. 재조회 실패는 이미 성공한 동작의 실패로 취급하지 않는다.
- 받은 요청·보낸 요청·친구 목록은 각각 조회한다. 한 조회의 실패로 다른 결과를 버리지 않는다.
- 로그아웃·다른 세션으로 변경 시 데이터를 비우고, 이전 요청의 늦은 응답은 무시한다. 401이면 해당 세션만 정리하도록 인증 상태에 전달한다.
- 앱 메인 화면 진입, 친구 요청 처리, 수동 새로고침 및 메뉴바 팝오버 진입 시 읽는다. 친구 REST 목록은 주기적으로 폴링하지 않는다. 친구 조회·수락 후 Socket.IO 상태를 재조회한다.
- REST 친구 목록에는 온라인·앱 활동 상태가 없으므로 별도 Socket.IO 이벤트를 UUID로 합성한다. 실시간 연결이 끊기면 상태를 확인 불가로 표시한다. [실시간 API 문서](API_PRESENCE.md)를 참고한다.

친구 삭제는 친구 프로필 상세의 삭제 버튼 → 확인 → DELETE 요청으로 연결한다. 별도 삭제 탭은 제거했다. 성공 시 UUID로 목록 항목을 제거하고 Presence의 유지 대상 ID도 즉시 갱신한 뒤 친구·요청 목록을 다시 읽는다. 실패하면 기존 친구를 유지하며 오류를 표시하고 자동 재전송하지 않는다. 중복 클릭과 이전 계정의 늦은 응답을 방어한다. 실제 다른 사용자에게 요청을 보내는 검증은 수행하지 않고 모의 HTTP로 검증한다.

2026-11-12 갱신된 Swagger의 `/api/user/search`를 확인해 이름 검색을 연결했다. `/api/friend/search`는 기존 친구 목록 조회이고, 새 사용자를 찾는 API와 구분한다. 사용자 ID는 요청·삭제·상태 연결에 계속 사용하되 직접 입력하지 않는다.

검색은 버튼/Return으로 실행한다. API는 keyword 생략 시 전체 사용자를 반환하지만 앱은 빈 검색을 보내지 않는다. URLComponents로 한 개의 keyword를 인코딩하고 literal +도 보존한다. 검색어 변경·계정 변경 이후의 늦은 응답을 무시하며 401은 해당 세션만 정리한다. 요청 성공 시 서버가 준 요청 ID로 보낸 요청을 즉시 반영하고 목록을 재조회한다.

메뉴바의 친구 상세·삭제 확인은 내부 화면으로 표시하고 메인 앱에서는 sheet·표준 확인 창을 사용한다. HTTP 요청과 UUID 식별·오류 처리는 동일하다.
