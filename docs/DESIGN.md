# UI 색상과 기본 표시 규칙

## 강조색

색상의 기준 파일은 `PokoPeeko/PokoPeeko/Assets.xcassets/AccentColor.colorset/Contents.json`이다. Xcode의 Global Accent Color Name은 `AccentColor`로 지정되어 있으며 SwiftUI에서는 `Color.accentColor` 또는 `.tint`로 사용한다. 색상 수치를 개별 View에 중복해서 넣지 않는다.

| 모드 | sRGB R / G / B | HEX 근삿값 |
| --- | --- | --- |
| 기본·라이트 | 0.357 / 0.439 / 0.737 | `#5B70BC` |
| 다크 | 0.604 / 0.678 / 0.937 | `#9AADEF` |

이 색은 앱의 브랜드 강조색이다. SwiftUI `.primary` / `.secondary`는 시스템의 텍스트 계층 색이므로 브랜드 강조색과 구분한다. 앱 설정의 시스템/라이트/다크 모드를 통해 해당 모드 색을 사용한다.

로그인·최초 프로필 설정은 시스템 배경색 위에 낮은 불투명도의 AccentColor 그라데이션을 전체 창과 가운데 폼 카드 모두에 적용한다. 카드에는 얇은 강조색 테두리와 약한 그림자를 사용하며 라이트·다크에서 텍스트 가독성을 유지한다.

## 메뉴바 활동 목록

내 활동과 친구 활동은 한 스크롤 목록에 배치한다. 내 행은 section header를 이용해 목록 상단에 고정하고 친구만 온라인/오프라인 필터를 적용한다. 내 음악은 이름 옆에 표시하고 기존 10pt secondary 텍스트와 일시정지 opacity를 유지한다. 내 행은 메인 프로필로 이동하고 친구 행은 같은 메뉴바 창 내부의 친구 프로필을 연다. 메인 앱에서 친구 행을 선택할 때는 sheet를 유지한다.

메뉴바의 이름/음악 구분자는 `·`이며 내 행도 같은 규칙을 사용한다. 온라인/오프라인 필터는 켜짐 상태가 유지되는 버튼형 Toggle를 사용한다.

## 필터 버튼

`Shared/Components/FilterToggle.swift`에서 하나의 네이티브 버튼 Toggle로 관리한다. 비활성은 기본 스타일을 유지하고 활성일 때만 foreground에 밝은 보라색(sRGB 0.80/0.77/0.92)을 직접 적용한다. 배경 및 tint는 별도 변경하지 않는다. 앱 전체 AccentColor는 변경하지 않는다.

A/B 선택과 설정 화면의 필터 스타일 항목은 제거했다. 기존 `filterButtonAppearance` 저장값은 더 이상 읽지 않으며 필터의 실제 활성 값에는 영향을 주지 않는다.

메뉴바 친구 상세는 친구 탭과 동일한 `FriendProfileView`를 재사용한다. 너비 300pt·최소 높이 380pt, 내용 크기에 맞게 표시하고 상세 자체의 ScrollView는 사용하지 않는다. 기본 상세의 하단 여백에 12pt를 추가한다. 회색은 라이트 white 0.92·다크 white 0.20, alpha 1로 이전보다 조금 진하게 조정했다. 다른 내용·서식은 유지한다.
