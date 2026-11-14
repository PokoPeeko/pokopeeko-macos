# 인증 API 연동

명세 출처: 개발 서버 [Swagger](https://port-0-pokopeeko-mvzcjohte9c33cc4.sel3.cloudtype.app/api-docs). 서버 주소는 `Shared/Networking/APIConfig.swift`에서 개발 환경에 맞게 수정한다.

## Apple 로그인

- `POST /api/auth/login/apple`
- `Authorization: Bearer <Firebase ID Token>`
- `x-device-id: <device UUID>`
- 요청 본문 없음. 인증 토큰과 디바이스 ID를 헤더로만 전송한다. 사용자가 확인한 백엔드 수정에 맞춰 로그인 요청 DTO와 JSON 본문을 제거했다.
- 성공 응답(최신 문서에서는 HTTP 201): `success`, `message`, `data.sessionId`, `data.needsProfileSetup`.

`needsProfileSetup`의 클라이언트·백엔드 합의는 **true이면 프로필 설정, false이면 메인 앱 진입**이다. 조회 당시 Swagger의 기존 사용자 true·신규 사용자 false라는 설명은 이 합의와 반대였다. 실제 백엔드 분기 동작을 검증한 것은 아니며, 앱에서는 사용자 확인을 받은 의미를 따른다. 현재는 재로그인 시 설정창이 반복되는 문제를 진단하기 위해 사용자 요청으로 **임시 반전**한다. 즉 서버 true는 메인 앱, 서버 false는 프로필 설정으로 해석하며, Keychain에는 변환한 설정 필요 여부를 저장한다. 이는 확인을 위한 임시 동작으로 백엔드 실제 의미가 확정된 것은 아니다. 해석 변경 전의 저장 세션은 재사용하지 않아 다음 실행 시 재로그인한다. 진단 후 원복할 때 플래그 변환과 세션 `routingVersion`을 함께 갱신한다.

Firebase UID나 이메일을 클라이언트가 별도로 인증 근거로 보내지 않는다. 백엔드가 Firebase ID 토큰을 검증한다.

## 최초 프로필 설정

- `PATCH /api/user/profile`
- `x-session-id: <session ID>`
- `Content-Type: multipart/form-data; boundary=...`
- `displayName`: 공백 없는 1~10자 텍스트. 수정 API 자체에서는 선택 필드지만 최초 설정 UI에서는 필수로 입력받는다.
- `profile_image`: 최신 수정 API에서는 선택 파일이며 생략하면 기존 이미지를 유지한다. Swift의 `profileImage: Data?`를 이 이름의 파일 파트로 전송한다. JSON 문자열·파일 경로·base64를 보내지 않는다.
- 같은 DTO는 기존 프로필 사진 변경에도 사용한다. `displayName`은 Swift에서 선택값으로 선언하고, 사진만 변경할 때는 해당 파트를 생략한다. 최초 설정 UI의 닉네임 필수 검증은 유지한다.

선택 이미지는 방향을 반영하고 긴 변을 최대 1024px로 줄인 PNG로 변환한다. 업로드 파일명은 `profile.png`, MIME 타입은 `image/png`다. 이는 클라이언트의 이미지 처리 기준이며 서버의 파일 크기 제한을 의미하지 않는다.

```json
{
  "success": true,
  "message": "프로필 수정에 성공했습니다.",
  "data": {
    "displayName": "권수영",
    "profileImage": "550e8400-e29b-41d4-a716-446655440000.png"
  }
}
```

`ProfileSetupResponseDTO`는 응답을 디코딩한다. Swagger에서 두 프로필 필드는 nullable이므로 DTO는 이를 허용한다. 최초 설정은 사진 선택·닉네임 필수로 제공한다. 사진을 선택하지 않으면 파일 파트를 보내지 않고 기본 아바타를 사용한다. 성공 응답에 비어 있지 않은 표시 이름이 반환되고 Keychain 저장까지 완료되어야 끝난다. 사진을 업로드했다면 이미지 파일명도 정상 반환되어야 한다. 이미지 파일명은 다운로드 URL로 간주하지 않는다.

## 로그아웃

- `POST /api/auth/logout`
- `x-session-id: <session ID>`
- 성공 응답(HTTP 201): `success`, `message`. 추가 `data: null`은 사용하지 않는다.
- 정상 성공 또는 서버의 401(이미 무효화된 세션)이면 해당 로컬 세션과 Firebase 인증을 정리한다.
- 네트워크·서버 오류가 나면 오류를 표시하고 로그인 상태를 유지한다. 앱 세션 삭제 후 Firebase 정리만 실패한 경우에는 로그아웃 화면으로 이동하고 남은 오류를 알린다.
- 요청 중 로컬 세션이 교체되면 새 세션을 지우지 않는다.

## 로컬 상태와 오류 처리

- 세션 ID, 프로필 설정 필요 여부, 설정 응답의 프로필 정보를 같은 Keychain 항목에 저장한다. 이미지 원본·업로드 파일은 Keychain에 넣지 않는다.
- 설정을 마치기 전 재실행하면 프로필 설정 화면을 이어간다. 이미지 선택은 다시 해야 한다.
- 이전 구현의 세션 문자열은 완료 여부를 판단할 수 없으므로 자동 로그인에 사용하지 않고 재로그인을 요구한다.
- Keychain 저장·삭제 오류를 무시하지 않는다. 저장이 실패하면 메인 앱으로 진입하지 않는다.
- 로그인 취소는 오류 메시지를 표시하지 않으며, 진행 중에는 중복 요청을 막는다.
- HTTP 오류·`success: false`·잘못된 JSON 응답을 성공으로 처리하지 않는다. 토큰이나 서버 응답 본문을 콘솔에 출력하지 않는다.
- 로그인 실패 화면에는 Firebase 인증·서버 로그인·로그인 정보 저장 중 실패한 단계를 표시한다. 서버 HTTP 오류에는 상태 코드를 함께 표시해 원인을 구분한다.

## 세션 확인·프로필 조회

로그인·시작 오류 화면의 개발용 로컬 진입 경로는 제거했다. 저장 세션 검증 또는 정상 로그인을 통과한 경우에만 메인 화면에 진입한다. 인증 오류 시 재시도·다시 로그인 복구는 유지한다.

`GET /api/user/profile` 명세가 완성되어 앱 시작 시 세션 유효성 확인과 프로필 조회를 함께 처리한다. 401·삭제된 사용자(404)는 로그인으로 이동하고, 통신 실패·서버 오류는 저장 세션을 유지한 채 재시도한다. 이미지 정적 경로도 사용자가 확인한 `/static/profile/{fileName}`으로 연결했다. 상세 내용은 [프로필 API 문서](API_PROFILE.md)를 참고한다.

실제 Apple 로그인·개발 서버 업로드는 개발 환경에서 별도로 확인해야 한다. `Tests/AuthServiceChecks.swift`는 외부 요청을 차단한 HTTP 모형으로 요청 형식과 응답 처리를 검증한다.
