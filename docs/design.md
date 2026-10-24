## 3위 우리애콘 — 반려동물 스티커 팩

결론: 누끼는 OS 기본 기능이 되므로 차별점은 "사진을 판 어긋난 리소 2판 스티커로 바꾸는 변환 + 한국어 12컷 팩"에 둔다. 성장은 "카카오톡 피드 카드의 '우리 애도 만들기' 버튼 + 이미지 속 작은 스탬프"로 만들고, 재방문은 시즌 템플릿 팩·여러 반려동물·주 1회 '오늘의 한 장'으로 만든다. 처리는 전부 Android 기기 안에서 하고(서버 0, 유료 API 0원), Gboard 연동과 카톡 이모티콘 스토어 입점은 하지 않는다.

| 결정 | 내용 |
|---|---|
| 차별점 | 누끼가 아니라 리소 2판 변환(핑크+블루, 판 어긋남·하프톤 망점)과 한국어 말풍선 12컷 |
| 주 전송 경로 | ① 카카오톡 공유 피드 카드(스티커 이미지 + 버튼) ② Android 공유 시트로 이미지 전송 |
| 성장 장치 | 버튼 "우리 애도 만들기" → Play(리퍼러에 템플릿 ID) → 첫 실행 때 친구와 같은 컷으로 시작 |
| 재방문 장치 | 계절·이벤트 템플릿 팩, 반려동물 여러 마리, 주 1회 로컬 알림(사용자가 켤 때만) |
| 하지 않음 | 이미지 생성 AI, 서버, 유료 API, Gboard 스티커, 카톡 이모티콘 스토어, iOS(MVP) |

### 1. 문제 정의

| 항목 | 내용 |
|---|---|
| 대상 | 카카오톡으로 가족·친구·반려인 단톡방과 대화하는 20~40대 한국 반려인(강아지·고양이) |
| 문제 인식 | "우리 애 이모티콘"을 원하지만 외주는 정지 1종 ₩20,000~30,000으로 비쌈 [출처](https://kmong.com/gig/203919). 누끼 스티커는 만들 수 있어도 사진 그대로라 "작품" 느낌이 없음 |
| 원하는 것 | 몇 분 안에 우리 애가 그대로 닮은, 예쁘고 말이 들어간 스티커 묶음을 단톡방에 바로 보내기 |
| 관찰되는 현상 | iOS·삼성 갤러리는 길게 눌러 스티커 만들기를 이미 제공(조사 문서 g2 3장). 결과물이 한 장짜리 누끼라 팩이 안 되고, 한 번 쓰고 잊힘. 반려동물 사진은 갤러리에 계속 쌓임 |
| 기대 효과 | 설치 후 5분 안에 첫 스티커를 보냄. 받은 사람 일부가 "우리 애도" 하며 설치함. 계절마다 다시 열어 새 팩을 만듦 |

### 2. 검증 가능한 가설

| ID | 가설 | 성공 기준(수치) | 측정 시점 |
|---|---|---|---|
| H0 기술 | ML Kit 분할이 반려동물 사진에서 쓸 만함 | 테스트 사진 30장 중 수정 없이 OK 판정 ≥ 80%, 중급기 1장 처리 ≤ 1.5초 | 스프린트 1 |
| H1 활성화 | 리소 변환이 "갖고 싶은" 결과를 만든다 | 설치자 중 첫 세션에서 스티커 1장 이상 저장·전송 ≥ 60%, 12컷 팩 완성 ≥ 35% | 비공개 테스트·출시 4주 |
| H2 전송 | 팩을 만든 사람은 보낸다 | 팩 완성자 중 7일 안 외부 전송 ≥ 50%, 전송자 1인당 주 5회 이상 | 출시 4주 |
| H3 바이럴 | 받은 사람이 설치한다 | 카톡 카드 버튼 클릭률 ≥ 8%, 전체 신규 설치 중 공유 유입 ≥ 30%, K ≥ 0.2 | 출시 8주 |
| H4 재방문 | 새 템플릿 팩이 휴면 사용자를 깨운다 | 시즌 팩 공개 주에 30일 휴면자 재방문 ≥ 10%, 2마리 이상 등록 ≥ 15% | 첫 시즌 팩 후 |

K 계산식: K = 전송 사용자 비율 × 1인당 전송 수 × 카드 클릭률 × 설치율. 예시(가정): 0.6 × 10 × 0.1 × 0.35 = 0.21.

### 3. MVP 범위와 백로그

| 구분 | 항목 | 이유 |
|---|---|---|
| MVP | 반려동물 등록 + Photo Picker 3~5장 | 권한 0개로 시작 |
| MVP | ML Kit 분할 + 가장자리 다듬기 슬라이더 | 핵심 기능 |
| MVP | 리소 2판 변환(핑크+블루 1종) + 흰 테두리 | 시그니처 |
| MVP | 템플릿 12컷 자동 구성, 머리 위치 탭, 문구 수정 | 팩 경험 |
| MVP | 갤러리 저장(투명 PNG + 흰 배경 PNG), 공유 시트, 카톡 피드 카드 | 전송·성장 |
| MVP | 스탬프 워터마크(기본 켬, 설정에서 끔), 설치 리퍼러 템플릿 | 성장 루프 |
| MVP | 반려동물 여러 마리, 번들 시즌 팩 1개, 주 1회 알림(선택) | 재방문 |
| MVP | Firebase Analytics·Crashlytics | 지표 |
| 백로그 | 원격 템플릿 팩(GitHub Pages 정적 JSON) | 앱 업데이트 없이 팩 추가 |
| 백로그 | Instagram 스토리 스티커 공유 | Facebook App ID 필요 |
| 백로그 | WhatsApp 스티커팩 | 한국 사용률 낮음, 규격 작업 필요 |
| 백로그 | 브러시 지우개·복원, 판 색 프리셋 추가, 움직이는 스티커 | 품질·재미 확장 |
| 백로그 | iOS | 분할 플러그인이 Android 전용 |
| 제외 | 카톡 이모티콘 스토어 입점, Gboard 스티커, 이미지 생성 AI, 결제 | 범위 밖·불가·원칙 위반 |

### 4. 에픽 → 피처 → 유저 스토리

가치 1~3(높을수록 중요), 노력 S=1·M=2·L=3. 우선순위 = 가치 ÷ 노력.

| ID | 에픽 / 피처 | 유저 스토리(누가/무엇을/왜) | 인수 조건 | 크기 | 가치 | 우선 |
|---|---|---|---|---|---|---|
| A1 | 팩 만들기 / 등록 | 보호자로서 이름·종을 넣고 사진 3~5장을 고른다, 권한 걱정 없이 바로 시작하려고 | 권한 팝업 0회. 선택 상한 5장. 긴 변 1024px로 줄여 저장. 512px 미만 사진은 경고 | S | 3 | 3.0 |
| A2 | 팩 만들기 / 오려내기 | 보호자로서 배경이 지워진 미리보기를 본다, 우리 애만 쓰려고 | 중급기 1장 ≤ 1.5초. 전경 비율 5% 미만·95% 초과면 "다른 사진" 안내. 모델 내려받는 중이면 진행 표시 | M | 3 | 1.5 |
| A3 | 팩 만들기 / 오려내기 | 보호자로서 가장자리를 조금 깎거나 넓힌다, 털 끝이 어색할 때 고치려고 | 슬라이더 ±4px. 결과 즉시 갱신(≤ 100ms) | S | 2 | 2.0 |
| A4 | 팩 만들기 / 리소 변환 | 보호자로서 사진이 2도 인쇄 스티커처럼 바뀌는 걸 본다, 사진과 다른 "작품"을 갖고 싶어서 | 512px 변환 ≤ 150ms(GPU). 같은 사진은 같은 어긋남(시드 고정). 망점이 확대 없이 보임 | M | 3 | 1.5 |
| A5 | 팩 만들기 / 리소 변환 | 보호자로서 흰 테두리 두께를 고른다, 어두운 채팅 배경에서도 잘 보이게 | 0~16px, 기본 11px(시안 값) | S | 2 | 2.0 |
| A6 | 팩 만들기 / 12컷 | 보호자로서 사진을 올리면 12컷이 자동으로 채워진다, 하나씩 꾸미기 귀찮아서 | 사진 3장이면 컷당 회전·반전·크기 변형으로 12컷 채움. 중급기 12컷 ≤ 10초 | M | 3 | 1.5 |
| A7 | 팩 만들기 / 12컷 | 보호자로서 머리를 한 번 탭해 소품 위치를 맞춘다, 소품이 엉뚱한 곳에 붙지 않게 | 기본은 전경 상단 20% 지점. 탭 1회로 12컷 모두 반영 | S | 3 | 3.0 |
| A8 | 팩 만들기 / 12컷 | 보호자로서 말풍선 문구를 바꾼다, 우리 집 말투로 쓰려고 | 12자 이내. 번들 한글 폰트 1종(상업 이용 가능 라이선스) | S | 2 | 2.0 |
| B1 | 보내기 / 저장 | 보호자로서 12장을 한 번에 갤러리에 저장한다, 나중에 쓰려고 | 투명 PNG + 흰 배경 PNG 각 12장. EXIF 없음 | S | 2 | 2.0 |
| B2 | 보내기 / 공유 시트 | 보호자로서 한 컷을 아무 앱으로 보낸다, 카톡 말고도 쓰려고 | 기본은 흰(종이색) 배경 PNG. share_plus 호출 성공 기록 | S | 3 | 3.0 |
| B3 | 보내기 / 카톡 카드 | 보호자로서 카톡에 스티커 카드를 보낸다, 친구가 크게 보고 반응하게 | 이미지 업로드 후 피드 카드 전송. 버튼 "우리 애도 만들기". 카톡 미설치·쿼터 초과면 공유 시트로 대체 | M | 3 | 1.5 |
| B4 | 보내기 / 스탬프 | 받은 사람으로서 이미지 구석의 '우리애콘' 표시를 본다, 어디서 만들었는지 알려고 | 이미지 폭 8% 이하, 우하단, 설정에서 끔 가능 | S | 3 | 3.0 |
| B5 | 보내기 / 리퍼러 | 새 사용자로서 친구가 보낸 컷 템플릿으로 첫 팩을 시작한다, 바로 "그거" 만들려고 | Play 링크 referrer의 template 값 읽기. 값 없으면 기본 팩 | M | 2 | 1.0 |
| C1 | 다시 열기 / 여러 마리 | 보호자로서 반려동물을 여러 마리 등록한다, 둘째 팩도 만들려고 | 마리 수 제한 없음. 홈에 마리별 팩 목록 | S | 2 | 2.0 |
| C2 | 다시 열기 / 시즌 팩 | 보호자로서 여름(휴가·장마) 같은 시즌 컷을 받는다, 그때 보낼 인사를 만들려고 | 번들 시즌 팩 1개(여름, 12컷). 이미 오린 사진 재사용(다시 고를 필요 없음) | M | 3 | 1.5 |
| C3 | 다시 열기 / 오늘의 한 장 | 보호자로서 주 1회 "오늘의 한 장" 알림을 받는다, 보낼 거리를 떠올리려고 | 기본 꺼짐. 켤 때만 알림 권한 요청. 퇴근 시간대(18:30) 기본 | S | 2 | 2.0 |
| D1 | 출시 기반 / 계측 | 개발자로서 이벤트를 본다, 가설을 판정하려고 | 6장 이벤트 목록 전부 기록. 사진·이름은 보내지 않음 | S | 3 | 3.0 |
| D2 | 출시 기반 / 스토어 | 개발자로서 스토어 서류를 낸다, 출시하려고 | 개인정보처리방침·Data safety·등급 설문·스크린샷 완료 | M | 3 | 1.5 |
| (L) | 브러시 지우개·복원 | L이라 쪼갬 → 지우개(M) + 복원(M) + 실행 취소(S), 전부 백로그 | - | L | 2 | - |

### 5. 2주 스프린트 계획

가정: 평일 저녁 + 주말, 스프린트당 약 20시간. 시작 2027-04-12, 출시 목표 2027-06-27.

| 스프린트 | 기간 | 목표(1~2개) | 스토리 | 끝날 때 동작하는 결과물 |
|---|---|---|---|---|
| S1 스파이크 | 04/12~04/25 | ① 분할 품질·속도 검증(H0) ② 리소 셰이더 프로토타입 | A1, A2, A4(초안) | 사진 1장 → 리소 스티커 PNG 1장 저장. 사진 30장·기기 2대 측정표. H0 실패 시 다듬기·사진 가이드 강화로 방향 수정 |
| S2 | 04/26~05/09 | ① 12컷 팩 완성 | A3, A5, A6, A7, A8, B1 | 사진 3장 → 12컷 → 갤러리 저장 |
| S3 | 05/10~05/23 | ① 보내기와 성장 루프 ② 계측 | B2, B3, B4, B5, D1 | 카톡 카드·공유 시트 전송, 리퍼러로 템플릿 시작, 이벤트 확인 |
| S4 | 05/24~06/06 | ① 재방문 장치 ② 스토어 준비 | C1, C2(여름 팩), C3, D2 | 내부 테스트 빌드 + 스토어 서류 완료. 6/7 비공개 테스트 시작 |
| S5 | 06/07~06/20 | ① 비공개 테스트 12명·14일 연속 유지 ② 버그·저사양 대응 | 테스트 피드백 | 14일 충족(6/20) 후 6/21 프로덕션 신청 → 6/27 출시 목표. 6월 기말과 겹치므로 새 기능 없이 버그 대응만. 추석 팩은 출시 후 |

- 비공개 테스트: 신규 개인 계정은 12명 이상이 14일 연속 참여해야 프로덕션 신청 가능 [출처](https://support.google.com/googleplay/android-developer/answer/14151465). 테스터는 15명 모집(이탈 대비).
- targetSdk: 2026-08-31부터 신규 앱은 API 36 이상 [출처](https://support.google.com/googleplay/android-developer/answer/11926878).
- 매 작업 전 세 줄 메모(어제/오늘/막힌 것). 도구는 GitHub Projects 하나.

### 6. 지표

| 구분 | 지표 | 목표 | 도구(무료) |
|---|---|---|---|
| 북극성 | 주간 전송자 수: 지난 7일 앱 밖으로 스티커를 1회 이상 보낸 사용자 | 출시 8주에 주간 설치자의 40% | Firebase Analytics |
| 보조 1 | 활성화율: 설치 → 첫 세션 저장·전송 | ≥ 60% | Firebase Analytics |
| 보조 2 | 공유 유입 비중: 신규 설치 중 utm_source=sticker_share | ≥ 30% | play_install_referrer + Firebase |
| 보조 3 | D30 재방문율(시즌 팩 공개 주 포함) | ≥ 15% | Firebase Analytics |
| 보조 4 | 크래시 없는 사용자 비율 | ≥ 99% | Crashlytics, Play Console Android vitals |

주요 이벤트: `pet_created`, `segment_done`(소요 ms, 성공 여부), `sticker_saved`, `pack_completed`, `share_tap`(channel: kakao/sheet), `kakao_share_sent`, `first_open_referrer`(template), `season_pack_opened`, `notif_open`.
- 한계: share_plus는 Android에서 실제 전송 여부를 보장해 알려주지 않음(결과 `status`가 `unavailable`일 수 있음) [출처](https://pub.dev/packages/share_plus). 그래서 "전송"은 공유 시트 호출 성공 + 카톡 카드 전송 성공으로 정의.
- Firebase 무료 요금제 한도 수치는 미확인(가입 시 확인).

### 7. 회고 방식

| 항목 | 내용 |
|---|---|
| 시점 | 스프린트 마지막 날 30분, 혼자 |
| 순서 | ① 목표 달성 여부(결과물 동작 영상 1개) ② 지표 1장 확인(북극성·보조) ③ 가설 판정(유지/수정/폐기) ④ 다음 스프린트 목표 1~2개 결정 |
| 고정 질문 | 사람들이 보내는 컷은 무엇인가(문구 vs 표정)? 분할 실패는 어떤 사진·기기에서 나오나? 카드 클릭은 일어나는데 설치가 안 되는가, 클릭 자체가 없는가? |
| 기록 | GitHub Projects 회고 이슈 1개(잘된 것 / 아쉬운 것 / 다음에 바꿀 것 각 3줄) |
| 반영 규칙 | 바꿀 것 중 1개만 다음 스프린트 스토리로 등록 |

### 8. 성장 루프 설계

| 단계 | 상대가 보는 것 | 전환 장치 | 측정 |
|---|---|---|---|
| 1. 만든 직후 | (보낸 사람) 완성 화면 | "보내기" 기본 버튼 = 카톡 카드, 보조 = 이미지로 보내기. 완성 축하 화면에서 바로 1컷 추천 | `share_tap` |
| 2. 채팅방 | 큰 스티커 이미지 카드 + 제목 "콩이: 퇴근 언제 해?" + 버튼 "우리 애도 만들기" | 버튼 → 앱 실행, 미설치면 Play 스토어(카카오 링크 우선순위) | `kakao_share_sent` |
| 2'. 이미지 전송 | 리소 스티커 + 우하단 '우리애콘' 판 어긋난 스탬프 | 앱 이름 그대로 검색되게 스토어 제목 "우리애콘 - 반려동물 스티커 만들기" | 검색 유입(Play Console) |
| 3. 스토어 | 첫 스크린샷 = 사진 → 리소 스티커 전후 비교 | 문구 "사진 3장, 3분, 12컷" | 스토어 전환율 |
| 4. 첫 실행 | "친구가 보낸 '퇴근 언제 해?' 컷으로 시작할까요?" | referrer의 template 값으로 같은 컷 먼저 만들기 | `first_open_referrer` |
| 5. 답장 | 첫 컷 완성 즉시 "답장으로 보내기" | 받은 대화방으로 돌아가 답장 → 루프 재시작 | `share_tap` |

- 카카오 링크: 앱 미설치면 플랫폼에 설정한 스토어 URL로 이동, 등록 안 된 도메인·스킴은 사용 불가 [출처](https://developers.kakao.com/docs/latest/ko/message-template/common).
- 카드 이미지는 피드 템플릿 최소 200x200(기본)·400x400(사용자 정의), 5MB 이하 [출처](https://developers.kakao.com/docs/latest/ko/message-template/common). 카드용은 800x800 종이색 배경 PNG로 만든다.
- 카톡 공유 기본 쿼터는 일 30,000건, 초과분은 유료 API 설정 시 건당 50원(2027-12-31까지 10원) [출처](https://developers.kakao.com/docs/latest/ko/getting-started/quota). 유료 설정은 하지 않고, 실패 시 공유 시트로 대체.
- 업로드 이미지 보관 기간은 문서에서 못 찾음(미확인).

다시 열게 만드는 장치:

| 장치 | 방식 | 서버 |
|---|---|---|
| 시즌·이벤트 팩 | 여름(MVP 앱 번들), 이후 추석·연말·설·봄 산책·생일 등 12컷 팩을 GitHub Pages 정적 JSON+이미지로 | 없음(정적 호스팅) |
| 이미 오린 사진 재사용 | 새 팩은 사진 다시 고를 필요 없이 1탭 생성 | 없음 |
| 여러 반려동물 | 둘째·친구네 애 등록, 마리별 팩 | 없음 |
| 오늘의 한 장 | 주 1회 로컬 알림, 기본 꺼짐(사용자가 켤 때만 권한 요청) | 없음 |
| 새 사진 넣기 | 홈 "새 사진으로 표정 추가" → 같은 팩 컷 교체 | 없음 |

### 9. 스티커를 실제로 보내는 경로(조사 결과)

| 경로 | 가능 여부 | 요구사항·제약 | 판단 |
|---|---|---|---|
| Android 공유 시트(카톡·인스타 DM·문자 등) | 가능 | `share_plus` 13.3.1로 파일+텍스트 공유. 텍스트+이미지를 함께 넘기면 일부 앱이 제대로 받지 못함 [출처](https://pub.dev/packages/share_plus) | MVP. 텍스트 없이 이미지만 |
| 카카오톡 공유 피드 카드 | 가능 | `kakao_flutter_sdk_share` 2.0.1. `uploadImage`로 카카오 서버에 이미지 업로드 후 카드 전송 [출처](https://developers.kakao.com/sdk/reference/flutter/release/kakao_flutter_sdk_share/ShareClient-class.html). Kakao SDK 전용(REST 미지원), 카카오톡 10.0.0 이상 [출처](https://developers.kakao.com/docs/latest/ko/kakaotalk-share/common) | MVP 주력(버튼이 성장 장치) |
| 카카오톡 이모티콘 탭에 개인 스티커 등록 | 미확인(공식 경로 못 찾음) | 프로필 이모티콘 스티커는 보유 이모티콘 대상 [출처](https://www.kakaocorp.com/page/detail/9921) | 하지 않음 |
| 카카오톡에 투명 PNG 전송 | 미확인 | 투명 배경 유지 여부 확인 못 함 | 기본 전송은 흰(종이색) 배경 PNG, 투명은 저장용 |
| Instagram 스토리 스티커 | 가능 | 인텐트 `com.instagram.share.ADD_TO_STORY`, `interactive_asset_uri`(PNG/JPG, 권장 640x480), Facebook App ID를 `source_application`으로 필수 [출처](https://developers.facebook.com/docs/instagram-platform/sharing-to-stories) | 백로그(v1.1) |
| WhatsApp 스티커팩 | 가능 | 정확히 512x512 WebP, 정지 100KB 이하, 팩당 3~30장, 앱당 1~10팩, 트레이 96x96·50KB 이하, 스티커당 이모지 최대 3개, ContentProvider + `ENABLE_STICKER_PACK` 인텐트, 스토어 설명에 "WAStickerApps", 앱 이름에 WhatsApp 금지 [출처](https://raw.githubusercontent.com/WhatsApp/stickers/main/Android/README.md). Flutter는 `whatsapp_stickers_handler` 0.5.0(2025-04 게시) | 백로그. 12컷이 규격(3~30) 안이라 나중에 붙이기 쉬움 |
| Gboard / 키보드 스티커 | 일반 앱은 불가 | Commit Content API는 키보드(IME)가 앱에 보내는 규약이라, 넣으려면 자체 키보드 앱이 필요 [출처](https://developer.android.com/develop/ui/views/touch-and-input/image-keyboard). Firebase App Indexing 스티커 방식은 2018 자료만 확인 [출처](https://spin.atomicobject.com/custom-gboard-sticker-pack/), 현재 Firebase 문서에서 스티커 지원·종료 공지 모두 못 찾음(미확인) | 하지 않음 |

### 10. 기술 구조

파이프라인(전부 기기 안):

| 단계 | 처리 | 패키지·API | 성능 목표 |
|---|---|---|---|
| 1. 선택 | Photo Picker로 3~5장, 긴 변 1024px로 축소 저장 | `image_picker` 1.2.4 + `image_picker_android` 0.8.13+25 | 즉시 |
| 2. 분할 | 전경 마스크·전경 비트맵, 결과 캐시 | `google_mlkit_subject_segmentation` 0.2.1 | 1장 ≤ 1.5초(중급기) |
| 3. 다듬기 | 마스크 침식/확장, 2px 페더, 전경 bbox로 크롭 후 512 정사각 배치 | Dart 직접 구현(Isolate) | ≤ 100ms |
| 4. 리소 2판 | 판 분리 → 회전 망점 → 판 어긋남 → 곱하기 합성 → 잉크 결 | Flutter `FragmentShader`(.frag), 대체 경로 `image` 4.12.0 | GPU ≤ 150ms / CPU ≤ 1초 |
| 5. 합성 | 흰 테두리, 소품(리소 2판 스타일 번들 PNG), 말풍선·한글 문구 | `Canvas` + `PictureRecorder`, 소품 원본은 `flutter_svg` 2.3.0 | 컷당 ≤ 300ms |
| 6. 내보내기 | 투명 PNG 512, 흰 배경 PNG 512, 카톡 카드 800 PNG | `gal` 2.3.3, `share_plus` 13.3.1, `kakao_flutter_sdk_share` 2.0.1 | 12장 저장 ≤ 3초 |
| 저장 | 반려동물·팩·컷 메타데이터, 파일은 앱 전용 폴더 | `sqflite` 2.4.5, `path_provider` 2.1.6 | - |
| 계측 | 이벤트·크래시 | `firebase_analytics` 13.0.0, `firebase_crashlytics` 6.0.0, `play_install_referrer` 0.5.0 | - |
| 알림 | 주 1회 로컬 알림 | `flutter_local_notifications` 22.3.2 | - |

패키지 버전은 pub.dev API로 2026-10-22 확인 [출처](https://pub.dev/api/packages/google_mlkit_subject_segmentation).

ML Kit 주체 분할 사실 확인:
- Android 전용, beta, minSdk 24 [출처](https://pub.dev/packages/google_mlkit_subject_segmentation). beta라 SLA·지원 중단 정책이 없고 호환이 깨질 수 있음 [출처](https://developers.google.com/ml-kit/vision/subject-segmentation/android).
- 대상은 사람·반려동물·사물, 정지 이미지만, Pixel 7 Pro 평균 약 200ms [출처](https://developers.google.com/ml-kit/vision/subject-segmentation).
- 모델은 Play services가 제공(앱 용량 약 200KB 증가). manifest에 `com.google.mlkit.vision.DEPENDENCIES` = `subject_segment`로 설치 때 미리 받기 가능. 다운로드 전 요청은 결과 없음. 입력 512x512 이상 권장. 세션 첫 추론이 느려 미리 더미 추론 권장 [출처](https://developers.google.com/ml-kit/vision/subject-segmentation/android).
- Flutter 플러그인의 옵션 이름·결과 필드명은 문서에서 확인 못 함(미확인) → S1 스파이크에서 코드로 확인.

리소 2판 변환 설계(시안: 핑크+블루 2도, 판 어긋남, 종이결):

| 순서 | 처리 | 기본값(조정 가능) |
|---|---|---|
| 1 | 휘도 L 계산, 대비 자동 보정(상하위 2% 늘리기) | - |
| 2 | 블루판 = 어두운 부분 농도 `(1-L)^0.9`, 핑크판 = 중간톤·따뜻한 색 `smoothstep(0.25,0.85,1-L) + 0.4·max(R-B,0)` | 판 색: 핑크 #FF48B0, 블루 #0078BF(근사값) |
| 3 | 판마다 좌표를 회전해 원형 망점, 반지름 = √농도 × 셀 × 0.7, 경계 1px 안티앨리어싱 | 셀 6px(512 기준), 블루 75°, 핑크 15° |
| 4 | 판 어긋남: 핑크판을 (3,−2)px 이동 + 0.4° 회전, 시드는 컷 ID로 고정 | 2~4px |
| 5 | 곱하기 합성: 색 = 1 − (1−핑크·a₁)(1−블루·a₂) 개념의 감산 혼합, 알파 = 전경 마스크 | - |
| 6 | 잉크 결: 해시 노이즈로 망점 3~5% 빠짐, 종이 배경은 흰 배경 버전에만 | 4% |
| 7 | 흰 테두리: 마스크를 거리 기준으로 확장해 흰색, 그 바깥에 블루 얇은 선을 어긋나게 | 11px + 2px |

- 셰이더는 `.frag`를 pubspec `shaders`에 선언하고 `FragmentProgram.fromAsset`으로 읽음. 이미지는 `sampler2D` + `setImageSampler`로 넘김. 출력은 premultiplied alpha, `FlutterFragCoord()` 사용, Skia에선 런타임 컴파일이라 미리 로드 필요 [출처](https://docs.flutter.dev/ui/design/graphics/fragment-shaders).
- 렌더 결과는 `PictureRecorder` → `toImage` → PNG 인코딩. GPU 결과가 기기마다 다르면 CPU 경로(`image` 패키지, Isolate)로 같은 수식 실행.
- 저사양 대책: 입력 1024px 상한, 12컷은 한 컷씩 순차 생성·디스크 캐시, 미리보기는 256px.

### 11. 권한·Play 정책

| 항목 | 설계 |
|---|---|
| 사진 | Photo Picker 사용, `READ_MEDIA_IMAGES` 선언 안 함. Android 13+에서 이 권한은 시스템 피커로 부족할 때만 허용 [출처](https://support.google.com/googleplay/android-developer/answer/9888170) |
| image_picker 동작 | Android 16+는 갤러리 선택이 항상 Photo Picker. Android 15 이하는 `useAndroidPhotoPicker = true` 필요. 선택 개수 제한(`limit`)은 이 플래그가 켜져야 하고 Android 13+에서만 보장 [출처](https://pub.dev/packages/image_picker_android) |
| 구형 기기 | Photo Picker는 Android 4.4~10에 Play 서비스 백포트, 미지원 시 `ACTION_OPEN_DOCUMENT` 대체 [출처](https://developer.android.com/training/data-storage/shared/photopicker) |
| 알림 | Android 13+ 알림 권한은 "오늘의 한 장"을 켤 때만 요청 [출처](https://developer.android.com/develop/ui/views/notifications/notification-permission) |
| 인터넷 | 카카오 공유·Firebase용. 사진 처리에는 쓰지 않음 |
| Data safety: 사진 | 기기 안에서만 처리하는 데이터는 수집이 아님 [출처](https://support.google.com/googleplay/android-developer/answer/10787469). 단 카톡 카드는 스티커 이미지를 카카오 서버로 올리므로, 보수적으로 "사진" 수집·공유(사용자 요청 시 전송, 카카오) 신고 |
| Data safety: 계측 | Firebase Analytics·Crashlytics가 보내는 항목(앱 활동, 기기 ID, 크래시 로그 등) 신고. 정확한 항목은 Firebase 안내로 출시 전 확인 |
| 반려동물 사진 | 동물 사진 전용 Data safety 항목은 없음. "사진" 유형으로 다룸. 내보낸 PNG는 새로 그려 EXIF(위치) 없음 |
| 개인정보처리방침 | 데이터 미수집이어도 필수, 앱 안 + Play Console 링크 [출처](https://support.google.com/googleplay/android-developer/answer/10144311). GitHub Pages에 게시 |
| 생성형 AI 정책 | 대상은 텍스트·이미지→이미지 생성 앱 등 [출처](https://support.google.com/googleplay/android-developer/answer/14094294). 본 앱은 분할 + 규칙 기반 변환이라 해당 가능성 낮음(정책문이 사진 변환 앱을 직접 언급하지 않아 확정 아님) |
| 대상 연령·등급 | 아동 대상 아님(13세 이상), IARC 설문 [출처](https://support.google.com/googleplay/android-developer/answer/9859655) |
| 에셋 라이선스 | 소품은 직접 제작, 한글 폰트는 상업 이용·임베딩 허용 라이선스만 |
| 외부 키 | 카카오디벨로퍼스 앱 키·키 해시·플랫폼 등록. Facebook App ID는 Instagram 백로그 때 |

### 12. 리스크와 대응

| 리스크 | 신호 | 대응 |
|---|---|---|
| 분할 품질(털 끝, 검은 고양이, 배경과 같은 색) | `segment_done` 실패율 > 20%, 다듬기 사용률 높음 | 촬영 가이드(정면·밝게·배경 대비), 가장자리 슬라이더, 리소 망점이 경계 거칠음을 가려 줌. 그래도 안 되면 브러시 지우개를 백로그에서 당김 |
| ML Kit beta 변경·Play services 없는 기기 | 빌드 깨짐, 모델 미설치 오류 | 버전 고정, 설치 때 모델 미리 받기, 모델 없으면 "잠시 후 다시" 안내, 스토어 설명에 Google Play 서비스 필요 명시 |
| 저사양 기기(RAM 3~4GB) | ANR·OOM, 12컷 > 15초 | 입력 1024px 상한, 순차 생성, 셰이더 실패 시 CPU 경로, 테스트 기기 1대는 저사양 |
| 일회성 이탈 | D30 < 10% | 시즌 팩(사진 재선택 없이 1탭), 여러 마리, 주 1회 알림. 그래도 낮으면 "신규 유입 중심"으로 목표 재정의 |
| OS 기본 누끼와 비교됨 | 리뷰에 "갤러리로도 됨" | 전후 비교 스크린샷으로 리소 변환을 앞세움, 누끼 언급 최소화 |
| 카톡 공유 쿼터·정책 변경 | 공유 실패 증가 | 공유 시트 자동 대체, 유료 설정 안 함 |
| 카톡 투명 처리 불확실 | 검은 배경 신고 | 기본 전송을 흰(종이색) 배경으로 |
| 워터마크 거부감 | 설정에서 끔 비율 > 50% | 크기 축소·위치 조정, 카드 버튼에 성장 의존도 이동 |
| 비공개 테스트 이탈 | 14일 연속 깨짐 | 15명 모집, 지인 단톡방에서 주 1회 새 컷 공유로 참여 유지 |

#### 출처

- 크몽 이모티콘 외주 가격: https://kmong.com/gig/203919
- ML Kit 주체 분할 개요: https://developers.google.com/ml-kit/vision/subject-segmentation
- ML Kit 주체 분할 Android: https://developers.google.com/ml-kit/vision/subject-segmentation/android
- google_mlkit_subject_segmentation: https://pub.dev/packages/google_mlkit_subject_segmentation
- pub.dev 패키지 버전 API: https://pub.dev/api/packages/google_mlkit_subject_segmentation (같은 형식으로 각 패키지 확인)
- image_picker_android: https://pub.dev/packages/image_picker_android
- Android Photo Picker: https://developer.android.com/training/data-storage/shared/photopicker
- share_plus: https://pub.dev/packages/share_plus
- 카카오톡 공유 공통: https://developers.kakao.com/docs/latest/ko/kakaotalk-share/common
- 카카오 ShareClient(Flutter): https://developers.kakao.com/sdk/reference/flutter/release/kakao_flutter_sdk_share/ShareClient-class.html
- 카카오 메시지 템플릿: https://developers.kakao.com/docs/latest/ko/message-template/common
- 카카오 쿼터: https://developers.kakao.com/docs/latest/ko/getting-started/quota
- 카카오톡 프로필 이모티콘 스티커: https://www.kakaocorp.com/page/detail/9921
- Instagram 스토리 공유: https://developers.facebook.com/docs/instagram-platform/sharing-to-stories
- WhatsApp 스티커 규격: https://raw.githubusercontent.com/WhatsApp/stickers/main/Android/README.md
- Android 이미지 키보드(Commit Content API): https://developer.android.com/develop/ui/views/touch-and-input/image-keyboard
- Gboard 스티커 팩(App Indexing, 2018): https://spin.atomicobject.com/custom-gboard-sticker-pack/
- Flutter 프래그먼트 셰이더: https://docs.flutter.dev/ui/design/graphics/fragment-shaders
- Play 권한·민감 API: https://support.google.com/googleplay/android-developer/answer/9888170
- Play Data safety: https://support.google.com/googleplay/android-developer/answer/10787469
- Play 개인정보처리방침: https://support.google.com/googleplay/android-developer/answer/10144311
- Play 생성형 AI 정책: https://support.google.com/googleplay/android-developer/answer/14094294
- Play 콘텐츠 등급: https://support.google.com/googleplay/android-developer/answer/9859655
- Play 비공개 테스트 요건: https://support.google.com/googleplay/android-developer/answer/14151465
- Play targetSdk 요건: https://support.google.com/googleplay/android-developer/answer/11926878
- Android 알림 권한: https://developer.android.com/develop/ui/views/notifications/notification-permission
- 조사 원문: /home/claude/research/g2.md 3장, /home/claude/research/common.md
